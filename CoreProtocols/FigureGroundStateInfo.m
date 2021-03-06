%FIGURE GROUND state configuration file, this gets loaded by opticka via
%runExperiment class. 
% The following class objects (easily named handle copies) are already 
% loaded and available to use: 
%
% me = runExperiment object
% io = digital I/O to recording system
% s = screenManager
% aM = audioManager
% sM = State Machine
% eT = eyetracker manager
% task  = task sequence (taskSequence class)
% rM = Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR = behavioural record plot (on screen GUI during task run)
% stims = our list of stimuli
% tS = general struct to hold variables for this run, will be saved

%==================================================================
%------------General Settings-----------------
tS.rewardTime = 150; %==TTL time in milliseconds
tS.useTask = true; %==use taskSequence (randomised variable task object)
tS.checkKeysDuringStimulus = false; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition = false; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments = false; %==little UI requestor asks for comments before/after run
tS.saveData = true; %==save behavioural and eye movement data?
tS.useMagStim = false; %enable the magstim manager
tS.name = 'figure-ground'; %==name of this protocol
tS.luminancePedestal = [0.5 0.5 0.5]; %used during training, it sets the clip behind the figure to a different luminance which makes the figure more salient and thus easier to train to.
tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
tS.CORRECT 					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX 				= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT 				= -5;		%==the code to send eyetracker for incorrect trials

%==================================================================
%------------Debug logging to command window-----------------
%io.verbose					= true; %print out io commands for debugging
%eT.verbose					= true; %print out eyelink commands for debugging
%rM.verbose					= true; %print out reward commands for debugging

%==================================================================
%-----enable the magstimManager which uses FOI2 of the LabJack
if tS.useMagStim
	mS = magstimManager('lJ',rM,'defaultTTL',2);
	mS.stimulateTime	= 240;
	mS.frequency		= 0.7;
	mS.rewardTime		= 25;
	open(mS);
end
				
%------------Eyetracker Settings-----------------
tS.fixX = 0;
tS.fixY = 0;
tS.firstFixInit = 1;
tS.firstFixTime = 0.6;
tS.firstFixRadius = 3.3;
me.lastXPosition = tS.fixX;
me.lastYPosition = tS.fixY;
tS.strict = true; %do we allow (strict==false) multiple entry/exits of fix window within the time limit

tS.targetFixInit = 1;
tS.targetFixTime = 0.6;
tS.targetRadius = 5;

%==================================================================
%------------------------Eyelink setup--------------------------
me.useEyeLink				= true; % make sure we are using eyetracker
eT.name 					= tS.name;
if tS.saveData == true;		eT.recordData = true; end %===save EDF file?
if me.dummyMode;			eT.isDummy = true; end %===use dummy or real eyetracker? 
eT.sampleRate 				= 250; % sampling rate
%-----------------------
% remote calibration enables manual control and selection of each fixation
% this is useful for a baby or monkey who has not been trained for fixation
% use 1-9 to show each dot, space to select fix as valid, INS key ON EYELINK KEYBOARD to
% accept calibration!
eT.remoteCalibration			= true; 
%-----------------------
eT.calibrationStyle 			= 'HV5'; % calibration style
eT.calibrationProportion		= [0.6 0.6]; %the proportion of the screen occupied by the calibration stimuli
eT.modify.calibrationtargetcolour = [1 1 1];
eT.modify.calibrationtargetsize = 2; % size of calibration target as percentage of screen
eT.modify.calibrationtargetwidth = 0.15; % width of calibration target's border as percentage of screen
eT.modify.waitformodereadytime	= 500;
eT.modify.devicenumber 			= -1; % -1==use any keyboard
eT.modify.targetbeep 			= 1;

%Initialise the eyeLink object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%randomise stimulus variables every trial? useful during initial training but not for
%data collection.
stims.choice = [];
stims.stimulusTable = [];

% allows using arrow keys to control this table during the main loop
% ideal for mapping receptive fields so we can twiddle parameters, normally not used
% for normal tasks
stims.controlTable = [];
stims.tableChoice = 1;

% this allows us to enable subsets from our stimulus list. So each set is a
% particular display like fixation spot only, background. During the trial you can
% use the showSet method of stims to change to a particular stimulus set.
% numbers are the stimuli in the opticka UI
stims.stimulusSets = {[1 2 3 4],[1,4]};
stims.setChoice = 1;
showSet(stims);

