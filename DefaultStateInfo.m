% DEFAULT state configuration file for runExperiment.runTrainingSession (full
% behavioural task design). This state file has a prefix state, a fixation
% state for the subject to initiate fixation, then a stimulus state. If the
% subject fails initial fixation, an incorrect state is called. If the
% subject fails fixation during stimulus presentation, a breakfix state is
% called.
%
% State files control the logic of a stateMachine instance for a behavioural task, switching 
% between states and executing functions on entry, within and on exit of
% states. In addition there are transition function sets which can test
% things like eye position to conditionally switch to another state. This state 
% control file will be run in the scope of the calling runExperiment.runTask method 
% and other objects will be available at run time (with easy to use names listed below).
% The following class objects (easily named handle copies) are already 
% loaded and available to use. Each class has methods useful for running the task: 
%
% me		= runExperiment class object
% s			= screenManager class object
% aM		= audioManager class object
% sM		= State Machine (stateMachine class)
% task		= task sequence (taskSequence class)
% eT		= eyetracker manager
% io		= digital I/O to recording system
% rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR		= behavioural record plot (on screen GUI during task run)
% stims		= our list of stimuli (metaStimulus class)
% tS		= general structure to hold general variables, will be saved as part of the data

%==================================================================
%------------General Settings-----------------
tS.useTask					= true;		%==use taskSequence (randomised variable task object)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus  = true;		%==allow keyboard control? Slight drop in performance
tS.recordEyePosition		= false;	%==record eye position within PTB, **in addition** to the EDF?
tS.askForComments			= false;	%==little UI requestor asks for comments before/after run
tS.saveData					= false;	%==save behavioural and eye movement data?
tS.includeErrors			= false;	%==do we update the trial number even for incorrect saccade/fixate, if true then we call updateTask for both correct and incorrect, otherwise we only call updateTask() for correct responses
tS.nStims					= stims.n;	%==number of stimuli
tS.name						= 'default'; %==name of this protocol
tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
tS.CORRECT 					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX 				= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT 				= -5;		%==the code to send eyetracker for incorrect trials

%==================================================================
%------------Debug logging to command window-----------------
%io.verbose					= true;		%==print out io commands for debugging
%eT.verbose					= true;		%==print out eyelink commands for debugging
%rM.verbose					= true;		%==print out reward commands for debugging

%==================================================================
%--------------------Eyetracker Settings---------------------------
tS.fixX						= 0;		%==X position in degrees
tS.fixY						= 0;		%==X position in degrees
tS.firstFixInit				= 3;		%==time to search and enter fixation window
tS.firstFixTime				= [0.5 0.9];%==time to maintain fixation within window
tS.firstFixRadius			= 2;		%==radius in degrees
tS.strict					= true;		%==do we forbid eye to enter-exit-reenter fixation window?
tS.exclusionZone			= [];		%==do we add an exclusion zone where subject cannot saccade to...
tS.stimulusFixTime			= 0.5;		%==time to fix on the stimulus
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;

%==================================================================
%---------------------------Eyelink setup--------------------------
eT.name 					= tS.name;
eT.sampleRate 				= 250;		%==sampling rate
eT.calibrationStyle 		= 'HV5';	%==calibration style
eT.calibrationProportion	= [0.3 0.3]; %==the proportion of the screen occupied by the calibration stimuli
if tS.saveData == true;		eT.recordData = true; end %==save EDF file?
if me.dummyMode;			eT.isDummy = true; end %==use dummy or real eyetracker? 
%-----------------------
% remote calibration enables manual control and selection of each fixation
% this is useful for a baby or monkey who has not been trained for fixation
% use 1-9 to show each dot, space to select fix as valid, INS key ON EYELINK KEYBOARD to
% accept calibration!
eT.remoteCalibration				= true; 
%-----------------------
eT.modify.calibrationtargetcolour	= [1 1 1];	%==calibration target colour
eT.modify.calibrationtargetsize		= 2;		%==size of calibration target as percentage of screen
eT.modify.calibrationtargetwidth	= 0.15;		%==width of calibration target's border as percentage of screen
eT.modify.waitformodereadytime		= 500;
eT.modify.devicenumber				= -1;		%==-1 = use any attachedkeyboard
eT.modify.targetbeep				= 1;		%==beep during calibration
%Initialise the eyeLink object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%==================================================================
%----WHICH states assigned as correct or break for online plot?----
%----You need to use regex patterns for the match (doc regexp)-----
bR.correctStateName				= '^correct';
bR.breakStateName				= '^(breakfix|incorrect)';

