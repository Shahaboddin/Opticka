% ========================================================================
%> @brief runExperiment is the main Experiment manager; Inherits from optickaCore
%>
%>RUNEXPERIMENT The main class which accepts a task (taskSequence) and 
%>stimulus (metaStimulus) object and runs the stimuli based on the task object passed.
%>This class uses the fundamental configuration of the screen (calibration, size
%>etc. via screenManager), and manages communication to the DAQ systems
%using digital I/O and communication over a UDP client<->server socket (via dataConnection).
%>
%> There are 2 main experiment types:
%>  1) MOC (method of constants) tasks -- uses stimuli and task objects directly to run standard
%>     randomised variable tasks. See optickatest.m for an example. Does not use the stateMachine.
%>  2) Behavioural tasks that use state machines for control logic. These
%>     tasks still use stimuli and task objects to provide stimuli and variable lists, 
%>     but use a state machine to control the task structure.
%>
%>  Stimuli must be metaStimulus class, so for example:
%>
%>  gStim = gratingStimulus('mask',1,'sf',1);
%>  myStim = metaStimulus;
%>  myStim{1} = gStim;
%>  myExp = runExperiment('stimuli',myStim);
%>  run(myExp);
%>
%>	will run a minimal experiment showing a 1c/d circularly masked grating
%>
%> Copyright ©2014-2021 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef runExperiment < optickaCore
	
	properties
		%> a metaStimulus class holding our stimulus objects
		stimuli metaStimulus
		%> the taskSequence object(s) for the task
		task taskSequence
		%> screen manager object
		screen screenManager
		%> file to define the stateMachine state info
		stateInfoFile char = ''
		%> use Display++ for strobed digital I/O?
		useDisplayPP logical = false
		%> use dataPixx for strobed digital I/O?
		useDataPixx logical = false
		%> use LabJack T4 for strobed digital I/O?
		useLabJackTStrobe logical = false
		%> use LabJack U3/U6 for strobed digital I/O?
		useLabJackStrobe logical = false
		%> use LabJack for reward TTL?
		useLabJackReward logical = false
		%> use Arduino for reward TTL?
		useArduino logical = false
		%> use Eyelink eyetracker?
		useEyeLink logical = false
		%> use Tobii eyetracker?
		useTobii logical = false
		%> use eye occluder (custom arduino device) for monocular stimulation?
		useEyeOccluder logical = false
		%> use a dummy mode for the eyetrackers?
		dummyMode logical = false
		%> do we flip or not?
		doFlip logical = true
		%> log all frame times?
		logFrames logical = true
		%> enable debugging? (poorer temporal fidelity)
		debug logical = false
		%> shows the info text and position grid during stimulus presentation
		visualDebug logical = false
		%> draw simple fixation cross during trial for MOC tasks?
		drawFixation logical = false
		%> flip as fast as possible?
		benchmark logical = false
		%> verbose logging to command window?
		verbose = false
		%> what value to send on stimulus OFF
		stimOFFValue double = 255
		%> subject name
		subjectName char = 'Simulcra'
		%> researcher name
		researcherName char = 'Joanna Doe'
		%> this lets the opticka UI leave commands to runExperiment
		uiCommand char = ''
	end
	
	properties (Transient = true)
		%> structure for screenManager on initialisation and info from opticka
		screenSettings struct = struct()
	end
	
	properties (Hidden = true)
		%> our old stimulus structure used to be a simple cell, now we use metaStimulus
		stimulus
		%> used to select single stimulus in training mode
		stimList = []
		%> which stimulus is selected?
		thisStim = []
		%> tS is the runtime settings structure, saved here as a backup
		tS
		%> keep track of several task values
		lastXPosition = 0
		lastYPosition = 0
		lastXExclusion = []
		lastYExclusion = []
		lastSize = 1
		lastIndex = 0
		%> what mode to run the Display++ digital I/O in? Plexon requires
		%the use of a strobe trigger line, whereas most other equipment
		%just uses simple threshold reading
		dPPMode char = 'plain'
		%> which port is the arduino on?
		arduinoPort char = '/dev/ttyACM0'
		%> initial eyelink settings
		elsettings
		%> initial tobii settings
		tobiisettings
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> send strobe on next flip?
		sendStrobe logical = false
		%> need eyetracker sample on next flip?
		needSample logical = false
		%> send eyetracker SYNCTIME after next flip?
		sendSyncTime logical = false
		%> stateMachine
		stateMachine
		%> eyetracker manager object
		eyeTracker 
		%> generic IO manager
		io
		%> DataPixx control object
		dPixx 
		%> Display++ control object
		dPP 
		%> LabJack control object
		lJack 
		%> Arduino control object
		arduino 
		%> state machine control cell array
		stateInfo cell		= {}
		%> general computer info
		computer
		%> PTB info
		ptb
		%> gamma tables and the like from screenManager
		screenVals struct
		%> MOC log times
		runLog
		%> task log times
		taskLog
		%> behavioural log
		behaviouralRecord
		%> general info on current run
		currentInfo
		%> variable info on the current run
		variableInfo
		%> previous info populated during load of a saved object
		previousInfo struct = struct()
		%> check if runExperiment is running or not
		isRunning logical	= false
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> fInc for managing keyboard sensitivity
		fInc = 6
		%> is it MOC run (false) or stateMachine runTask (true)?
		isRunTask logical	= true
		%> are we using taskSequeence or not?
		isTask logical		= true
		%> should we stop the task?
		stopTask logical	= false
		%> properties allowed to be modified during construction
		allowedProperties='stateInfoFile|dummyMode|stimuli|task|screen|visualDebug|useLabJack|useDataPixx|logFrames|debug|verbose|screenSettings|benchmark'
	end
	
	events %causing a major MATLAB 2019a crash when loading .mat files that contain events, removed for the moment
		%runInfo
		%calls when we quit
		%abortRun
		%calls after all runs finish
		%endAllRuns
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of the class.
		% ===================================================================
		function me = runExperiment(varargin)
			
			args = optickaCore.addDefaults(varargin,struct('name','runExperiment'));
			me=me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties);
			
		end
		
		% ===================================================================
		%> @brief The main run loop for MOC type experiments - a MOC
		%> experiment just runs trials with variables applied to stimuli in a
		%> fixed loop, no conditional logic. Use the behavioural tasks
		%> using the state machine for more complex experimental paradigms.
		%>
		%> run uses built-in loop for experiment control and runs a
		%> methods-of-constants experiment with the settings passed to it (stimuli,task
		%> and screen). This is different to the runTask method as it doesn't
		%> use a stateMachine for experimental logic, just a minimal
		%> trial+block loop.
		%>
		%> @param me required class object
		% ===================================================================
		function runMOC(me)
			global rM %eyetracker calibration needs access to reward manager
					
			if isempty(me.screen) || isempty(me.task)
				me.initialise;
			end
			if isempty(me.stimuli) || me.stimuli.n < 1
				error('No stimuli present!!!')
			end
			if me.screen.isPTB == false
				errordlg('There is no working PTB available!')
				error('There is no working PTB available!')
			end
			
			initialiseSaveFile(me); %generate a savePrefix for this run
			me.name = [me.subjectName '-' me.savePrefix]; %give us a run name

			%initialise runLog for this run
			me.previousInfo.runLog = me.runLog;
			me.taskLog = timeLogger();
			me.runLog = timeLogger();
			tL = me.runLog;
			s = me.screen;
			t = me.task;

			%-----------------------------------------------------------
			try%======This is our main TRY CATCH experiment display loop
			%-----------------------------------------------------------	
				me.isRunning = true;
				me.isRunTask = false;
				
				%------open the PTB screen
				me.screenVals = s.open(me.debug,tL);
				me.stimuli.screen = s; %make sure our stimuli use the same screen
				me.stimuli.verbose = me.verbose;
				t.fps = me.screenVals.fps;
				setup(me.stimuli); %run setup() for each stimulus
				if s.movieSettings.record; prepareMovie(s); end
				
				%configure IO
				io = configureIO(me);
				
				if me.useDataPixx || me.useDisplayPP
					startRecording(io);
					WaitSecs(0.5);
				elseif me.useLabJackStrobe
					%Trigger the omniplex (TTL on FIO1) into paused mode
					io.setDIO([2,0,0]);WaitSecs(0.001);io.setDIO([0,0,0]);
				end

				% set up the eyelink interface
				if me.useEyeLink
					me.eyeTracker = eyelinkManager();
					eT = me.eyeTracker;
					eT.isDummy = me.dummyMode;
					eT.saveFile = [me.paths.savedData pathsep me.savePrefix 'RUN.edf'];
					initialise(eT, s);
					setup(eT);
				end
				
				me.initialiseTask(); %set up our task structure 
				
				me.updateMOCVars(1,1); %set the variables for the very first run;
				
				KbReleaseWait; %make sure keyboard keys are all released
				
				%bump our priority to maximum allowed
				Priority(MaxPriority(s.win));
				
				%--------------unpause Plexon-------------------------
				if me.useDataPixx || me.useDisplayPP
					resumeRecording(io);
				elseif me.useLabJackStrobe
					io.setDIO([3,0,0],[3,0,0])%(Set HIGH FIO0->Pin 24), unpausing the omniplex
				end
				
				if me.useEyeLink; startRecording(eT); end
				
				%------------------------------------------------------------
				% lets draw 2 seconds worth of the stimuli we will be using
				% covered by a blank. Primes the GPU and other components with the sorts
				% of stimuli/tasks used and this does appear to minimise
				% some of the frames lost on first presentation for very complex
				% stimuli using 32bit computation buffers...
				fprintf('\n===>>> Warming up the GPU and I/O systems... <<<===\n')
				show(me.stimuli);
				if me.useEyeLink; trackerClearScreen(eT); end
				for i = 1:s.screenVals.fps*2
					draw(me.stimuli);
					drawBackground(s);
					s.drawPhotoDiodeSquare([0 0 0 1]);
					finishDrawing(s);
					animate(me.stimuli);
					if ~mod(i,10); io.sendStrobe(255); end
					if me.useEyeLink
						getSample(eT); 
						trackerDrawText(eT,'Warming Up System');
						trackerMessage(eT,'Warmup test');
					end
					flip(s);
				end
				update(me.stimuli); %make sure stimuli are set back to their start state
				io.resetStrobe;flip(s);flip(s);
				tL.screenLog.beforeDisplay = GetSecs();
				
				%-----profiling starts here
				%profile clear; profile on;
				
				%-----final setup
				ListenChar(-1);
				me.task.tick = 1;
				me.task.switched = 0;
				me.task.isBlank = true; %lets start in a blank
				if me.logFrames == true
					tL.screenLog.stimTime(1) = 1;
				end
				tL.vbl(1) = GetSecs();
				tL.startTime = tL.vbl(1);
				
				%==================================================================%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Our display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%==================================================================%
				while ~me.task.taskFinished
					if me.task.isBlank
						if s.photoDiode;s.drawPhotoDiodeSquare([0 0 0 1]);end
						if me.drawFixation;s.drawCross(0.4,[0.3 0.3 0.3 1]);end
					else
						if ~isempty(s.backgroundColour);s.drawBackground;end
						draw(me.stimuli);
						if s.photoDiode;s.drawPhotoDiodeSquare([1 1 1 1]);end
						if me.drawFixation;s.drawCross(0.4,[1 1 1 1]);end
					end
					if s.visualDebug;s.drawGrid;me.infoTextScreen;end
					
					Screen('DrawingFinished', s.win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
					
					%========= check for keyboard if in blank ========%
					if me.task.isBlank
						if strcmpi(me.uiCommand,'stop');break;end
						[~,~,kc] = KbCheck(-1);
						if strcmpi(KbName(kc),'q')
							%notify(me,'abortRun');
							break; %break the while loop
						end
					end
					
					%============== Get eye position==================%
					if me.useEyeLink; getSample(me.eyeTracker); end
					
					%================= UPDATE TASK ===================%
					updateMOCTask(me); %update our task structure
					
					%============== Send Strobe =======================%
					if (me.useDisplayPP || me.useDataPixx) && me.sendStrobe
						triggerStrobe(io);
						me.sendStrobe = false;
					end
					
					%======= FLIP: Show it at correct retrace: ========%
					nextvbl = tL.vbl(end) + me.screenVals.halfisi;
					if me.logFrames == true
						[tL.vbl(me.task.tick),tL.show(me.task.tick),tL.flip(me.task.tick),tL.miss(me.task.tick)] = Screen('Flip', s.win, nextvbl);
					elseif me.benchmark == true
						tL.vbl = Screen('Flip', s.win, 0, 2, 2);
					else
						tL.vbl = Screen('Flip', s.win, nextvbl);
					end
					
					%===================Logging=======================%
					if me.task.tick == 1
						if me.benchmark == false
							tL.startTime=tL.vbl(1); %respecify this with actual stimulus vbl
						end
					end
					if me.logFrames == true
						if me.task.isBlank == false
							tL.stimTime(me.task.tick)=1+me.task.switched;
						else
							tL.stimTime(me.task.tick)=0-me.task.switched;
						end
					end
					if s.movieSettings.record ...
							&& ~me.task.isBlank ...
							&& (s.movieSettings.loop <= s.movieSettings.nFrames)
						s.addMovieFrame();
					end
					%===================Tick tock!=======================%
					me.task.tick=me.task.tick+1; tL.tick = me.task.tick;
					
				end
				%==================================================================%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Finished display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%==================================================================%
				ListenChar(0);
				s.drawBackground;
				vbl=Screen('Flip', s.win);
				tL.screenLog.afterDisplay=vbl;
				if me.useDataPixx || me.useDisplayPP
					pauseRecording(io);
				elseif me.useLabJackStrobe
					io.setDIO([0,0,0],[1,0,0]); %this is RSTOP, pausing the omniplex
				end
				%notify(me,'endAllRuns');
				
				%-----get our profiling report for our task loop
				%profile off; profile report; profile clear
				
				tL.screenLog.deltaDispay=tL.screenLog.afterDisplay - tL.screenLog.beforeDisplay;
				tL.screenLog.deltaUntilDisplay=tL.startTime - tL.screenLog.beforeDisplay;
				tL.screenLog.deltaToFirstVBL=tL.vbl(1) - tL.screenLog.beforeDisplay;
				if me.benchmark == true
					tL.screenLog.benchmark = me.task.tick / (tL.screenLog.afterDisplay - tL.startTime);
					fprintf('\n---> BENCHMARK FPS = %g\n', tL.screenLog.benchmark);
				end
				
				s.screenVals.info = Screen('GetWindowInfo', s.win);
				
				s.resetScreenGamma();
				
				if me.useEyeLink
					close(me.eyeTracker);
					me.eyeTracker = [];
				end
				
				s.finaliseMovie(false);
				
				me.stimuli.reset();
				s.close();
				
				if me.useDataPixx || me.useDisplayPP
					stopRecording(io);
					close(io);
				elseif me.useLabJackStrobe
					me.lJack.setDIO([2,0,0]);WaitSecs(0.05);me.lJack.setDIO([0,0,0]); %we stop recording mode completely
					me.lJack.close;
					me.lJack=[];
				end
				
				tL.calculateMisses;
				if tL.nMissed > 0
					fprintf('\n!!!>>> >>> >>> There were %i MISSED FRAMES <<< <<< <<<!!!\n',tL.nMissed);
				end
				
				s.playMovie();
				
				me.isRunning = false;
				
			catch ME
				me.isRunning = false;
				fprintf('\n\n---!!! ERROR in runExperiment.runMOC()\n');
				getReport(ME)
				if me.useDataPixx || me.useDisplayPP
					pauseRecording(io); %pause plexon
					WaitSecs(0.25)
					stopRecording(io);
					close(io);
				end
				%profile off; profile clear
				warning('on')
				Priority(0);
				ListenChar(0);
				ShowCursor;
				resetScreenGamma(s);
				close(s);
				close(me.eyeTracker);
				me.eyeTracker = [];
				me.behaviouralRecord = [];
				close(rM);
				me.lJack=[];
				me.io = [];
				clear tL s tS bR rM eT io sM
				rethrow(ME)	
			end
		end
	
		% ===================================================================
		%> @brief runTask runs a state machine (behaviourally) driven task. Uses a StateInfo.m
		%> file to control the behavioural paradigm. The state machine
		%> controls the logic of the experiment, and this method manages the
		%> display loop.
		%> 
		% ===================================================================
		function runTask(me)
			global rM %#ok<*GVMIS> %global reward manager we can share with eyetracker 
			global aM %global audio manager we can share with eyetracker
			
			%-----make sure we reset any state machine functions to not
			% cause problems when they are reassigned below. For example, io
			% interfaces can be reset unless we clear this before we open
			% the io.	
			me.stateInfo = {};
			if isa(me.stateMachine,'stateMachine'); me.stateMachine.reset; me.stateMachine = []; end
			
			%------initialise the rM global
			if ~isa(rM,'arduinoManager') 
				rM=arduinoManager();
			end
			if rM.isOpen
				rM.close; rM.reset;
			end
			
			%------initialise an audioManager for beeps,playing sounds etc.
			if ~exist('aM','var') || isempty(aM) || ~isa(aM,'audioManager')
				aM=audioManager;
			end
			aM.silentMode = false;
			if ~aM.isSetup;	aM.setup; end
			aM.beep(1000,0.1,0.1);
			
			if isempty(regexpi(me.comment, '^Protocol','once'))
				me.comment = '';
			end
			
			refreshScreen(me);
			initialiseSaveFile(me); %generate a savePrefix for this run
			me.name = [me.subjectName '-' me.savePrefix]; %give us a run name
			if isempty(me.screen) || isempty(me.task)
				me.initialise; %we set up screenManager and taskSequence objects
			end
			if me.screen.isPTB == false %NEED PTB!
				errordlg('There is no working PTB available!')
				error('There is no working PTB available!')
			end
			
			fprintf('\n\n\n===>>> Start task: %s <<<===\n\n\n',me.name);
			
			%------tS is a general structure to hold various parameters
			% will be saved after the run; prefer structure over class 
			% to keep it light. These defaults can be overwritten by the StateFile.m
			tS							= struct();
			tS.name						= 'generic'; %==name of this protocol
			tS.useTask					= false;	%==use taskSequence (randomised variable task object)
			tS.checkKeysDuringStimulus	= false;	%==allow keyboard control? Slight drop in performance
			tS.keyExclusionPattern		= '^(fixate|stim)';
			tS.recordEyePosition		= false;	%==record eye position within PTB, **in addition** to the eyetracker?
			tS.askForComments			= false;	%==little UI requestor asks for comments before/after run
			tS.saveData					= false;	%==save behavioural and eye movement data?
			tS.controlPlexon			= false;	%==send start/stop commands to a plexon?
			tS.rewardTime				= 250;		%==TTL time in milliseconds
			tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
			tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
			tS.useMagStim				= false;
	
			%------initialise time logs for this run
			me.previousInfo.taskLog		= me.taskLog;
			me.runLog					= [];
			me.taskLog					= timeLogger();
			tL							= me.taskLog; %short handle to log
			tL.name						= me.name;
			
			%-----behavioural record
			me.behaviouralRecord		= behaviouralRecord('name',me.name); %#ok<*CPROP>
			bR							= me.behaviouralRecord; %short handle
		
			%------make a short handle to the screenManager and metaStimulus objects
			s							= me.screen; 
			stims						= me.stimuli;
			stims.screen				= s;
			
			%------initialise task
			task						= me.task;
			initialise(task);
			
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			try %================This is our main TASK setup=====================
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				me.isRunning			= true;
				me.isRunTask			= true;
				
				%-----open the eyelink interface
				if me.useTobii
					me.eyeTracker		= tobiiManager();
					if ~isempty(me.tobiisettings); me.eyeTracker.addArgs(me.tobiisettings); end
				else
					me.eyeTracker		= eyelinkManager();
					if ~isempty(me.elsettings); me.eyeTracker.addArgs(me.elsettings); end
				end
				eT						= me.eyeTracker;
				eT.verbose				= me.verbose;
				eT.saveFile				= [me.paths.savedData filesep me.subjectName '-' me.savePrefix '.edf'];
				if ~me.useEyeLink && ~me.useTobii
					eT.isDummy			= true;
				else
					eT.isDummy			= me.dummyMode;
				end
				
				if isfield(tS,'rewardTime')
					bR.rewardTime		= tS.rewardTime;
				end
				
				%--------open the PTB screen and setup stimuli
				me.screenVals			= s.open(me.debug,tL);
				if me.screenVals.fps < 90
					me.fInc = 6;
				else
					me.fInc = 8;
				end
				stims.verbose			= me.verbose;
				setup(stims); %run setup() for each stimulus
				task.fps				= s.screenVals.fps;
				
				%---------initialise and set up I/O
				io						= configureIO(me);
				
				%---------initialise the state machine
				sM						= stateMachine('verbose',me.verbose,'realTime',true,'timeDelta',1e-4,'name',me.name); 
				me.stateMachine			= sM;
				if isempty(me.paths.stateInfoFile) || ~exist(me.paths.stateInfoFile,'file')
					errordlg('Please specify a valid State Machine file...')
				else
					cd(fileparts(me.paths.stateInfoFile))
					me.paths.stateInfoFile = regexprep(me.paths.stateInfoFile,'\s+','\\ ');
					run(me.paths.stateInfoFile)
					me.stateInfo		= stateInfoTmp;
					addStates(sM, me.stateInfo);
				end
				
				%---------set up the eyetracker interface
				if me.useEyeLink
					fprintf('\n===>>> Handing over to eyelink for calibration & validation...\n')
					initialise(eT, s);
					setup(eT);
				elseif me.useTobii
					if length(Screen('Screens')) > 1 && s.screen - 1 >= 0
						ss					= screenManager;
						ss.screen			= 0;
						ss.windowed			= [0 0 1000 1000];
						ss.backgroundColour	= s.backgroundColour;
						ss.bitDepth			= '8bit';
						ss.blend			= true;
						ss.pixelsPerCm		= 30;
					end
					if exist('ss','var')
						initialise(eT,s,ss);
					else
						initialise(eT,s);
					end
					trackerSetup(eT); ShowCursor();
					if ~eT.isConnected && ~eT.isDummy
						warning('Eyetracker is not connected and not in dummy mode, potential connection issue...')
					end
				end

				%--------get pre-run comments for this data collection
				if tS.askForComments
					comment = inputdlg({'CHECK Recording system!!! Initial Comment for this Run?'},['Run Comment for ' me.name]);
					if ~isempty(comment)
						comment = comment{1};
						me.comment = [me.name ':' comment];
						bR.comment = me.comment; eT.comment = me.comment; sM.comment = me.comment; io.comment = me.comment; tL.comment = me.comment; tS.comment = me.comment;
					end
				end
				
				%---------set up our behavioural plot
				createPlot(bR, eT);
				drawnow; 
				commandwindow;

				%------------------------------------------------------------
				% lets draw 1 seconds worth of the stimuli we will be using
				% covered by a blank. Primes the GPU and other components with the sorts
				% of stimuli/tasks used...
				fprintf('\n===>>> Warming up the GPU, Eyetracker and I/O systems... <<<===\n')
				show(stims);
				if me.useEyeLink; trackerClearScreen(eT); end
				for i = 1:s.screenVals.fps*1
					draw(stims);
					drawBackground(s);
					s.drawPhotoDiodeSquare([1 1 1 1]);
					Screen('DrawText',s.win,'Warming up the GPU, Eyetracker and I/O systems...',65,10);
					finishDrawing(s);
					animate(stims);
					if ~mod(i,10); io.sendStrobe(255); end
					if me.useEyeLink || me.useTobii
						getSample(eT); 
						if i == 1; trackerDrawText(eT,'Warming Up System'); end
						if i == 1; trackerMessage(eT,'Warmup test'); end
					end
					flip(s);
				end
				update(stims); %make sure stimuli are set back to their start state
				io.resetStrobe;flip(s);flip(s);
				
				%-----Premptive save in case of crash or error: SAVE IN /TMP
				rE = me;
				htmp = me.screenSettings.optickahandle; me.screenSettings.optickahandle = [];
				%h2tmp = me.behaviouralRecord.h; me.behaviouralRecord.h = [];
				save([tempdir filesep me.name '.mat'],'rE','tS');
				me.screenSettings.optickahandle = htmp; %me.behaviouralRecord.h = h2tmp;
				
				%-----ensure we open the reward manager
				if me.useArduino && isa(rM,'arduinoManager') && ~rM.isOpen
					fprintf('===>>> Opening Arduino for sending reward TTLs\n')
					open(rM);
				elseif  me.useLabJackReward && isa(rM,'labJack')
					fprintf('===>>> Opening LabJack for sending reward TTLs\n')
					open(rM);
				end
				
				%-----Start Plexon in paused mode
				if tS.controlPlexon && (me.useDisplayPP || me.useDataPixx)
					fprintf('\n===>>> Triggering I/O systems... <<<===\n')
					pauseRecording(io); %make sure this is set low first
					startRecording(io);
					WaitSecs(1);
				end
				
				%-----initialise our various counters
				task.tick					= 1;
				task.switched				= 1;
				task.totalRuns				= 1;
				me.isTask					= tS.useTask;
				if me.isTask 
					updateVariables(me, task.totalRuns, true, false); % set to first variable
					update(stims); %update our stimuli ready for display
				else
					updateVariables(me, 1, false, false); % set to first variable
					update(stims); %update our stimuli ready for display
				end
				tS.keyTicks				= 0; %tick counter for reducing sensitivity of keyboard
				tS.keyHold				= 1; %a small loop to stop overeager key presses
				tS.totalTicks			= 1; % a tick counter
				tS.pauseToggle			= 1; %toggle pause/unpause
				tS.eyePos				= []; %locally record eye position
				
				%-----double check the labJackT handle is still valid
				% (sometimes it disconnects)
				if isa(io','labJackT') && ~io.isHandleValid
					io.close;
					io.open;
					warning('We had to reopen the labJackT, ensure connection is stable...')
				end
				
				%-----take over the keyboard!
				KbReleaseWait; %make sure keyboard keys are all released
				commandwindow;
				if me.debug == false
					%warning('off'); %#ok<*WNOFF>
					ListenChar(-1); %2=capture all keystrokes
				end
				Priority(MaxPriority(s.win)); %bump our priority to maximum allowed
				
				%-----profiling starts here
				%profile clear; profile on;
				
				%-----initialise our vbl's
				me.needSample				= false;
				me.stopTask					= false;
				tL.screenLog.beforeDisplay	= GetSecs;
				tL.screenLog.trackerStartTime = getTrackerTime(eT);
				tL.screenLog.trackerStartOffset = getTimeOffset(eT);
				tL.vbl(1)					= Screen('Flip', s.win);
				tL.startTime				= tL.vbl(1);
				
				%-----ignite the stateMachine!
				start(sM); 

				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Our display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				while me.stopTask == false
					
					%------run the stateMachine one tick forward
					update(sM);
					if me.doFlip && s.visualDebug; s.drawGrid; me.infoTextScreen; end
					if me.doFlip; s.finishDrawing(); end % potential optimisation, but note stateMachine may run non-drawing tasks in update()
					
					%------check eye position manually. REMEMBER eyelink will save the real eye data in
					% the EDF this is just a backup wrapped in the PTB loop. 
					if me.needSample; getSample(eT); end
					if tS.recordEyePosition && me.useEyeLink
						saveEyeInfo(me, sM, eT, tS);
					end
					
					%------Check keyboard for commands
					if tS.checkKeysDuringStimulus || ~contains(sM.currentName,tS.keyExclusionPattern)
						tS = checkKeys(me,tS);
					end
					
					%----- FLIP: Show it at correct retrace: -----%
					if me.doFlip
						%------Display++ or DataPixx: I/O send strobe for this screen flip
						%------needs to be sent prior to the flip
						if me.sendStrobe && me.useDisplayPP
							sendStrobe(io); me.sendStrobe = false;
						elseif me.sendStrobe && me.useDataPixx
							triggerStrobe(io); me.sendStrobe = false;
						end
						%------Do the actual Screen flip
						nextvbl = tL.vbl(end) + me.screenVals.halfisi;
						if me.logFrames == true
							[tL.vbl(tS.totalTicks),tL.show(tS.totalTicks),tL.flip(tS.totalTicks),tL.miss(tS.totalTicks)] = Screen('Flip', s.win, nextvbl);
						elseif me.benchmark == true
							tL.vbl = Screen('Flip', s.win, 0, 2, 2);
						else
							tL.vbl = Screen('Flip', s.win, nextvbl);
						end
						%-----LabJack: I/O needs to send strobe immediately after this screen flip
						if me.sendStrobe && me.useLabJackTStrobe
							sendStrobe(io); me.sendStrobe = false;
							%Eyelink('Message', sprintf('MSG:SYNCSTROBE value:%i @ vbl:%20.40g / totalTicks: %i', io.sendValue, tL.vbl(end), tS.totalTicks));
						end
						%----- Send Eyetracker messages
						if me.sendSyncTime % sends SYNCTIME message to eyetracker
							syncTime(eT);
							me.sendSyncTime = false;
						end
						%------Log stim / no stim condition
						if me.logFrames; logStim(tL,sM.currentName,tS.totalTicks); end
						%----- increment our global tick counter
						tS.totalTicks = tS.totalTicks + 1; tL.tick = tS.totalTicks;
					end
					
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				end %======================END OF TASK LOOP=========================
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				
				tL.screenLog.afterDisplay = GetSecs;
				tL.screenLog.trackerEndTime = getTrackerTime(eT);
				tL.screenLog.trackerEndOffset = getTimeOffset(eT);
				
				updatePlot(bR, eT, sM); %update our behavioural plot for final state
				show(stims); %make all stimuli visible again, useful for editing 
				drawBackground(s);
				trackerClearScreen(eT);
				trackerDrawText(eT,['FINISHED TASK:' me.name]);
				Screen('Flip', s.win);
				Priority(0);
				ListenChar(0);
				RestrictKeysForKbCheck([]);
				ShowCursor;
				warning('on');
				
				%notify(me,'endAllRuns');
				me.isRunning = false;
				
				%-----get our profiling report for our task loop
				%profile off; profile report; profile clear
				
				if me.useDisplayPP || me.useDataPixx
					pauseRecording(io); %pause plexon
					WaitSecs(0.5);
					stopRecording(io);
					WaitSecs(0.5);
					close(io);
				end
				
				close(s); %screen
				close(io);
				close(eT); % eyetracker, should save the data for us we've already given it our name and folder
				WaitSecs(0.25);
				close(aM);
				close(rM);
				
				fprintf('\n\n===>>> Total ticks: %g | stateMachine ticks: %g\n', tS.totalTicks, sM.totalTicks);
				fprintf('===>>> Tracker Time: %g | PTB time: %g | Drift Offset: %g\n', ...
					tL.screenLog.trackerEndTime-tL.screenLog.trackerStartTime, ...
					tL.screenLog.afterDisplay-tL.screenLog.beforeDisplay, ...
					tL.screenLog.trackerEndOffset-tL.screenLog.trackerStartOffset);
		
				if isfield(tS,'eO')
					close(tS.eO)
					tS.eO=[];
				end				
				
				if tS.askForComments
					comment = inputdlg('Final Comment for this Run?','Run Comment');
					if ~isempty(comment)
						comment = comment{1};
						me.comment = [me.comment ' | Final Comment: ' comment];
						bR.comment = me.comment;
						eT.comment = me.comment;
						sM.comment = me.comment;
						io.comment = me.comment;
						tL.comment = me.comment;
						tS.comment = me.comment;
					end
				end
				
				me.tS = tS; %copy our tS structure for backup
				
				if tS.saveData
					sname = [me.paths.savedData filesep me.name '.mat'];
					rE = me;
					htmp = me.screenSettings.optickahandle; me.screenSettings.optickahandle = [];
					assignin('base', 'tS', tS);
					save(sname,'rE','tS');
					me.screenSettings.optickahandle = htmp;
					fprintf('\n\n===>>> SAVED DATA to: %s\n\n',sname)
				end
				
				me.stateInfo = [];
				if isa(me.stateMachine,'stateMachine'); me.stateMachine.reset; end
				if isa(me.stimuli,'metaStimulus'); me.stimuli.reset; end
				
				clear rE tL s tS bR rM eT io sM	task
				
			catch ME
				me.isRunning = false;
				fprintf('\n\n===!!! ERROR in runExperiment.runTask()\n');
				getReport(ME)
				if exist('io','var')
					pauseRecording(io); %pause plexon
					WaitSecs(0.25)
					stopRecording(io);
					close(io);
				end
				%profile off; profile clear
				warning('on') 
				if me.useEyeOccluder && isfield(tS,'eO')
					close(tS.eO)
					tS.eO=[];
				end
				Priority(0);
				ListenChar(0); RestrictKeysForKbCheck([]);
				ShowCursor;
				try close(s); end
				try close(aM); end
				try close(eT); end
				me.eyeTracker = [];
				me.behaviouralRecord = [];
				try close(rM); end
				me.lJack=[];
				me.io = [];
				clear tL s tS bR rM eT io sM
				rethrow(ME)
			end

		end
		% ===================================================================
		%> @brief prepare the object for the local machine
		%>
		%> @param config allows excluding screen / task initialisation
		%> @return
		% ===================================================================
		function initialise(me,config)
			if ~exist('config','var')
				config = '';
			end
			if me.debug == true %let screen inherit debug settings
				me.screenSettings.debug = true;
				me.screenSettings.visualDebug = true;
			end
			
			if isempty(regexpi('nostimuli',config)) && (isempty(me.stimuli) || ~isa(me.stimuli,'metaStimulus'))
				me.stimuli = metaStimulus();
			end
			
			if isempty(regexpi('noscreen',config)) && isempty(me.screen)
				me.screen = screenManager(me.screenSettings);
			end
			
			if isempty(regexpi('notask',config)) && isempty(me.task)
				me.task = taskSequence();
			end
			
			if me.useDisplayPP == true
				me.useLabJackStrobe = false;
				me.dPP = plusplusManager();
			elseif me.useDataPixx == true
				me.useLabJackStrobe = false;
				me.dPixx = dPixxManager();
			end
			
			if ~isfield(me.paths,'stateInfoFile') || isempty(me.paths.stateInfoFile)
				if exist([me.paths.root filesep 'DefaultStateInfo.m'],'file')
					me.paths.stateInfoFile = [me.paths.root filesep 'DefaultStateInfo.m'];
				end
			end
				
			if me.screen.isPTB == true
				me.computer=Screen('computer');
				me.ptb=Screen('version');
			end
		
			me.screenVals = me.screen.screenVals;
			
			me.stopTask = false;
			
			if isa(me.runLog,'timeLogger')
				me.runLog.screenLog.prepTime=me.runLog.timer()-me.runLog.screenLog.construct;
			end
			
		end
		
		% ===================================================================
		%> @brief check if stateMachine has finished, set tS.stopTask true
		%>
		%> @param
		% ===================================================================
		function checkTaskEnded(me)
			if me.stateMachine.isRunning && me.task.taskFinished
				me.stopTask = true;
			end
		end
		
		% ===================================================================
		%> @brief check if screenManager is in a good state
		%>
		%> @param
		% ===================================================================
		function error = checkScreenError(me)
			testWindowOpen(me.screen);
			if me.isRunning && ~me.screen.isOpen
				me.isRunning = false;
				error = true;
			else
				error = false;
			end
		end
		
		% ===================================================================
		%> @brief getrunLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function getRunLog(me)
			if isa(me.taskLog,'timeLogger') && me.taskLog.vbl(1) ~= 0
				me.taskLog.printRunLog;
			elseif isa(me.runLog,'timeLogger') && me.runLog.vbl(1) ~= 0
				me.runLog.printRunLog;
			else
				warndlg('No log available yet...');
			end
		end
		
		% ===================================================================
		%> @brief updates eyelink with stimuli position
		%>
		%> @param
		% ===================================================================
		function updateFixationTarget(me, useTask, varargin)
			if ~exist('useTask','var');	useTask = false; end
			if useTask 
				[me.lastXPosition,me.lastYPosition] = getFixationPositions(me.stimuli);
				updateFixationValues(me.eyeTracker, me.lastXPosition, me.lastYPosition, varargin);
			else
				updateFixationValues(me.eyeTracker, me.stimuli.lastXPosition, me.stimuli.lastYPosition);
			end
		end
		
		% ===================================================================
		%> @brief updates eyelink with stimuli position
		%>
		%> @param
		% ===================================================================
		function updateExclusionZones(me, useTask, radius)
			if ~exist('useTask','var');	useTask = false; end
			if useTask 
				[me.lastXExclusion,me.lastYExclusion] = getExclusionPositions(me.stimuli);
				updateExclusionZones(me.eyeTracker, me.lastXExclusion, me.lastYExclusion, radius);
			else 
				updateExclusionZones(me.eyeTracker, me.stimuli.lastXExclusion, me.stimuli.lastYExclusion);
			end
		end
		
		% ===================================================================
		%> @brief checks the variable value of a stimulus (e.g. its angle) and then sets a fixation target based on
		%> that value, so you can use multiple test stimuli and set the target to one of them in a
		%> forced choice paradigm that matches the variable value
		%>
		%> @param stimulus	which stimulus or stimuli to check
		%> @param variable	which variable to check
		%> @param value		which value to check for
		%> @param varargin	additional parameters to set the fixation window
		% ===================================================================
		function updateConditionalFixationTarget(me, stimulus, variable, value, varargin)
			selected = [];
			try
				for i = stimulus
					thisValue = me.stimuli{stimulus}.([variable 'Out']); %get our value
					if ischar(value)
						if strcmpi(thisValue,value); selected = [selected i]; end
					elseif isnumeric(value)
						if all(thisValue == value); selected = [selected i]; end
					end
				end
			end
			if ~isempty(selected)
				me.stimuli.fixationChoice = selected;
				[me.lastXPosition,me.lastYPosition] = getFixationPositions(me.stimuli);
				updateFixationValues(me.eyeTracker, me.lastXPosition, me.lastYPosition, varargin);
			end
		end
		
		% ===================================================================
		%> @brief when running allow keyboard override, so we can edit/debug things
		%>
		%> @param
		% ===================================================================
		function keyOverride(me, tS)
			KbReleaseWait; %make sure keyboard keys are all released
			ListenChar(0); %capture keystrokes
			ShowCursor;
			ii = 0;
			dbstop in clear
			%uiinspect(me)
			clear ii
			dbclear in clear
			ListenChar(-1); %capture keystrokes
			%HideCursor;
		end
		
		% ===================================================================
		%> @brief set.verbose
		%>
		%> Let us cascase verbosity to other classes
		% ===================================================================
		function set.verbose(me,value)
			value = logical(value);
			me.verbose = value;
			if isa(me.task,'taskSequence') %#ok<*MCSUP>
				me.task.verbose = value;
			end
			if isa(me.screen,'screenManager')
				me.screen.verbose = value;
			end
			if isa(me.stateMachine,'stateMachine')
				me.stateMachine.verbose = value;
			end
			if isa(me.eyeTracker,'eyelinkManager')
				me.eyeTracker.verbose = value;
			end
			if isa(me.eyeTracker,'tobiiManager')
				me.eyeTracker.verbose = value;
			end
			if isa(me.lJack,'labJack')
				me.lJack.verbose = value;
			end
			if isa(me.dPixx,'dPixxManager')
				me.dPixx.verbose = value;
			end
			if isa(me.dPP,'plusplusManager')
				me.dPP.verbose = value;
			end
			if isa(me.stimuli,'metaStimulus') && me.stimuli.n > 0
				for i = 1:me.stimuli.n
					me.stimuli{i}.verbose = value;
				end
			end
			me.salutation(sprintf('Cascaded Verbose = %i to all objects...',value),[],true);
		end
		
		% ===================================================================
		%> @brief set.stimuli
		%>
		%> Migrate to use a metaStimulus object to manage stimulus objects
		% ===================================================================
		function set.stimuli(me,in)
			if isempty(me.stimuli) || ~isa(me.stimuli,'metaStimulus')
				me.stimuli = metaStimulus();
			end
			if isa(in,'metaStimulus')
				me.stimuli = in;
			elseif isa(in,'baseStimulus')
				me.stimuli{1} = in;
			elseif iscell(in)
				me.stimuli.stimuli = in;
			end
		end
		
		% ===================================================================
		%> @brief randomiseTrainingList
		%>
		%> For single stimulus presentation, randomise stimulus choice
		% ===================================================================
		function randomiseTrainingList(me)
			if ~isempty(me.thisStim)
				me.thisStim = randi(length(me.stimList));
				me.stimuli.choice = me.thisStim;
			end
		end
		
		% ===================================================================
		%> @brief set strobe value
		%>
		%> 
		% ===================================================================
		function setStrobeValue(me, value)
			if value == Inf; value = me.stimOFFValue; end
			if me.useDisplayPP == true
				prepareStrobe(me.dPP, value);
			elseif me.useDataPixx == true
				prepareStrobe(me.dPixx, value);
			elseif me.useLabJackTStrobe || me.useLabJackStrobe
				prepareStrobe(me.lJack, value)
			end
		end
		
		% ===================================================================
		%> @brief set strobe method to trigger on next flip
		%>
		%> 
		% ===================================================================
		function doStrobe(me, value)
			if isempty(value) || value == true
				me.sendStrobe = true;
			else
				me.sendStrobe = false;
			end
		end
		
		% ===================================================================
		%> @brief send SYNCTIME message to eyelink after flip
		%>
		%> 
		% ===================================================================
		function doSyncTime(me)
			me.sendSyncTime = true;
		end
		
		% ===================================================================
		%> @brief enable screen flip
		%>
		%> 
		% ===================================================================
		function enableFlip(me)
			me.doFlip = true;
		end
		
		% ===================================================================
		%> @brief disable screen flip
		%>
		%> 
		% ===================================================================
		function disableFlip(me)
			me.doFlip = false;
		end
		
		% ===================================================================
		%> @brief get task run index
		%>
		%> 
		% ===================================================================
		function trial = getTaskIndex(me, index)
			if ~exist('index','var') || isempty(index)
				index = me.task.totalRuns;
			end
			if index > 0 && ~isempty(me.task.outIndex) && length(me.task.outIndex) >= index
				trial = me.task.outIndex(index);
			else
				trial = -1;
			end
		end
		
		% ===================================================================
		%> @brief get task run index
		%>
		%> 
		% ===================================================================
		function window = getFixationWindow(me)
			window = me.eyeTracker.fixWindow;
		end
		
		% ===================================================================
		%> @brief updateTask
		%> runs the taskSequence.updateTask function
		%> @param result an integer result, e.g. 1 = correct
		% ===================================================================
		function updateTask(me,result)
			info = '';
			if me.useEyeLink || me.useTobii
				info = sprintf('window = %i; isBlink = %i; isExclusion = %i; isFix = %i; isInitFail = %i; fixTotal = %g ',...
					me.eyeTracker.fixWindow, me.eyeTracker.isBlink, me.eyeTracker.isExclusion, ...
					me.eyeTracker.isFix, me.eyeTracker.isInitFail, me.eyeTracker.fixTotal);
			end
			for i = 1:me.stimuli.n
				info = sprintf('%s stim:%i tick:%i drawtick:%i',info,i,me.stimuli{i}.tick,me.stimuli{i}.drawTick);
			end
			info = [info '\n' me.variableInfo];
			updateTask(me.task,result,GetSecs,info); %do this before getting index
		end
		
		% ===================================================================
		%> @brief updateNextState
		%> taskSequence can generate a trial factor, and we can set these to
		%> the name of a state in the stateMachine. This means we can choose
		%> a state based on the trial factor in taskSequence. This sets
		%> stateMacine.tempNextState to override the state table next field.
		%>
		%> @param type - whether to use 'trial' [default] or 'block' factor
		% ===================================================================
		function updateNextState(me, type)
			if ~exist('type','var'); type = 'trial'; end
			if me.isTask && me.isRunTask
				switch type
					case {'block'}
						thisName = me.task.outBlock{me.task.totalRuns};
					otherwise
						thisName = me.task.outTrial{me.task.totalRuns};
				end
				if ~isempty(thisName) && me.stateMachine.isStateName(thisName)
					if me.verbose; fprintf('!!!>>> Next STATE selected: %s\n',thisName); end
					me.stateMachine.tempNextState = thisName;
				end
			end 
		end
		
		
		% ===================================================================
		%> @brief updateVariables
		%> Updates the stimulus objects with the current variable set from taskSequence()
		%> 
		%> @param index a single value
		%> @param override - forces updating even if it is the same trial
		%> @param update - do we run taskSequence.updateTask() as well?
		% ===================================================================
		function updateVariables(me, index, override, update)
			if ~exist('update','var') || isempty(update)
				update = false;
			end
			if update == true
				me.updateTask(true); %do this before getting new index
			end
			if ~exist('index','var') || isempty(index)
				index = me.task.totalRuns;
			end
			if ~exist('override','var') || isempty(override)
				override = false;
			end
			if me.useDataPixx || me.useDisplayPP || me.useLabJackTStrobe
				if me.isTask
					setStrobeValue(me, me.task.outIndex(index));
				else
					setStrobeValue(me, index);
				end
			end
			if me.isTask && ((index > me.lastIndex) || override == true)
				[thisBlock, thisRun] = me.task.findRun(index);
				stimIdx = []; 
				t = sprintf('B#%i R#%i T#%i = ',thisBlock, thisRun, index);
				for i=1:me.task.nVars
					valueList = cell(1); oValueList = cell(1); %#ok<NASGU>
					doXY = false;
					stimIdx = me.task.nVar(i).stimulus; %which stimuli
					value=me.task.outVars{thisBlock,i}(thisRun);
					if iscell(value)
						value = value{1};
					end
					[valueList{1,1:size(stimIdx,2)}] = deal(value);
					name=[me.task.nVar(i).name 'Out']; %which parameter
					
					if regexpi(name,'^xyPositionOut','once')
						doXY = true;
						me.lastXPosition = value(1);
						me.lastYPosition = value(2);
					elseif regexpi(name,'^xPositionOut','once')
						me.lastXPosition = value;
					elseif regexpi(name,'^yPositionOut','once')
						me.lastYPosition = value;
					elseif regexpi(name,'^sizeOut','once')
						me.lastSize = value;
					end
					
					offsetix = me.task.nVar(i).offsetstimulus;
					offsetvalue = me.task.nVar(i).offsetvalue;
					if ~isempty(offsetix)
						if ischar(offsetvalue)
							mtch = regexpi(offsetvalue,'^(?<name>[^\(\s\d]*)(\(?)(?<num>\d*)(\)?)','names');
							nme = mtch.name;
							num = str2double(mtch.num);
							if ~isempty(nme)
								switch (lower(nme))
									case {'invert'}
										if isnan(num) || isempty(num)
											val = -value;
										else
											val(num) = -value(num);
										end
									case {'yvar'}
										if doXY && ~isnan(num) && ~isempty(num) && length(value)==2
											if rand < 0.5
												val = [value(1) value(2)-num];
											else
												val = [value(1) value(2)+num];
											end
										end
									case {'xvar'}
										if doXY && ~isnan(num) && ~isempty(num) && length(value)==2
											if rand< 0.5
												val = [value(1)-num value(2)];
											else
												val = [value(1)+num value(2)];
											end
										end
									case {'yoffset'}
										if doXY && ~isnan(num) && ~isempty(num) && length(value)==2
											val = [value(1) value(2)+num];
										end
									case {'xoffset'}
										if doXY && ~isnan(num) && ~isempty(num) && length(value)==2
											val = [value(1)+num value(2)];
										end
									otherwise
										val = -value;
								end
							else
								val = value;
							end
						else
							val = value+offsetvalue;
						end
						stimIdx = [stimIdx offsetix];
						[ovalueList{1,1:size(offsetix,2)}] = deal(val);
						valueList = [valueList{:} ovalueList];
					end
				end
				
				a = 1;
				for j = stimIdx %loop through our stimuli references for this variable
					t = [t sprintf('S%i: %s: %s ',j,name,num2str(valueList{a}, '%g '))];
					if ~doXY
						me.stimuli{j}.(name)=valueList{a};
					else
						me.stimuli{j}.xPositionOut=valueList{a}(1);
						me.stimuli{j}.yPositionOut=valueList{a}(2);
					end
					a = a + 1;
				end
					
				me.variableInfo = t;
				me.behaviouralRecord.info = t;
				me.lastIndex = index;
			end
		end
		
		% ===================================================================
		%> @brief set needSample if eyeManager getSample on current flip?
		%>
		%> @param
		% ===================================================================
		function needEyeSample(me,value)
			me.needSample = value;
		end
		
		% ===================================================================
		%> @brief deletes the run logs
		%>
		%> @param
		% ===================================================================
		function deleteRunLog(me)
			me.runLog = [];
			me.taskLog = [];
		end
		
		% ===================================================================
		%> @brief refresh the screen values stored in the object
		%>
		%> @param
		% ===================================================================
		function refreshScreen(me)
			me.screenVals = me.screen.prepareScreen();
			if me.screenVals.fps < 90
				me.fInc = 6;
			else
				me.fInc = 8;
			end
		end
		
		% ===================================================================
		%> @brief print run info to command window
		%>
		%> @param
		% ===================================================================
		function logRun(me,tag)
			if me.isRunning
				if ~exist('tag','var'); tag = '#'; end
				t = me.infoText;
				fprintf('===> %s: %s\n',tag,t);
			end			
		end

		% ===================================================================
		%> @brief no operation, tests method call overhead
		%>
		%> @param
		% ===================================================================
		function noop(me)
			% used to test any overhead of simply calling an empty method
		end
		
		% ===================================================================
		%> @brief called on save, removes opticka handle
		%>
		%> @param
		% ===================================================================
		function out = saveobj(me)
			me.screenSettings.optickahandle = [];
			fprintf('===> Saving runExperiment object...\n')
			out = me;
		end

	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief configureIO
		%> Configures the IO devices.
		%> @param
		% ===================================================================
		function io = configureIO(me)
			global rM
			%-------Set up Digital I/O (dPixx and labjack) for this task run...
			if me.useDisplayPP
				if ~isa(me.dPP,'plusplusManager')
					me.dPP = plusplusManager('verbose',me.verbose);
				end
				io = me.dPP;  %#ok<*PROP>
				io.sM = me.screen;
				io.strobeMode = me.dPPMode;
				me.stimOFFValue = 255;
				io.name = me.name;
				io.verbose = me.verbose;
				io.name = 'runinstance';
				open(io);
				me.useLabJackStrobe = false;
				me.useLabJackTStrobe = false;
				me.useDataPixx = false;
				fprintf('===> Using Display++ for I/O...\n')
			elseif me.useDataPixx
				if ~isa(me.dPixx,'dPixxManager')
					me.dPixx = dPixxManager('verbose',me.verbose);
				end
				io = me.dPixx; io.name = me.name;
				io.stimOFFValue = 2^15;
				io.silentMode = false;
				io.verbose = me.verbose;
				io.name = 'runinstance';
				open(io);
				me.useLabJackStrobe = false;
				me.useLabJackTStrobe = false;
				me.useDisplayPP = false;
				fprintf('===> Using dataPixx for I/O...\n')
			elseif me.useLabJackTStrobe
				if ~isa(me.lJack,'labjackT')
					me.lJack = labJackT('openNow',false,'device',1);
				end
				io = me.lJack; io.name = me.name;
				io.silentMode = false;
				io.verbose = me.verbose;
				io.name = 'runinstance';
				open(io);
				me.useDataPixx = false;
				me.useLabJackStrobe = false;
				me.useDisplayPP = false;
				if io.isOpen
					fprintf('===> Using labjackT for I/O...\n')
				else
					warning('===> !!! labJackT could not properly open !!!');
				end
			elseif me.useLabJackStrobe
				if ~isa(me.lJack,'labjack')
					me.lJack = labJack('openNow',false);
				end
				io = me.lJack; io.name = me.name;
				io.silentMode = false;
				io.verbose = me.verbose;
				io.name = 'runinstance';
				open(io);
				me.useDataPixx = false;
				me.useLabJackTStrobe = false;
				me.useDisplayPP = false;
				if io.isOpen
					fprintf('===> Using labjack for I/O...\n')
				else
					warning('===> !!! labJackT could not properly open !!!');
				end
			else
				io = ioManager();
				io.silentMode = true;
				io.verbose = false;
				io.name = 'silentruninstance';
				me.useDataPixx = false;
				me.useLabJackTStrobe = false;
				me.useLabJackStrobe = false;
				me.useDisplayPP = false;
				fprintf('\n===>>> No strobe output I/O...\n')
			end
			if me.useArduino
				if ~isa(rM,'arduinoManager')
                    rM = arduinoManager();
				end
				if ~rM.isOpen || rM.silentMode
					rM.reset();
					rM.silentMode = false;
					rM.port = me.arduinoPort;
					rM.open();
				end
				me.arduino = rM;
				if rM.isOpen; fprintf('===> Using Arduino for reward TTLs...\n'); end
			elseif ~me.useArduino && ~me.useLabJackReward
				if isa(rM,'arduinoManager')
					rM.close();
					rM.silentMode = true;
				else
					rM = ioManager();
				end
				fprintf('===> No reward TTLs will be sent...\n')
			elseif me.useLabJackReward
				rM = ioManager();
				warning('===> Currently not enabled to use LabJack U3/U6 for reward...')
			else
				rM = ioManager();
			end
			%-----try to open eyeOccluder
			if me.useEyeOccluder
				if ~isfield(tS,'eO') || ~isa(tS.eO,'eyeOccluder')
					tS.eO				= eyeOccluder;
				end
				if tS.eO.isOpen == true
					pause(0.1);
					tS.eO.bothEyesOpen;
				else
					tS.eO				= [];
					tS					= rmfield(tS,'eO');
				end
			end
		end
		
		% ===================================================================
		%> @brief InitialiseTask
		%> Sets up the task structure with dynamic properties
		%> @param
		% ===================================================================
		function initialiseTask(me)
			if isempty(me.task) %we have no task setup, so we generate one.
				me.task=taskSequence;
			end
			me.task.initialise();
		end
		
		% ===================================================================
		%> @brief updateMOCVars
		%> Updates the stimulus objects with the current variable set
		%> @param thisBlock is the current trial
		%> @param thisRun is the current run
		% ===================================================================
		function updateMOCVars(me,thisBlock,thisRun)
			
			if thisBlock > me.task.nBlocks
				return %we've reached the end of the experiment, no need to update anything!
			end
			
			%start looping through out variables
			for i=1:me.task.nVars
				ix = []; valueList = []; oValueList = []; %#ok<NASGU>
				ix = me.task.nVar(i).stimulus; %which stimuli
				value=me.task.outVars{thisBlock,i}(thisRun);
				if iscell(value); value = value{1}; end
				valueList = repmat({value},length(ix),1);
				name=[me.task.nVar(i).name 'Out']; %which parameter
				
				offsetix = me.task.nVar(i).offsetstimulus;
				offsetvalue = me.task.nVar(i).offsetvalue;
				if ~isempty(offsetix)
					ix = [ix offsetix];
					offsetvalue = value + offsetvalue;
					valueList = [valueList; repmat({offsetvalue},length(offsetix),1)];
				end
				
				if me.task.blankTick > 2 && me.task.blankTick <= me.stimuli.n + 2
					%me.stimuli{j}.(name)=value;
				else
					a = 1;
					for j = ix %loop through our stimuli references for this variable
						if me.verbose==true;tic;end
						me.stimuli{j}.(name)=valueList{a};
						if thisBlock == 1 && thisRun == 1 %make sure we update if this is the first run, otherwise the variables may not update properly
							update(me.stimuli, j);
						end
						if me.verbose==true
							fprintf('=-> updateMOCVars() block/trial %i/%i: Variable:%i %s = %s | Stimulus %g -> %g ms\n',thisBlock,thisRun,i,name,num2str(valueList{a}),j,toc*1000);
						end
						a = a + 1;
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief updateMOCTask
		%> Updates the stimulus run state; update the stimulus values for the
		%> current trial and increments the switchTime and switchTick timer
		% ===================================================================
		function updateMOCTask(me)
			me.task.timeNow = GetSecs;
			me.sendStrobe = false;
			
			%--------------first run-----------------
			if me.task.tick == 1 
				fprintf('START @%s\n\n',infoText(me));
				me.task.isBlank = true;
				me.task.startTime = me.task.timeNow;
				me.task.switchTime = me.task.isTime; %first ever time is for the first trial
				me.task.switchTick = me.task.isTime*ceil(me.screenVals.fps);
				setStrobeValue(me,me.task.outIndex(me.task.totalRuns));
			end
			
			%-------------------------------------------------------------------
			if me.task.realTime %we measure real time
				maintain = me.task.timeNow <= (me.task.startTime+me.task.switchTime);
			else %we measure frames, prone to error build-up
				maintain = me.task.tick < me.task.switchTick;
			end
			
			if maintain == true %no need to switch state
				
				if me.task.isBlank == false %showing stimulus, need to call animate for each stimulus
					
					% because the update happens before the flip, but the drawing of the update happens
					% only in the next loop, we have to send the strobe one loop after we set switched
					% to true
					if me.task.switched == true
						me.sendStrobe = true;
					end
					%if me.verbose==true;tic;end
% 					parfor i = 1:me.stimuli.n %parfor appears faster here for 6 stimuli at least
% 						me.stimuli{i}.animate;
% 					end
					animate(me.stimuli);
					%if me.verbose==true;fprintf('=-> updateMOCTask() Stimuli animation: %g ms\n',toc*1000);end
					
				else %this is a blank stimulus
					me.task.blankTick = me.task.blankTick + 1;
					%this causes the update of the stimuli, which may take more than one refresh, to
					%occur during the second blank flip, thus we don't lose any timing.
					if me.task.blankTick == 2 && me.task.tick > 1
						fprintf('@%s\n\n',infoText(me));
						me.task.doUpdate = true;
					end
					% because the update happens before the flip, but the drawing of the update happens
					% only in the next loop, we have to send the strobe one loop after we set switched
					% to true
					if me.task.switched == true
						me.sendStrobe = true;
					end
					% now update our stimuli, we do it after the first blank as less
					% critical timingwise
					if me.task.doUpdate == true
						if ~mod(me.task.thisRun,me.task.minTrials) %are we rolling over into a new trial?
							mT=me.task.thisBlock+1;
							mR = 1;
						else
							mT=me.task.thisBlock;
							mR = me.task.thisRun + 1;
						end
						me.updateMOCVars(mT,mR);
						me.task.doUpdate = false;
					end
					%this dispatches each stimulus update on a new blank frame to
					%reduce overhead.
					if me.task.blankTick > 2 && me.task.blankTick <= me.stimuli.n + 2
						%if me.verbose==true;tic;end
						update(me.stimuli, me.task.blankTick-2);
						%if me.verbose==true;fprintf('=-> updateMOCTask() Blank-frame %i: stimulus %i update = %g ms\n',me.task.blankTick,me.task.blankTick-2,toc*1000);end
					end
					
				end
				me.task.switched = false;
				
				%-------------------------------------------------------------------
			else %need to switch to next trial or blank
				me.task.switched = true;
				if me.task.isBlank == false %we come from showing a stimulus
					%me.logMe('IntoBlank');
					me.task.isBlank = true;
					me.task.blankTick = 0;
					
					if me.task.thisRun == me.task.minTrials %are we within a trial block or not? we add the required time to our switch timer
						me.task.switchTime=me.task.switchTime+me.task.ibTimeNow;
						me.task.switchTick=me.task.switchTick+(me.task.ibTimeNow*ceil(me.screenVals.fps));
						fprintf('IB TIME: %g\n',me.task.ibTimeNow);
					else
						me.task.switchTime=me.task.switchTime+me.task.isTimeNow;
						me.task.switchTick=me.task.switchTick+(me.task.isTimeNow*ceil(me.screenVals.fps));
						fprintf('IS TIME: %g\n',me.task.isTimeNow);
					end
					
					setStrobeValue(me,me.stimOFFValue);%get the strobe word to signify stimulus OFF ready
					%me.logMe('OutaBlank');
					
				else %we have to show the new run on the next flip
					%me.logMe('IntoTrial');
					me.task.switchTime=me.task.switchTime+me.task.trialTime; %update our timer
					me.task.switchTick=me.task.switchTick+(me.task.trialTime*round(me.screenVals.fps)); %update our timer
					me.task.isBlank = false;
					updateTask(me.task);
					if me.task.totalRuns <= me.task.nRuns
						setStrobeValue(me,me.task.outIndex(me.task.totalRuns)); %get the strobe word ready
					end
					%me.logMe('OutaTrial');
				end
			end
		end
		
		% ===================================================================
		%> @brief infoTextScreen - draws text about frame to screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function infoTextScreen(me)
			t=infoText(me);
			Screen('DrawText',me.screen.win,t,5,50,[0.8 0.8 0.8 1],[0.1 0.1 0.1 1]);
		end
		
		% ===================================================================
		%> @brief infoText - info string
		%>
		%> @param
		%> @return
		% ===================================================================
		function t = infoText(me)
			etinfo = '';name=''; uuid = '';
			if me.isRunTask
				log = me.taskLog;
				name = [me.stateMachine.currentName ':' me.stateMachine.currentUUID];
				if me.useEyeLink || me.useTobii
					etinfo = sprintf('| isFix:%i isExcl:%i isFixInit:%i fixLength: %.2f',...
						me.eyeTracker.isFix,me.eyeTracker.isExclusion,me.eyeTracker.isInitFail,me.eyeTracker.fixLength);
				end
			else
				log = me.runLog;
				name = sprintf('%s Blank:%i',name,me.task.isBlank);
			end
			if isempty(me.task.outValues)
				t = sprintf('%s | Time: %3.3f (%i) | isFix: %i | isExclusion: %i | isFixInit: %i',...
					name,(log.vbl(end)-log.startTime), log.tick,...
					me.eyeTracker.isFix,me.eyeTracker.isExclusion,me.eyeTracker.isInitFail);
				return
			else
				var = me.task.outIndex(me.task.totalRuns);
			end
			if me.logFrames == true && log.tick > 1
				t=sprintf('%s | B:%i R:%i [%i/%i] | V: %i | Time: %3.3f (%i) %s',...
					name,me.task.thisBlock, me.task.thisRun, me.task.totalRuns,...
					me.task.nRuns, var, ...
					(log.vbl(end)-log.startTime), log.tick,...
					etinfo);
			else
				t=sprintf('%s | B:%i R:%i [%i/%i] | V: %i | Time: %3.3f (%i) %s',...
					name,me.task.thisBlock,me.task.thisRun,me.task.totalRuns,...
					me.task.nRuns, var, ...
					(log.vbl(1)-log.startTime), log.tick,...
					etinfo);
			end
			for i=1:me.task.nVars
				if iscell(me.task.outVars{me.task.thisBlock,i}(me.task.thisRun))
					t=[t sprintf(' > %s: %s',me.task.nVar(i).name,...
						num2str(me.task.outVars{me.task.thisBlock,i}{me.task.thisRun},'%.2f '))];
				else
					t=[t sprintf(' > %s: %3.3f',me.task.nVar(i).name,...
						me.task.outVars{me.task.thisBlock,i}(me.task.thisRun))];
				end
			end
			if ~isempty(me.variableInfo)
				t = [t me.variableInfo];
			end
		end
		
		% ===================================================================
		%> @brief Logs the run loop parameters along with a calling tag
		%>
		%> Logs the run loop parameters along with a calling tag
		%> @param tag the calling function
		% ===================================================================
		function logMe(me,tag)
			if me.verbose == 1 && me.debug == 1
				if ~exist('tag','var')
					tag='#';
				end
				if isempty(me.task.outValues)
					fprintf('Tick: %i | Time: %5.8g\n',tag,...
						me.task.tick,me.task.timeNow-me.task.startTime);
				else
					fprintf('%s -- B:%i R:%i [%i/%i] | TT: %i | Tick: %i | Time: %5.8g\n',tag,...
						me.task.thisBlock,me.task.thisRun,me.task.totalRuns,me.task.nRuns,...
						me.task.isBlank,me.task.tick,me.task.timeNow-me.task.startTime);
				end
			end
		end
		
		% ===================================================================
		%> @brief save this trial eye info
		%>
		%> @param
		% ===================================================================
		function tS = saveEyeInfo(me,sM,eT,tS)
			switch sM.currentName
				case 'fixate'
					prefix = 'F';
				case 'stimulus'
					prefix = 'E';
				case 'correct'
					prefix = 'CC';
				case 'breakfix'
					prefix = 'BF';
				otherwise
					prefix = 'U';
			end
			if ~strcmpi(prefix,'U')
				uuid = [prefix sM.currentUUID];
				if isfield(tS.eyePos, uuid)
					tS.eyePos.(uuid).x(end+1) = eT.x;
					tS.eyePos.(uuid).y(end+1) = eT.y;
				else
					tS.eyePos.(uuid).x = eT.x;
					tS.eyePos.(uuid).y = eT.y;
				end
			end
		end
		
		% ===================================================================
		%> @brief manage key commands during task loop
		%>
		%> @param args input structure
		% ===================================================================
		function tS = checkKeys(me,tS)
			tS.keyTicks = tS.keyTicks + 1;
			%now lets check whether any keyboard commands are pressed...
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode);
				if iscell(rchar);rchar=rchar{1};end
				switch rchar
					case 'q' %quit
						me.stopTask = true;
					case 'p' %pause the display
						if tS.keyTicks > tS.keyHold
							if strcmpi(me.stateMachine.currentState.name, 'pause')
								forceTransition(me.stateMachine, me.stateMachine.currentState.next);
							else
								flip(me.screen,[],[],2);flip(me.screen,[],[],2)
								forceTransition(me.stateMachine, 'pause');
								tS.pauseToggle = tS.pauseToggle + 1;
							end
							FlushEvents();
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case {'UpArrow','up'}
						if tS.keyTicks > tS.keyHold
							if ~isempty(me.stimuli.controlTable)
								maxl = length(me.stimuli.controlTable);
								if isempty(me.stimuli.tableChoice) && maxl > 0
									me.stimuli.tableChoice = 1;
								end
								if (me.stimuli.tableChoice > 0) && (me.stimuli.tableChoice < maxl)
									me.stimuli.tableChoice = me.stimuli.tableChoice + 1;
								end
								var=me.stimuli.controlTable(me.stimuli.tableChoice).variable;
								delta=me.stimuli.controlTable(me.stimuli.tableChoice).delta;
								fprintf('===>>> Set Control table %g - %s : %g\n',me.stimuli.tableChoice,var,delta)
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case {'DownArrow','down'}
						if tS.keyTicks > tS.keyHold
							if ~isempty(me.stimuli.controlTable)
								maxl = length(me.stimuli.controlTable);
								if isempty(me.stimuli.tableChoice) && maxl > 0
									me.stimuli.tableChoice = 1;
								end
								if (me.stimuli.tableChoice > 1) && (me.stimuli.tableChoice <= maxl)
									me.stimuli.tableChoice = me.stimuli.tableChoice - 1;
								end
								var=me.stimuli.controlTable(me.stimuli.tableChoice).variable;
								delta=me.stimuli.controlTable(me.stimuli.tableChoice).delta;
								fprintf('===>>> Set Control table %g - %s : %g\n',me.stimuli.tableChoice,var,delta)
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
						
					case {'LeftArrow','left'} %previous variable 1 value
						if tS.keyTicks > tS.keyHold
							if ~isempty(me.stimuli.controlTable) && ~isempty(me.stimuli.controlTable.variable)
								choice = me.stimuli.tableChoice;
								if isempty(choice)
									choice = 1;
								end
								var = me.stimuli.controlTable(choice).variable;
								delta = me.stimuli.controlTable(choice).delta;
								stims = me.stimuli.controlTable(choice).stimuli;
								thisstim = me.stimuli.stimulusSets{me.stimuli.setChoice}; %what stimulus is visible?
								stims = intersect(stims,thisstim); %only change the visible stimulus
								limits = me.stimuli.controlTable(choice).limits;
								for i = 1:length(stims)
									if ~isa(me.stimuli{stims(i)},'barStimulus') && (strcmpi(var,'size') || strcmpi(var,'dotSize'))
										oval = me.stimuli{stims(i)}.([var 'Out']) / me.stimuli{stims(i)}.ppd;
									elseif strcmpi(var,'sf')
										oval = me.stimuli{stims(i)}.getsfOut;
									else
										oval = me.stimuli{stims(i)}.([var 'Out']);
									end
									val = oval - delta;
									if min(val) < limits(1)
										val(val < limits(1)) = limits(2);
									elseif max(val) > limits(2)
										val(val > limits(2)) = limits(1);
									end
									if length(val) > length(oval)
										val = val(1:length(oval));
									end
									me.stimuli{stims(i)}.([var 'Out']) = val;
									me.stimuli{stims(i)}.update();
									fprintf('===>>> Stimulus #%i -- %s: %.3f (%.3f)\n',stims(i),var,val,oval)
								end
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case {'RightArrow','right'} %next variable 1 value
						if tS.keyTicks > tS.keyHold
							if ~isempty(me.stimuli.controlTable) && ~isempty(me.stimuli.controlTable.variable)
								choice = me.stimuli.tableChoice;
								if isempty(choice)
									choice = 1;
								end
								var = me.stimuli.controlTable(choice).variable;
								delta = me.stimuli.controlTable(choice).delta;
								stims = me.stimuli.controlTable(choice).stimuli;
								thisstim = me.stimuli.stimulusSets{me.stimuli.setChoice}; %what stimulus is visible?
								stims = intersect(stims,thisstim); %only change the visible stimulus
								limits = me.stimuli.controlTable(choice).limits;
								for i = 1:length(stims)
									if ~isa(me.stimuli{stims(i)},'barStimulus') && (strcmpi(var,'size') || strcmpi(var,'dotSize'))
										oval = me.stimuli{stims(i)}.([var 'Out']) / me.stimuli{stims(i)}.ppd;
									elseif strcmpi(var,'sf')
										oval = me.stimuli{stims(i)}.getsfOut;
									else
										oval = me.stimuli{stims(i)}.([var 'Out']);
									end
									val = oval + delta;
									if min(val) < limits(1)
										val(val < limits(1)) = limits(2);
									elseif max(val) > limits(2)
										val(val > limits(2)) = limits(1);
									end
									if length(val) > length(oval)
										val = val(1:length(oval));
									end
									me.stimuli{stims(i)}.([var 'Out']) = val;
									me.stimuli{stims(i)}.update();
									fprintf('===>>> Stimulus #%i -- %s: %.3f (%.3f)\n',stims(i),var,val,oval)
								end
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case ',<'
						if tS.keyTicks > tS.keyHold
							if me.stimuli.setChoice > 1
								me.stimuli.setChoice = round(me.stimuli.setChoice - 1);
								me.stimuli.showSet();
							end
							fprintf('===>>> Stimulus Set: #%g | Stimuli: %s\n',me.stimuli.setChoice, num2str(me.stimuli.stimulusSets{me.stimuli.setChoice}))
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '.>'
						if tS.keyTicks > tS.keyHold
							if me.stimuli.setChoice < length(me.stimuli.stimulusSets)
								me.stimuli.setChoice = me.stimuli.setChoice + 1;
								me.stimuli.showSet();
							end
							fprintf('===>>> Stimulus Set: #%g | Stimuli: %s\n',me.stimuli.setChoice, num2str(me.stimuli.stimulusSets{me.stimuli.setChoice}))
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'r'
						timedTTL(rM,rM.rewardPin,rM.rewardTime);
					case '=+'
						if tS.keyTicks > tS.keyHold
							me.screen.screenXOffset = me.screen.screenXOffset + 1;
							fprintf('===>>> Screen X Center: %g deg / %g pixels\n',me.screen.screenXOffset,me.screen.xCenter);
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '-_'
						if tS.keyTicks > tS.keyHold
							me.screen.screenXOffset = me.screen.screenXOffset - 1;
							fprintf('===>>> Screen X Center: %g deg / %g pixels\n',me.screen.screenXOffset,me.screen.xCenter);
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '[{'
						if tS.keyTicks > tS.keyHold
							me.screen.screenYOffset = me.screen.screenYOffset - 1;
							fprintf('===>>> Screen Y Center: %g deg / %g pixels\n',me.screen.screenYOffset,me.screen.yCenter);
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case ']}'
						if tS.keyTicks > tS.keyHold
							me.screen.screenYOffset = me.screen.screenYOffset + 1;
							fprintf('===>>> Screen Y Center: %g deg / %g pixels\n',me.screen.screenYOffset,me.screen.yCenter);
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'k'
						if tS.keyTicks > tS.keyHold
							stateName = 'blank';
							[isState, index] = isStateName(me.stateMachine,stateName);
							if isState
								t = me.stateMachine.getState(stateName);
								if isfield(t,'time')
									tout = t.time - 0.25;
									if min(tout) >= 0.1
										me.stateMachine.editStateByName(stateName,'time',tout);
										fprintf('===>>> Decrease %s time: %g:%g\n',t.name, min(tout),max(tout));
									end
								end
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'l'
						if tS.keyTicks > tS.keyHold
							stateName = 'blank';
							[isState, index] = isStateName(me.stateMachine,stateName);
							if isState
								t = me.stateMachine.getState(stateName);
								if isfield(t,'time')
									tout = t.time + 0.25;
									me.stateMachine.editStateByName(stateName,'time',tout);
									fprintf('===>>> Increase %s time: %g:%g\n',t.name, min(tout),max(tout));
								end
								
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'y'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> Calibrate ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'calibrate');
							return
						end
					case 'u'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> Drift OFFSET ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'offset');
							return
						end
					case 'i'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> Drift CORRECT ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'drift');
							return
						end
					case 'f'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> Flash ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'flash');
							return
						end
					case 't'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> MagStim ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'magstim');
							return
						end
					case ';'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> Override ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'override');
							return
						end
					case 'g'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> grid ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'showgrid');
							return
						end
					case 'z'
						if tS.keyTicks > tS.keyHold
							me.eyeTracker.fixation.initTime = me.eyeTracker.fixation.initTime - 0.1;
							if me.eyeTracker.fixation.initTime < 0.01
								me.eyeTracker.fixation.initTime = 0.01;
							end
							tS.firstFixInit = me.eyeTracker.fixation.initTime;
							fprintf('===>>> FIXATION INIT TIME: %g\n',me.eyeTracker.fixation.initTime)
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'x'
						if tS.keyTicks > tS.keyHold
							me.eyeTracker.fixation.initTime = me.eyeTracker.fixation.initTime + 0.1;
							tS.firstFixInit = me.eyeTracker.fixation.initTime;
							fprintf('===>>> FIXATION INIT TIME: %g\n',me.eyeTracker.fixation.initTime)
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'c'
						if tS.keyTicks > tS.keyHold
							me.eyeTracker.fixation.time = me.eyeTracker.fixation.time - 0.1;
							if me.eyeTracker.fixation.time < 0.01
								me.eyeTracker.fixation.time = 0.01;
							end
							tS.firstFixTime = me.eyeTracker.fixation.time;
							fprintf('===>>> FIXATION TIME: %g\n',me.eyeTracker.fixation.time)
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'v'
						if tS.keyTicks > tS.keyHold
							me.eyeTracker.fixation.time = me.eyeTracker.fixation.time + 0.1;
							tS.firstFixTime = me.eyeTracker.fixation.time;
							fprintf('===>>> FIXATION TIME: %g\n',me.eyeTracker.fixation.time)
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'b'
						if tS.keyTicks > tS.keyHold
							me.eyeTracker.fixation.radius = me.eyeTracker.fixation.radius - 0.1;
							if me.eyeTracker.fixation.radius < 0.1
								me.eyeTracker.fixation.radius = 0.1;
							end
							tS.firstFixRadius = me.eyeTracker.fixation.radius;
							fprintf('===>>> FIXATION RADIUS: %g\n',me.eyeTracker.fixation.radius)
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'n'
						if tS.keyTicks > tS.keyHold
							me.eyeTracker.fixation.radius = me.eyeTracker.fixation.radius + 0.1;
							tS.firstFixRadius = me.eyeTracker.fixation.radius;
							fprintf('===>>> FIXATION RADIUS: %g\n',me.eyeTracker.fixation.radius)
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 's'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> Show Cursor!\n');
							ShowCursor('CrossHair',me.screen.win);
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'd'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> Hide Cursor!\n');
							HideCursor(me.screen.win);
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '1!'
						if tS.keyTicks > tS.keyHold
							if isfield(tS,'eO') && tS.eO.isOpen == true
								bothEyesOpen(tS.eO)
								Eyelink('Command','binocular_enabled = NO')
								Eyelink('Command','active_eye = LEFT')
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '2@'
						if tS.keyTicks > tS.keyHold
							if isfield(tS,'eO') && tS.eO.isOpen == true
								bothEyesClosed(tS.eO)
								Eyelink('Command','binocular_enabled = NO');
								Eyelink('Command','active_eye = LEFT');
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '3#'
						if tS.keyTicks > tS.keyHold
							if isfield(tS,'eO') && tS.eO.isOpen == true
								leftEyeClosed(tS.eO)
								Eyelink('Command','binocular_enabled = NO');
								Eyelink('Command','active_eye = RIGHT');
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '4$'
						if tS.keyTicks > tS.keyHold
							if isfield(tS,'eO') && tS.eO.isOpen == true
								rightEyeClosed(tS.eO)
								Eyelink('Command','binocular_enabled = NO');
								Eyelink('Command','active_eye = LEFT');
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
				end
			end
		end
		
	end %-------END PRIVATE METHODS
	
	%=======================================================================
	methods (Static = true) %------------------STATIC METHODS
	%=======================================================================
	
		function plotEyeLogs(tS)
			ifi = 0.013;
			tS = tS.eyePos;
			fn = fieldnames(tS);
			h=figure;
			set(gcf,'Color',[1 1 1]);
			figpos(1,[1200 1200]);
			p = panel(h);
			p.pack(2,2);
			a = 1;
			stdex = [];
			stdey = [];
			early = [];
			for i = 1:length(fn)-1
				if ~isempty(regexpi(fn{i},'^E')) && ~isempty(regexpi(fn{i+1},'^CC'))
					x = tS.(fn{i}).x;
					y = tS.(fn{i}).y;
					%if a < Inf%(max(x) < 16 && min(x) > -16) && (max(y) < 16 && min(y) > -16) && mean(abs(x(1:10))) < 1 && mean(abs(y(1:10))) < 1
						c = rand(1,3);
						p(1,1).select();
						p(1,1).hold('on')
						plot(x, y,'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);

						p(1,2).select();
						p(1,2).hold('on');
						t = 0:ifi:(ifi*length(x));
						t = t(1:length(x));
						plot(t,abs(x),'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						plot(t,abs(y),'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						
						p(2,1).select();
						p(2,1).hold('on');
						plot(mean(x(1:10)), mean(y(1:10)),'ko','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						stdex = [stdex std(x(1:10))];
						stdey = [stdey std(y(1:10))];
						
						p(2,2).select();
						p(2,2).hold('on');
						plot3(mean(x(1:10)), mean(y(1:10)),a,'ko','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						
						if mean(x(14:16)) > 5 || mean(y(14:16)) > 5
							early(a) = 1;
						else
							early(a) = 0;
						end
						
						a = a + 1;
						
					%end
				end
			end
			
			p(1,1).select();
			grid on
			box on
			axis square
			title('X vs. Y Eye Position in Degrees')
			xlabel('X Degrees')
			ylabel('Y Degrees')
			
			p(1,2).select();
			grid on
			box on
			title(sprintf('X and Y Position vs. time | Early = %g / %g', sum(early),length(early)))
			xlabel('Time (s)')
			ylabel('Degrees')
			
			p(2,1).select();
			grid on
			box on
			axis square
			title(sprintf('Average X vs. Y Position for first 150ms STDX: %g | STDY: %g',mean(stdex),mean(stdey)))
			xlabel('X Degrees')
			ylabel('Y Degrees')
			
			p(2,2).select();
			grid on
			box on
			axis square
			title('Average X vs. Y Position for first 150ms Over Time')
			xlabel('X Degrees')
			ylabel('Y Degrees')
			zlabel('Trial')
		end
		
		% ===================================================================
		%> @brief loadobj
		%> To be backwards compatible to older saved protocols, we have to parse 
		%> structures / objects specifically during object load
		%> @param in input object/structure
		% ===================================================================
		function lobj=loadobj(in)
			if isa(in,'runExperiment')
				lobj = in;
				name = '';
				if isprop(lobj,'fullName')
					name = [name 'NEW:' lobj.fullName];
				end
				fprintf('---> runExperiment loadobj: %s\n',name);
				isObject = true;
				setPaths(lobj);
				rebuild();
				return
			else
				lobj = runExperiment;
				name = '';
				if isprop(lobj,'fullName')
					name = [name 'NEW:' lobj.fullName];
				end
				if isprop(in,'name')
					name = [name '<--OLD:' in.name];
				end
				fprintf('---> runExperiment loadobj %s: Loading legacy structure...\n',name);
				isObject = false;
				lobj.initialise('notask noscreen nostimuli');
				rebuild();
			end
			
			
			function me = rebuild()
				fprintf('------> ');
				try %#ok<*TRYNC>
					if (isprop(in,'stimuli') || isfield(in,'stimuli')) && isa(in.stimuli,'metaStimulus')
						if ~isObject
							lobj.stimuli = in.stimuli;
							fprintf('metaStimulus object loaded | ');
						else
							fprintf('metaStimulus object present | ');
						end
					elseif isfield(in,'stimulus') || isprop(in,'stimulus')
						if iscell(in.stimulus) && isa(in.stimulus{1},'baseStimulus')
							lobj.stimuli = metaStimulus();
							lobj.stimuli.stimuli = in.stimulus;
							fprintf('Legacy Stimuli | ');
						elseif isa(in.stimulus,'metaStimulus')
							me.stimuli = in.stimulus;
							fprintf('Stimuli (old field) = metaStimulus object | ');
						else
							fprintf('NO STIMULI!!! | ');
						end
					end
					if isfield(in.paths,'stateInfoFile') 
						if exist(in.paths.stateInfoFile,'file')
							if ~isObject; lobj.paths.stateInfoFile = in.paths.stateInfoFile;end
							fprintf('stateInfoFile assigned');
						else
							tp = in.paths.stateInfoFile;
							tp = regexprep(tp,'(^/\w+/\w+)',lobj.paths.home);
							if exist(tp,'file')
								lobj.paths.stateInfoFile = tp;
								fprintf('stateInfoFile rebuilt');
							end
						end
					elseif isprop(in,'stateInfoFile') || isfield(in,'stateInfoFile')
						if exist(in.stateInfoFile,'file')
							lobj.paths.stateInfoFile = in.stateInfoFile;
							fprintf('stateInfoFile assigned');
						end
					end
					if isa(in.task,'taskSequence') 
						lobj.task = in.task;
						fprintf(' | loaded taskSequence');
					elseif isa(in.task,'stimulusSequence')
						if isstruct(in.task)
							tso = in.task;
						else
							tso = clone(in.task);
						end
						ts = taskSequence();
						if isprop(tso,'nVar') || isfield(tso,'nVar')
							ts.nVar = tso.nVar;
						end
						if isprop(tso,'nBlocks') || isfield(tso,'nBlocks')
							ts.nBlocks = in.task.nBlocks;
						end
						if isprop(tso,'randomSeed') || isfield(tso,'randomSeed')
							ts.randomSeed = in.task.randomSeed;
						end
						if isfield(tso,'isTime') || isprop(tso,'isTime')
							ts.isTime = in.task.isTime;
						end
						if isfield(tso,'ibTime') || isprop(tso,'ibTime')
							ts.ibTime = in.task.ibTime;
						end
						if isfield(tso,'trialTime') || isprop(tso,'trialTime')
							ts.trialTime = in.task.trialTime;
						end
						if isfield(tso,'randomise') || isprop(tso,'randomise')
							ts.randomise = in.task.randomise;
						end
						if isfield(tso,'realTime') || isprop(tso,'realTime')
							ts.realTime = in.task.realTime;
						end
						lobj.task = ts;
						fprintf(' | reconstructed taskSequence %s from %s',ts.fullName,tso.fullName);
						clear tso ts
					elseif isa(lobj.task,'taskSequence')
						lobj.previousInfo.task = in.task;
						fprintf(' | inherited taskSequence');
					else
						lobj.task = taskSequence();
						fprintf(' | new taskSequence');
					end
					if ~isObject && isfield(in,'verbose')
						lobj.verbose = in.verbose;
					end
					if ~isObject && isfield(in,'debug')
						lobj.debug = in.debug;
					end
					if ~isObject && isfield(in,'useLabJack')
						lobj.useLabJackReward = in.useLabJack;
					end
				end
				try
					if ~isa(in.screen,'screenManager') %this is an old object, pre screenManager
						lobj.screen = screenManager();
						lobj.screen.distance = in.distance;
						lobj.screen.pixelsPerCm = in.pixelsPerCm;
						lobj.screen.screenXOffset = in.screenXOffset;
						lobj.screen.screenYOffset = in.screenYOffset;
						lobj.screen.antiAlias = in.antiAlias;
						lobj.screen.srcMode = in.srcMode;
						lobj.screen.windowed = in.windowed;
						lobj.screen.dstMode = in.dstMode;
						lobj.screen.blend = in.blend;
						lobj.screen.hideFlash = in.hideFlash;
						lobj.screen.movieSettings = in.movieSettings;
						fprintf(' | regenerated screenManager');
					elseif ~strcmpi(in.screen.uuid,lobj.screen.uuid)
						lobj.screen = in.screen;
						in.screen.verbose = false; %no printout
						%in.screen = []; %force close any old screenManager instance;
						fprintf(' | inherited screenManager');
					else
						fprintf(' | loaded screenManager');
					end
				end
				try
					lobj.previousInfo.runLog = in.runLog;
					lobj.previousInfo.computer = in.computer;
					lobj.previousInfo.ptb = in.ptb;
					lobj.previousInfo.screenVals = in.screenVals;
					lobj.previousInfo.screenSettings = in.screenSettings;
				end
				try lobj.stateMachine		= in.stateMachine; end
				try lobj.eyeTracker			= in.eyeTracker; end
				try lobj.behaviouralRecord	= in.behaviouralRecord; end
				try lobj.runkLog			= in.runLog; end
				try lobj.taskLog			= in.taskLog; end
				try lobj.stateInfo			= in.stateInfo; end
				try lobj.comment			= in.comment; end
				fprintf('\n');
			end
		end
		
	end
	
end