%which stimulus in the list is used for a fixation target? For this protocol it means
%the subject must fixate this stimulus (the figure is #3 in the list) to get the
%reward.
stims.fixationChoice = 3;

%----------------------State Machine States-------------------------
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.
% each statemachine "function" is a cell array of anonymous functions that enables
% each state to perform a set of actions on entry, during and on exit of that state.

%--------------------pause entry
pauseEntryFcn = {
	@()hide(stims);
	@()drawBackground(s); %blank the display
	@()pauseRecording(io);
	@()drawTextNow(s,'Paused, press [p] to resume...');
	@()disp('Paused, press [p] to resume...');
	@()trackerClearScreen(eT); 
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()edfMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()stopRecording(eT); %stop eye position recording
	@()disableFlip(me); %stop screen updates
	@()needEyeSample(me,false);
}; 

%--------------------pause exit
pauseExitFcn = { 
	@()enableFlip(me);
	@()resumeRecording(io);
};

%--------------------prefixate entry
prefixEntryFcn = { 
	@()setOffline(eT); %make sure offline before start recording
	@()resetFixation(eT); %reset the fixation counters ready for a new trial
	@()updateFixationValues(eT,tS.fixX,tS.fixY,tS.firstFixInit,tS.firstFixTime,tS.firstFixRadius); %reset 
	@()show(stims);
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()trackerClearScreen(eT);
	@()trackerDrawFixation(eT); %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eT,stims.stimulusPositions); %draw location of stimulus on eyelink
	@()edit(stims,4,'colourOut',[0.5 0.5 0.5]); %dim fix spot
	@()logRun(me,'PREFIX'); %fprintf current trial info
};

%--------------------prefixate
prefixFcn = { @()draw(stims); };

%--------------------prefixate exit
prefixExitFcn = {
	@()edfMessage(eT,'V_RT MESSAGE END_FIX END_RT');
	@()edfMessage(eT,sprintf('TRIALID %i',getTaskIndex(me)));
	@()edfMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()startRecording(eT); %start eyelink recording eye data
	@()statusMessage(eT,'Get Fixation...'); %status text on the eyelink
	@()needEyeSample(me,true);
};

%--------------------fixate entry
fixEntryFcn = { 
	@()edit(stims,4,'colourOut',[1 1 0]); %edit fixation spot to be yellow
	@()startFixation(io);
};

%--------------------fix within
fixFcn = { @()draw(stims); @()drawPhotoDiode(s,[0 0 0]) };

%--------------------test we are fixated for a certain length of time
initFixFcn = { @()testSearchHoldFixation(eT,'stimulus','incorrect'); };

%--------------------exit fixation phase
fixExitFcn = { 
	@()updateFixationTarget(me, tS.useTask, tS.targetFixInit, tS.targetFixTime, tS.targetRadius, tS.strict); %use our stimuli values for next fix X and Y
	@()edit(stims,4,'colourOut',[0.6 0.6 0.5]); %dim fix spot
	%@()statusMessage(eT,'Show Stimulus...');
	@()trackerDrawFixation(eT); 
	@()edfMessage(eT,'END_FIX');
};

%--------------------what to run when we enter the stim presentation state
stimEntryFcn = { @()doStrobe(me,true);@()doSyncTime(me); };  

%--------------------what to run when we are showing stimuli
stimFcn =  { 
	@()draw(stims);
	@()drawPhotoDiode(s,[1 1 1]);
	@()finishDrawing(s);
	@()animate(stims); % animate stimuli for subsequent draw
};

%--------------------test we are finding target
testFixFcn = { @()testSearchHoldFixation(eT,'correct','breakfix'); };

%--------------------as we exit stim presentation state
stimExitFcn = { @()sendStrobe(io,255); };