%==================================================================
%-------------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without
% using taskSequence task, you can uncomment this and runExperiment can
% use this structure to change e.g. X or Y position, size, angle
% see metaStimulus for more details. Remember this will not be "Saved" for
% later use, if you want to do controlled methods of constants experiments
% use taskSequence to define proper randomised and balanced variable
% sets and triggers to send to recording equipment etc...
%
% stims.choice					= [];
% n								= 1;
% in(n).name					= 'xyPosition';
% in(n).values					= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
% in(n).stimuli					= 1;
% in(n).offset					= [];
% stims.stimulusTable			= in;
stims.choice					= [];
stims.stimulusTable				= [];

%==================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and up/down to control variable
stims.controlTable				= [];
stims.tableChoice				= 1;

%==================================================================
%this allows us to enable subsets from our stimulus list
% 1 = grating | 2 = fixation cross
stims.stimulusSets				= {[1]};
stims.setChoice					= 1;
hide(stims);

%==================================================================
% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates = {'fixate','incorrect|breakfix'};

%===================================================================
%-----------------State Machine State Functions---------------------
% each cell {array} holds a set of anonymous function handles which are executed by the
% state machine to control the experiment. The state machine can run sets
% at entry, during, exit and to trigger a transition. Remember these
% {sets} need to access the objects that are available within the
% runExperiment context (see top of file). You can also add global
% variables/objects then use these. The values entered here are set on
% load, if you want up-to-date values then you need to use methods/function
% wrappers to retrieve/set them. runExperiment (me) contains many such
% methods to set various properties and update variables.

%--------------------pause entry
pauseEntryFcn = { 
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'Paused, press [p] to resume...');
	@()disp('Paused, press [p] to resume...');
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()setOffline(eT); % make sure we set offline, only works on eyelink, ignored by tobii
	@()stopRecording(eT, true); %stop recording eye position data
	@()disableFlip(me); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%--------------------pause exit
pauseExitFcn = {
	@()startRecording(eT, true); %start recording eye position data again
}; 

%--------------------prefixation entry
prefixEntryFcn = { 
	@()enableFlip(me); 
	@()needEyeSample(me,true); % make sure we start measuring eye position
	@()hide(stims);
};

prefixFcn = {
	@()drawBackground(s);
};

%--------------------fixate entry
fixEntryFcn = { 
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset fixation window
	@()startRecording(eT); % start eyelink recording for this trial
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawFixation(eT); %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eT,stims.stimulusPositions); %draw location of stimulus on eyelink
	@()statusMessage(eT,'Initiate Fixation...'); %status text on the eyelink
	@()show(stims{tS.nStims});
	@()logRun(me,'INITFIX'); %fprintf current trial info to command window
};

%--------------------fix within
fixFcn = {
	@()draw(stims); %draw stimulus
	@()drawPhotoDiode(s,[0 0 0]);
	@()animate(stims); % animate stimuli for subsequent draw
};

%--------------------test we are fixated for a certain length of time
inFixFcn = { 
	@()testSearchHoldFixation(eT,'stimulus','incorrect')
};

%--------------------exit fixation phase
fixExitFcn = { 
	@()statusMessage(eT,'Show Stimulus...');
	@()updateFixationValues(eT,[],[],[],tS.stimulusFixTime); %reset a maintained fixation of 1 second
	@()show(stims);
    @()trackerMessage(eT,'END_FIX');
}; 

%--------------------what to run when we enter the stim presentation state

stimEntryFcn = { 
	@()syncTime(eT); %EDF sync message
	@()doStrobe(me,true)
};

%--------------------what to run when we are showing stimuli
stimFcn =  { 
	@()draw(stims);
	@()drawPhotoDiode(s,[1 1 1]);
	@()animate(stims); % animate stimuli for subsequent draw
};

%test we are maintaining fixation
maintainFixFcn = { 
	@()testSearchHoldFixation(eT,'correct','breakfix');
};