%--------------------if the subject is correct (small reward)
correctEntryFcn = { 
	@()edfMessage(eT,'END_RT');
	@()timedTTL(rM,0,tS.rewardTime); % labjack sends a TTL to Crist reward system
	@()beep(aM,2000); % correct beep
	@()statusMessage(eT,'Correct! :-)');
	@()hide(stims{4});
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%--------------------correct stimulus
correctFcn = { 
	@()draw(stims); 
	@()drawTimedSpot(s, 0.5, [0 1 0 1]);
};

%--------------------when we exit the correct state
correctExitFcn = { 
	@()correct(io);
	@()needEyeSample(me,false);
	@()edfMessage(eT,'TRIAL_RESULT 1');
	@()edfMessage(eT,'TRIAL OK');
	@()stopRecording(eT);
	@()updateVariables(me,[],[],true); %randomise our stimuli, set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()drawTimedSpot(s, 0.5, [0 1 0 1], 0.2, true); %reset the timer on the green spot
	@()updatePlot(bR, eT, sM); %update our behavioural plot
	@()checkTaskEnded(me); %check if task is finished
};

%--------------------incorrect entry
incEntryFcn = { 
	@()edfMessage(eT,'END_RT'); %send END_RT to eyelink
	@()trackerDrawText(eT,'Incorrect! :-(');
	@()beep(aM,400,0.5,1);
	@()hide(stims{4}); %hide fixation spot
	@()logRun(me,'INCORRECT'); %fprintf current trial info
}; 

%--------------------our incorrect stimulus
incFcn = { @()draw(stims); };

%--------------------incorrect / break exit
incExitFcn = { 
	@()incorrect(io);
	@()needEyeSample(me,false);
	@()edfMessage(eT,'TRIAL_RESULT 0'); %trial incorrect message
	@()stopRecording(eT); %stop eyelink recording data
	@()setOffline(eT); %set eyelink offline
	@()resetRun(task);... %we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(me,[],true,false); %update the variables
	@()update(stims); %update our stimuli ready for display
	@()updatePlot(bR, eT, sM); %update our behavioural plot;
	@()checkTaskEnded(me); %check if task is finished
};

%--------------------break entry
breakEntryFcn = { 
	@()edfMessage(eT,'END_RT');
	@()trackerDrawText(eT,'Broke Fixation!');
	@()beep(aM,400,0.5,1);
	@()hide(stims{4});
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

%--------------------incorrect / break exit
breakExitFcn = { 
	@()breakFixation(io);
	@()needEyeSample(me,false);
	@()edfMessage(eT,'TRIAL_RESULT -1');
	@()stopRecording(eT);
	@()setOffline(eT); %set eyelink offline
	@()resetRun(task);... %we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(me,[],true,false); %update the variables
	@()update(stims); %update our stimuli ready for display
	@()updatePlot(bR, eT, sM); %update our behavioural plot;
	@()checkTaskEnded(me); %check if task is finished
};

%--------------------calibration function
calibrateFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop eyelink recording data
	@()setOffline(eT); 
	@()rstop(io); 
	@()trackerSetup(eT);  %enter tracker calibrate/validate setup mode
};

%--------------------drift correction function
driftFcn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop eyelink recording data
	@()setOffline(eT); % set eyelink offline
	@()rstop(io); 
	@()driftCorrection(eT) % enter drift correct
};

%--------------------debug override
overrideFcn = { @()keyOverride(me); }; %a special mode which enters a matlab debug state so we can manually edit object values

%--------------------screenflash
flashFcn = { 
	@()drawBackground(s);
	@()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection
};

%--------------------run magstim
magstimFcn = { 
	@()drawBackground(s);
	@()stimulate(mS); % run the magstim
};

%--------------------show 1deg size grid
gridFcn = { @()drawGrid(s); };

% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate',{'incorrect','breakfix'}}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates = {'fixate',{'incorrect','breakfix'}};

%==================================================================
%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'		'next'		'time'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
'pause'		'prefix'	inf		pauseEntryFcn	{}				{}				pauseExitFcn;
'prefix'	'fixate'	2		prefixEntryFcn	prefixFcn		{}				prefixExitFcn;
'fixate'	'incorrect'	2		fixEntryFcn		fixFcn			initFixFcn		fixExitFcn;
'stimulus'  'incorrect'	2		stimEntryFcn	stimFcn			testFixFcn		stimExitFcn;
'incorrect'	'prefix'	1.25	incEntryFcn		incFcn			{}				incExitFcn;
'breakfix'	'prefix'	tS.tOut	breakEntryFcn	incFcn			{}				breakExitFcn;
'correct'	'prefix'	0.5		correctEntryFcn correctFcn		{}				correctExitFcn;
'calibrate' 'pause'		0.5		calibrateFcn	{}				{}				{};
'drift'		'pause'		0.5		driftFcn		[]				[]				[];
'override'	'pause'		0.5		overrideFcn		{}				{}				{};
'flash'		'pause'		0.5		flashFcn		{}				{}				{};
'magstim'	'prefix'	0.5		{}				magstimFcn		{}				{};
'showgrid'	'pause'		10		{}				gridFcn			{}				{};
};
%----------------------State Machine Table-------------------------
%==================================================================

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear pauseEntryFcn fixEntryFcn fixFcn initFixFcn fixExitFcn stimFcn maintainFixFcn incEntryFcn ...
	incFcn incExitFcn breakEntryFcn breakFcn correctEntryFcn correctFcn correctExitFcn ...
	calibrateFcn overrideFcn flashFcn gridFcn