%as we exit stim presentation state
stimExitFcn = { 
	@()sendStrobe(io,255);
};

%if the subject is correct (small reward)
correctEntryFcn = {
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()beep(aM,2000); % correct beep
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.CORRECT)]);
	@()trackerDrawText(eT,'Correct! :-)');
	@()stopRecording(eT);
	@()setOffline(eT); %set eyelink offline
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims);
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%correct stimulus
correctFcn = { 
	@()drawBackground(s);
};

%when we exit the correct state
correctExitFcn = {
	@()updateTask(me,tS.CORRECT); %make sure our taskSequence is moved to the next trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()update(me.stimuli); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions\
	@()resetFixation(eT);
	@()trackerClearScreen(eT); 
	@()updatePlot(bR, eT, sM); %update our behavioural plot
	@()checkTaskEnded(me); %check if task is finished
	@()drawnow;
};

%incorrect entry
incEntryFcn = { 
	@()beep(aM,400,0.5,1);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Incorrect! :-(');
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.INCORRECT)]);
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
}; 

%our incorrect stimulus
incFcn = {
	@()drawBackground(s);
};

%--------------------incorrect / break exit
incExitFcn = { 
	@()updateVariables(me); %randomise our stimuli, set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()resetFixation(eT);
	@()trackerClearScreen(eT); 
	@()checkTaskEnded(me); %check if task is finished
	@()updatePlot(bR, eT, sM); %update our behavioural plot;
	@()drawnow;
};
if tS.includeErrors
	incExitFcn = [ {@()updateTask(me,tS.BREAKFIX)}; incExitFcn ]; %make sure our taskSequence is moved to the next trial
else
	incExitFcn = [ {@()resetRun(task)}; incExitFcn ]; %we randomise the run within this block to make it harder to guess next trial
end

%--------------------break entry
breakEntryFcn = {
	@()beep(aM,400,0.5,1);
	@()edfMessage(eT,'END_RT');
	@()edfMessage(eT,['TRIAL_RESULT ' num2str(tS.BREAKFIX)]);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Broke maintain fix! :-(');
	@()stopRecording(eT);
	@()setOffline(eT); %set eyelink offline
	@()needEyeSample(me,false);
	@()sendStrobe(io,252);
	@()hide(stims);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
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
overrideFcn = { @()keyOverride(me) }; %a special mode which enters a matlab debug state so we can manually edit object values

%--------------------screenflash
flashFcn = { @()flashScreen(s, 0.2) }; % fullscreen flash mode for visual background activity detection

%--------------------magstim
magstimFcn = { 
	@()drawBackground(s);
	@()stimulate(mS); % run the magstim
};

%--------------------show 1deg size grid
gridFcn = {@()drawGrid(s)};

%==================================================================
%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'		'next'		'time'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
'pause'		'prefix'	inf		pauseEntryFcn	[]				[]				pauseExitFcn;
'prefix'	'fixate'	0.5		prefixEntryFcn	[]				[]				[];
'fixate'	'incorrect'	5	 	fixEntryFcn		fixFcn			inFixFcn		fixExitFcn;
'stimulus'  'incorrect'	5		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'incorrect'	'prefix'	2		incEntryFcn		incFcn			[]				incExitFcn;
'breakfix'	'prefix'	tS.tOut	breakEntryFcn	incFcn			[]				incExitFcn;
'correct'	'prefix'	1		correctEntryFcn	correctFcn		[]				correctExitFcn;
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]				[];
'drift'		'pause'		0.5		driftFcn		[]				[]				[];
'override'	'pause'		0.5		overrideFcn		[]				[]				[];
'flash'		'pause'		0.5		flashFcn		[]				[]				[];
'magstim'	'prefix'	0.5		[]				magstimFcn		[]				[];
'showgrid'	'pause'		10		[]				gridFcn			[]				[];
};
%----------------------State Machine Table-------------------------
%==================================================================

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear pauseEntryFcn fixEntryFcn fixFcn initFixFcn fixExitFcn stimFcn maintainFixFcn incEntryFcn ...
	incFcn incExitFcn breakEntryFcn breakFcn correctEntryFcn correctFcn correctExitFcn ...
	calibrateFcn overrideFcn flashFcn gridFcn
