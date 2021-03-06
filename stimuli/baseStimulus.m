% ========================================================================
%> @brief baseStimulus is the superclass for all opticka stimulus objects
%>
%> Superclass providing basic structure for all stimulus classes. This is a dynamic properties
%> descendant, allowing for the temporary run variables used, which get appended "name"Out, i.e.
%> speed is duplicated to a dymanic property called speedOut; it is the dynamic propertiy which is
%> used during runtime, and whose values are converted from definition units like degrees to pixel
%> values that PTB uses. The transient copies are generated on setup and removed on reset.
%>
%>
%> Copyright ©2014-2021 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef baseStimulus < optickaCore & dynamicprops
	
	properties (Abstract = true)
		%> stimulus type
		type char
	end
	
	properties (Abstract = true, SetAccess = protected)
		%> the stimulus family (grating, dots etc.)
		family char
	end
	
	properties
		%> X Position ± degrees relative to screen center (0,0)
		xPosition double = 0
		%> Y Position ± degrees relative to screen center (0,0)
		yPosition double = 0
		%> Size in degrees
		size double = 4
		%> Colour as a 0-1 range RGB
		colour double = [1 1 1]
		%> Alpha as a 0-1 range, this gets added to the RGB colour
		alpha double = 1
		%> For moving stimuli do we start "before" our initial position? This allows you to
		%> center a stimulus at a screen location, but then drift it across that location, so
		%> if xyPosition is 0,0 and startPosition is -2 then the stimulus will start at -2 drifing
		%> towards 0.
		startPosition double = 0
		%> speed in degs/s
		speed double = 0
		%> angle in degrees
		angle double = 0
		%> animation manager: can assign an animationManager() object that handles
		%> more complex animation paths than simple builtin linear motion
		animator = []
		%> delay time to display relative to stimulus onset, can set upper and lower range
		%> for random interval. This allows for a group of stimuli some to be delayed relative
		%> to others for a global stimulus onset time.
		delayTime double = 0
		%> time to turn stimulus off, relative to stimulus onset
		offTime double = Inf
		%> override X and Y position with mouse input? Useful for RF mapping
		mouseOverride logical = false
		%> true or false, whether to draw() this object
		isVisible logical = true
		%> show the position on the Eyetracker display?
		showOnTracker logical = true
		%> Do we print details to the commandline?
		verbose = false
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> computed X position
		xOut double = []
		%> computed Y position
		yOut double = []
		%> initial screen rectangle position [LEFT TOP RIGHT BOTTOM]
		dstRect double = []
		%> current screen rectangle position [LEFT TOP RIGHT BOTTOM]
		mvRect double = []
		%> tick updates +1 on each call of draw (even if delay or off is true and no stimulus is drawn, resets on each update
		tick double = 0
		%> draw tick only updates when a draw command is called, resets on each update
		drawTick double = 0
		%> pixels per degree (normally inhereted from screenManager)
		ppd double = 36
		%> is stimulus position defined as rect [true] or point [false]
		isRect logical = true
	end
	
	properties (Dependent = true, SetAccess = protected, GetAccess = public)
		%> What our per-frame motion delta is
		delta double
		%> X update which is computed from our speed and angle
		dX double
		%> X update which is computed from our speed and angle
		dY double
	end
	
	properties (SetAccess = protected, Transient = true)
		%> Our texture pointer for texture-based stimuli
		texture double
		%> handles for the GUI
		handles struct
		%> our screen manager
		sM screenManager
		%> screen settings generated by sM on setup
		screenVals struct = struct('ifi',1/60,'fps',60,'winRect',[0 0 1920 1080])
		%. is object set up?
		isSetup logical = false
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> is mouse position within screen co-ordinates?
		mouseValid logical = false
		%> mouse X position
		mouseX double = 0
		%> mouse Y position
		mouseY double = 0
		%> delay ticks to wait until display
		delayTicks double = 0
		%> ticks before stimulus turns off
		offTicks double = Inf
		%>are we setting up?
		inSetup logical = false
		%> delta cache
		delta_
		%> dX cache
		dX_
		%> dY cache
		dY_
		% deal with interaction of colour and alpha
		isInSetColour logical = false
		%> Which properties to ignore to clone when making transient copies in
		%> the setup method
		ignorePropertiesBase char = ['handles|ppd|sM|name|comment|fullName|'...
			'family|type|dX|dY|delta|verbose|texture|dstRect|mvRect|xOut|'...
			'yOut|isVisible|dateStamp|paths|uuid|tick|doAnimator|doDots|mouseOverride|isRect'...
			'dstRect|mvRect|sM|screenVals|isSetup'];
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be passed on construction
		allowedProperties char = ['xPosition|yPosition|size|colour|verbose|'...
			'alpha|startPosition|angle|speed|delayTime|mouseOverride|isVisible'...
			'showOnTracker|animator'];
	end
	
	events
		%> triggered when reading from a UI panel,
		readPanelUpdate
	end

	%=======================================================================
	methods (Abstract)%------------------ABSTRACT METHODS
	%=======================================================================
		%> initialise the stimulus with the PTB screenManager
		out = setup(runObject)
		%>draw to the screen buffer, ready for flip()
		out = draw(runObject)
		%> animate the stimulus, normally called after a draw
		out = animate(runObject)
		%> update the stimulus, normally called between trials if any
		%>variables have changed
		out = update(runObject)
		%> reset back to pre-setup state (removes the transient cache
		%> properties, resets the various timers etc.)
		out = reset(runObject)
	end %---END ABSTRACT METHODS---%
	
	%=======================================================================
	methods %----------------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> @param varargin are passed as a structure / cell of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function me = baseStimulus(varargin)
			me=me@optickaCore(varargin); %superclass constructor
			me.parseArgs(varargin, me.allowedProperties);
		end
		
		% ===================================================================
		%> @brief colour set method
		%> Allow 1 (R=G=B) 3 (RGB) or 4 (RGBA) value colour
		% ===================================================================
		function set.colour(me,value)
			me.isInSetColour = true; %#ok<*MCSUP>
			len=length(value);
			switch len
				case 4
					me.colour = value(1:4);
					me.alpha = value(4);
				case 3
					me.colour = [value(1:3) me.alpha]; %force our alpha to override
				case 1
					me.colour = [value value value me.alpha]; %construct RGBA
				otherwise
					if isa(me,'gaborStimulus') || isa(me,'gratingStimulus')
						me.colour = []; %return no colour to procedural gratings
					else
						me.colour = [1 1 1 me.alpha]; %return white for everything else
					end		
			end
			me.colour(me.colour<0)=0; me.colour(me.colour>1)=1;
			me.isInSetColour = false;
		end
		
		% ===================================================================
		%> @brief alpha set method
		%> 
		% ===================================================================
		function set.alpha(me,value)
			if value<0; value=0;elseif value>1; value=1; end
			me.alpha = value;
			if ~me.isInSetColour
				me.colour = me.colour(1:3); %force colour to be regenerated
				if isprop(me,'colour2')
					me.colour2 = me.colour2(1:3);
				end
			end
		end
		
		% ===================================================================
		%> @brief delta Get method
		%> delta is the normalised number of pixels per frame to move a stimulus
		% ===================================================================
		function value = get.delta(me)
			if isempty(me.findprop('speedOut'))
				value = (me.speed * me.ppd) * me.screenVals.ifi;
			else
				value = (me.speedOut * me.ppd) * me.screenVals.ifi;
			end
		end
		
		% ===================================================================
		%> @brief dX Get method
		%> X position increment for a given delta and angle
		% ===================================================================
		function value = get.dX(me)
			value = 0;
			if ~isempty(me.findprop('directionOut'))
				[value,~]=me.updatePosition(me.delta,me.directionOut);
			elseif ~isempty(me.findprop('angleOut'))
				[value,~]=me.updatePosition(me.delta,me.angleOut);
			end
		end
		
		% ===================================================================
		%> @brief dY Get method
		%> Y position increment for a given delta and angle
		% ===================================================================
		function value = get.dY(me)
			value = 0;
			if ~isempty(me.findprop('directionOut'))
				[~,value]=me.updatePosition(me.delta,me.directionOut);
			elseif ~isempty(me.findprop('angleOut'))
				[~,value]=me.updatePosition(me.delta,me.angleOut);
			end
		end
		
		% ===================================================================
		%> @brief Method to set isVisible=true.
		%>
		% ===================================================================
		function show(me)
			me.isVisible = true;
		end
		
		% ===================================================================
		%> @brief Method to set isVisible=false.
		%>
		% ===================================================================
		function hide(me)
			me.isVisible = false;
		end
		
		% ===================================================================
		%> @brief reset the various tick counters for our stimulus
		%>
		% ===================================================================
		function resetTicks(me)
			global mouseTick mouseGlobalX mouseGlobalY %shared across all stimuli
			if max(me.delayTime) > 0 %delay display a number of frames 
				if length(me.delayTime) == 1
					me.delayTicks = round(me.delayTime/me.screenVals.ifi);
				elseif length(me.delayTime) == 2
					time = randi([me.delayTime(1)*1000 me.delayTime(2)*1000])/1000;
					me.delayTicks = round(time/me.screenVals.ifi);
				end
			else
				me.delayTicks = 0;
			end
			if min(me.offTime) < Inf %delay display a number of frames 
				if length(me.offTime) == 1
					me.offTicks = round(me.offTime/me.screenVals.ifi);
				elseif length(me.offTime) == 2
					time = randi([me.offTime(1)*1000 me.offTime(2)*1000])/1000;
					me.offTicks = round(time/me.screenVals.ifi);
				end
			else
				me.offTicks = Inf;
			end
			mouseTick = 0; mouseGlobalX = 0; mouseGlobalY = 0;
			me.mouseX = 0; me.mouseY = 0;
			me.tick = 0; 
			me.drawTick = 0;
		end
		
		% ===================================================================
		%> @brief get mouse position
		%> we make sure this is only called once per animation tick to
		%> improve performance and ensure all stimuli that are following
		%> mouse position have consistent X and Y per frame update
		%> This sets mouseX and mouseY and mouseValid if mouse is within
		%> PTB screen (useful for mouse override positioning for stimuli)
		% ===================================================================
		function getMousePosition(me)
			global mouseTick mouseGlobalX mouseGlobalY
			me.mouseValid = false;
			if me.tick > mouseTick
				if ~isempty(me.sM) && isa(me.sM,'screenManager') && me.sM.isOpen
					[me.mouseX,me.mouseY] = GetMouse(me.sM.win);
					if me.mouseX > 0 && me.mouseY > 0 && me.mouseX <= me.sM.screenVals.width && me.mouseY <= me.sM.screenVals.height
						me.mouseValid = true;
					end
				else
					[me.mouseX,me.mouseY] = GetMouse;
				end
				mouseTick = me.tick; %set global so no other object with same tick number can call this again
				mouseGlobalX = me.mouseX; mouseGlobalY = me.mouseY;
			else
				if ~isempty(mouseGlobalX) && ~isempty(mouseGlobalY)
					me.mouseX = mouseGlobalX; me.mouseY = mouseGlobalY; me.mouseValid = true;
				end
			end
		end
		
		% ===================================================================
		%> @brief Run Stimulus in a window to preview
		%>
		% ===================================================================
		function run(me, benchmark, runtime, s, forceScreen, showVBL)
		% run(benchmark, runtime, s, forceScreen, showVBL)
			try
				warning off
				if ~exist('benchmark','var') || isempty(benchmark)
					benchmark=false;
				end
				if ~exist('runtime','var') || isempty(runtime)
					runtime = 2; %seconds to run
				end
				if ~exist('s','var') || ~isa(s,'screenManager')
					if isempty(me.sM); me.sM=screenManager; end
					s = me.sM;
					s.blend = true;
					s.disableSyncTests = true;
					s.visualDebug = true;
					s.bitDepth = 'FloatingPoint32BitIfPossible';
				end
				if ~exist('forceScreen','var') || isempty(forceScreen); forceScreen = -1; end
				if ~exist('showVBL','var') || isempty(showVBL); showVBL = false; end

				oldscreen = s.screen;
				oldbitdepth = s.bitDepth;
				oldwindowed = s.windowed;
				if forceScreen >= 0
					s.screen = forceScreen;
					if forceScreen == 0
						s.bitDepth = '8bit';
					end
				end
				prepareScreen(s);
				
				if benchmark
					s.windowed = false;
				elseif forceScreen > -1
					s.windowed = [0 0 s.screenVals.width/2 s.screenVals.height/2]; %half of screen
				end
				
				if ~s.isOpen
					sv=open(s); %open PTB screen
				else
					sv = s.screenVals;
				end
				setup(me,s); %setup our stimulus object
				
				Priority(MaxPriority(s.win)); %bump our priority to maximum allowed
				
				if ~strcmpi(me.type,'movie'); draw(me); resetTicks(me); end
				
				drawGrid(s); %draw +-5 degree dot grid
				drawScreenCenter(s); %centre spot
				
				if benchmark
					Screen('DrawText', s.win, 'BENCHMARK: screen won''t update properly, see FPS in command window at end.', 5,5,[0 0 0]);
				else
					Screen('DrawText', s.win, sprintf('Stim will be static for 2.0 seconds (debug grid is 1deg), then animate for %.2f seconds',runtime), 5,5,[0 0 0]);
				end
				
				flip(s);
				if benchmark
					WaitSecs('YieldSecs',0.5);
				else
					WaitSecs('YieldSecs',2);
				end
				if runtime < sv.ifi; runtime = sv.ifi; end
				nFrames = 0;
				notFinished = true;
				benchmarkFrames = floor(sv.fps * runtime);
				startT = GetSecs;
				vbl = zeros(benchmarkFrames+1,1);
				while notFinished
					nFrames = nFrames + 1;
					draw(me); %draw stimulus
					if s.visualDebug&&~benchmark; drawGrid(s); end
					finishDrawing(s); %tell PTB/GPU to draw
 					animate(me); %animate stimulus, will be seen on next draw
					if benchmark
						Screen('Flip',s.win,0,2,2);
						notFinished = nFrames < benchmarkFrames;
					else
						vbl(nFrames) = flip(s, vbl(end)); %flip the buffer
						% the calculation needs to take into account the
						% first and last frame times, so we subtract ifi*2
						notFinished = vbl(nFrames) < ( vbl(1) + ( runtime - (sv.ifi * 2) ) );
					end
				end
				endT = flip(s);
				if ~benchmark;startT = vbl(1);end
				diffT = endT - startT;
				WaitSecs(0.5);
				vbl = vbl(1:nFrames);
				if showVBL && ~benchmark
					figure;
					plot(diff(vbl)*1e3,'k*');
					line([0 length(vbl)-1],[sv.ifi*1e3 sv.ifi*1e3],'Color',[0 0 0]);
					title(sprintf('VBL Times, should be ~%.4f ms',sv.ifi*1e3));
					ylabel('Time (ms)')
					xlabel('Frame #')
				end
				Priority(0); ShowCursor; ListenChar(0);
				reset(me); %reset our stimulus ready for use again
				close(s); %close screen
				s.screen = oldscreen;
				s.windowed = oldwindowed;
				s.bitDepth = oldbitdepth;
				fps = nFrames / diffT;
				fprintf('\n\n======>>> Stimulus: %s\n',me.fullName);
				fprintf('======>>> <strong>SPEED</strong> (%i frames in %.3f secs) = <strong>%g</strong> fps\n\n',nFrames, diffT, fps);
				if ~benchmark;fprintf('\b======>>> First - Last frame time: %.3f\n\n',vbl(end)-startT);end
				clear s fps benchmark runtime b bb i vbl; %clear up a bit
				warning on
			catch ME
				warning on
				getReport(ME)
				Priority(0);
				if exist('s','var') && isa(s,'screenManager')
					close(s);
				end
				clear fps benchmark runtime b bb i; %clear up a bit
				reset(me); %reset our stimulus ready for use again
				rethrow(ME)				
			end
		end
		
		% ===================================================================
		%> @brief make a GUI properties panel for this object
		%>
		% ===================================================================
		function handles = makePanel(me, parent)
			if ~isempty(me.handles) && isfield(me.handles, 'root') && isa(me.handles.root,'matlab.ui.container.Panel')
				fprintf('---> Panel already open for %s\n', me.fullName);
				return
			end
			
			handles = [];
			
			if ~exist('parent','var')
				parent = uifigure('Tag','gFig',...
					'Name', [me.fullName 'Properties'], ...
					'Position', [ 10 10 800 500 ],...
					'MenuBar', 'none', ...
					'CloseRequestFcn', @me.closePanel, ...
					'NumberTitle', 'off');
				me.handles(1).parent = parent;
				handles(1).parent = parent;
			end
			
			bgcolor = [0.95 0.95 0.95];
			bgcoloredit = [1 1 1];
			fsmall = 10;
			fmed = 11;
			if ismac
				SansFont = 'Avenir next';
				MonoFont = 'Menlo';
			elseif ispc
				SansFont = 'Calibri';
				MonoFont = 'Consolas';
			else %linux
				SansFont = 'Liberation Sans'; %get(0,'defaultAxesFontName');
				MonoFont = 'Fira Code';
			end
			
			handles.root = uipanel('Parent',parent,...
				'Units','normalized',...
				'Position',[0 0 1 1],...
				'Title',me.fullName,...
				'TitlePosition','centertop',...
				'FontName',SansFont,...
				'FontSize',fmed,...
				'FontAngle','italic',...
				'BackgroundColor',[0.94 0.94 0.94]);
			handles.grid = uigridlayout(handles.root,[1 3]);
			handles.grid1 = uigridlayout(handles.grid,'Padding',[5 5 5 5],'BackgroundColor',bgcolor);
			handles.grid2 = uigridlayout(handles.grid,'Padding',[5 5 5 5],'BackgroundColor',bgcolor);
			handles.grid.ColumnWidth = {'1x','1x',130};
			handles.grid1.ColumnWidth = {'2x','1x'};
			handles.grid2.ColumnWidth = {'2x','1x'};
			
			idx = {'handles.grid1','handles.grid2','handles.grid3'};
			
			disableList = 'fullName';
			
			pr = findAttributesandType(me,'SetAccess','public','notlogical');
			pr = sort(pr);
			lp = ceil(length(pr)/2);
			
			pr2 = findAttributesandType(me,'SetAccess','public','logical');
			pr2 = sort(pr2);
			lp2 = length(pr2);
			handles.grid3 = uigridlayout(handles.grid,[lp2 1],'Padding',[1 1 1 1],'BackgroundColor',bgcolor);

			for i = 1:2
				for j = 1:lp
					cur = lp*(i-1)+j;
					if cur <= length(pr)
						val = me.(pr{cur});
						if ischar(val)
							if isprop(me,[pr{cur} 'List'])
								if strcmp(me.([pr{cur} 'List']),'filerequestor')
									val = regexprep(val,'\s+','  ');
									handles.([pr{cur} '_char']) = uieditfield(...
										'Parent',eval(idx{i}),...
										'Tag',[pr{cur} '_char'],...
										'HorizontalAlignment','center',...
										'ValueChangedFcn',@me.readPanel,...
										'Value',val,...
										'FontName',MonoFont,...
										'BackgroundColor',bgcoloredit);
									if ~isempty(regexpi(pr{cur},disableList,'once')) 
										handles.([pr{cur} '_char']).Enable = false; 
									end
								else
									txt=me.([pr{cur} 'List']);
									if contains(val,txt)
										handles.([pr{cur} '_list']) = uidropdown(...
										'Parent',eval(idx{i}),...
										'Tag',[pr{cur} '_list'],...
										'Items',txt,...
										'ValueChangedFcn',@me.readPanel,...
										'Value',val,...
										'BackgroundColor',bgcolor);
										if ~isempty(regexpi(pr{cur},disableList,'once')) 
											handles.([pr{cur} '_list']).Enable = false; 
										end
									else
										handles.([pr{cur} '_list']) = uidropdown(...
										'Parent',eval(idx{i}),...
										'Tag',[pr{cur} '_list'],...
										'Items',txt,...
										'ValueChangedFcn',@me.readPanel,...
										'BackgroundColor',bgcolor);
									end
								end
							else
								val = regexprep(val,'\s+','  ');
								handles.([pr{cur} '_char']) = uieditfield(...
									'Parent',eval(idx{i}),...
									'Tag',[pr{cur} '_char'],...
									'HorizontalAlignment','center',...
									'ValueChangedFcn',@me.readPanel,...
									'Value',val,...
									'BackgroundColor',bgcoloredit);
								if ~isempty(regexpi(pr{cur},disableList,'once')) 
									handles.([pr{cur} '_char']).Enable = false; 
								end
							end
						elseif isnumeric(val)
							val = num2str(val);
							val = regexprep(val,'\s+','  ');
							handles.([pr{cur} '_num']) = uieditfield('text',...
								'Parent',eval(idx{i}),...
								'Tag',[pr{cur} '_num'],...
								'HorizontalAlignment','center',...
								'Value',val,...
								'ValueChangedFcn',@me.readPanel,...
								'FontName',MonoFont,...
								'BackgroundColor',bgcoloredit);
							if ~isempty(regexpi(pr{cur},disableList,'once')) 
								handles.([pr{cur} '_num']).Enable = false; 
							end
						else
							uitextarea('Parent',eval(idx{i}),'BackgroundColor',bgcolor);
						end
						if isprop(me,[pr{cur} 'List'])
							if strcmp(me.([pr{cur} 'List']),'filerequestor')
								uibutton(...
								'Parent',eval(idx{i}),...
								'HorizontalAlignment','left',...
								'Text','Select file...',...
								'FontName',SansFont,...
								'Tag',[pr{cur} '_button'],...
								'FontSize', fsmall);
							else
								uilabel(...
								'Parent',eval(idx{i}),...
								'HorizontalAlignment','left',...
								'Text',pr{cur},...
								'FontName',SansFont,...
								'FontSize', fsmall,...
								'BackgroundColor',bgcolor);
							end
						else
							uilabel(...
							'Parent',eval(idx{i}),...
							'HorizontalAlignment','left',...
							'Text',pr{cur},...
							'FontName',SansFont,...
							'FontSize', fsmall,...
							'BackgroundColor',bgcolor);
						end
					else
						uitextarea('Parent',eval(idx{i}),'BackgroundColor',bgcolor);
					end
				end
			end
			for j = 1:lp2
				val = me.(pr2{j});
				if j <= length(pr2)
					handles.([pr2{j} '_bool']) = uicheckbox(...
						'Parent',eval(idx{end}),...
						'Tag',[pr2{j} '_bool'],...
						'Text',pr2{j},...
						'FontName',SansFont,...
						'FontSize', fsmall,...
						'ValueChangedFcn',@me.readPanel,...
						'Value',val);
				end
			end
			handles.readButton = uibutton(...
				'Parent',eval(idx{end}),...
				'Tag','readButton',...%'Callback',@me.readPanel,...
				'Text','Update');
			me.handles = handles;
		end
		
		% ===================================================================
		%> @brief read values from a GUI properties panel for this object
		%>
		% ===================================================================
		function selectFilePanel(me,varargin)
			if nargin > 0
				hin = varargin{1};
				if ishandle(hin)
					[f,p] = uigetfile('*.*','Select File:');
					re = regexp(get(hin,'Tag'),'(.+)_button','tokens','once');
					hout = me.handles.([re{1} '_char']);
					if ishandle(hout)
						set(hout,'String', [p f]);
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief read values from a GUI properties panel for this object
		%>
		% ===================================================================
		function readPanel(me,varargin)

			if isempty(me.handles) || ~(isfield(me.handles, 'root') && isa(me.handles.root,'matlab.ui.container.Panel'))
				return
			end
			if isempty(varargin) || isempty(varargin{1}); return; end
			source = varargin{1};
			tag = source.Tag;
			if isempty(tag); return; end
			tagName = regexprep(tag,'_.+$','');
			tagType = regexprep(tag,'^.+_','');
			
			pList = findAttributes(me,'SetAccess','public'); %our public properties
			
			if ~any(contains(pList,tagName)); return; end
			
			switch tagType
				case 'list'
					me.(tagName) = source.Value;
				case 'bool'	
					me.(tagName) = logical(source.Value);
				case 'num'
					me.(tagName) = str2num(source.Value);
				case 'char'
					me.(tagName) = source.Value;
				otherwise
					warning('Can''t set property');
			end
			
			if strcmpi(tagName,'name')
				me.handles.fullName_char.Value = me.fullName;
				me.handles.root.Title = me.fullName;
			end
			
			if strcmpi(tagName,'alpha')
				me.handles.colour_num.Value = num2str(me.colour, '%g ');
			end
			
			if strcmpi(tagName,'colour')
				me.handles.alpha_num.Value = num2str(me.alpha, '%g ');
			end
			
			notify(me,'readPanelUpdate');
		end
			
		% ===================================================================
		%> @brief show GUI properties panel for this object
		%>
		% ===================================================================
		function showPanel(me)
			if isempty(me.handles)
				return
			end
			set(me.handles.root,'Enable','on');
			set(me.handles.root,'Visible','on');
		end
		
		% ===================================================================
		%> @brief hide GUI properties panel for this object
		%>
		% ===================================================================
		function hidePanel(me)
			if isempty(me.handles)
				return
			end
			set(me.handles.root,'Enable','off');
			set(me.handles.root,'Visible','off');
		end
		
		% ===================================================================
		%> @brief close GUI panel for this object
		%>
		% ===================================================================
		function closePanel(me,varargin)
			if isfield(me.handles,'root') && isgraphics(me.handles.root)
				delete(me.handles.root);
			end
			if isfield(me.handles,'parent') && isgraphics(me.handles.parent,'figure')
				delete(me.handles.parent)
			end
			me.handles = [];
		end
		
		% ===================================================================
		%> @brief checkPaths
		%>
		%> @param
		%> @return
		% ===================================================================
		function cleanHandles(me,varargin)
			if isprop(me,'handles')
				me.handles = [];
			end
			if isprop(me,'h')
				me.handles = [];
			end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Static ) %----------STATIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief degrees2radians
		%>
		% ===================================================================
		function r = d2r(degrees)
		% d2r(degrees)
			r=degrees*(pi/180);
		end
		
		% ===================================================================
		%> @brief radians2degrees
		%>
		% ===================================================================
		function degrees = r2d(r)
		% r2d(radians)
			degrees=r*(180/pi);
		end
		
		% ===================================================================
		%> @brief findDistance in X and Y coordinates
		%>
		% ===================================================================
		function distance = findDistance(x1, y1, x2, y2)
		% findDistance(x1, y1, x2, y2)
			dx = x2 - x1;
			dy = y2 - y1;
			distance=sqrt(dx^2 + dy^2);
		end
		
		% ===================================================================
		%> @brief updatePosition returns dX and dY given an angle and delta
		%>
		% ===================================================================
		function [dX, dY] = updatePosition(delta,angle)
		% updatePosition(delta, angle)
			dX = delta .* cos(baseStimulus.d2r(angle));
			dY = delta .* sin(baseStimulus.d2r(angle));
		end
		
	end%---END STATIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief doProperties
		%> these are transient properties that specify actions during runtime
		% ===================================================================
		function doProperties(me)
			if isempty(me.findprop('doFlash'));p=me.addprop('doFlash');p.Transient = true;end
			if isempty(me.findprop('doDots'));p=me.addprop('doDots');p.Transient = true;end
			if isempty(me.findprop('doMotion'));p=me.addprop('doMotion');p.Transient = true;end
			if isempty(me.findprop('doDrift'));p=me.addprop('doDrift');p.Transient = true;end
			if isempty(me.findprop('doAnimator'));p=me.addprop('doAnimator');p.Transient = true;end
			
			me.doDots		= false;
			me.doMotion		= false;
			me.doDrift		= false;
			me.doFlash		= false;
			me.doAnimator	= false;
			
			if ~isempty(me.findprop('tf')) && me.tf > 0; me.doDrift = true; end
			if me.speed > 0; me.doMotion = true; end
			if strcmpi(me.family,'dots'); me.doDots = true; end
			if strcmpi(me.type,'flash'); me.doFlash = true; end
			if ~isempty(me.animator) && isa(me.animator,'animationManager')
				me.doAnimator = true; 
			end
		end
			
		% ===================================================================
		%> @brief setRect
		%> setRect makes the PsychRect based on the texture and screen
		%> values, you should call computePosition() first to get xOut and
		%> yOut
		% ===================================================================
		function setRect(me)
			if ~isempty(me.texture)
				me.dstRect=Screen('Rect',me.texture);
				if me.mouseOverride && me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
				else
					me.dstRect=CenterRectOnPointd(me.dstRect, me.xOut, me.yOut);
				end
				me.mvRect=me.dstRect;
			end
		end
		
		% ===================================================================
		%> @brief setAnimationDelta
		%> setAnimationDelta for performance better not to use get methods for dX dY and
		%> delta during animation, so we have to cache these properties to private copies so that
		%> when we call the animate method, it uses the cached versions not the
		%> public versions. This method simply copies the properties to their cached
		%> equivalents.
		% ===================================================================
		function setAnimationDelta(me)
			me.delta_ = me.delta;
			me.dX_ = me.dX;
			me.dY_ = me.dY;
		end
		
		% ===================================================================
		%> @brief compute xOut and yOut
		%>
		% ===================================================================
		function computePosition(me)
			if me.mouseOverride && me.mouseValid
				me.xOut = me.mouseX; me.yOut = me.mouseY;
			else
				if isempty(me.findprop('angleOut'))
					[dx, dy]=pol2cart(me.d2r(me.angle),me.startPosition);
				else
					[dx, dy]=pol2cart(me.d2r(me.angleOut),me.startPositionOut);
				end
				me.xOut = me.xPositionOut + (dx * me.ppd) + me.sM.xCenter;
				me.yOut = me.yPositionOut + (dy * me.ppd) + me.sM.yCenter;
				if me.verbose; fprintf('---> computePosition: %s X = %gpx / %gpx / %gdeg | Y = %gpx / %gpx / %gdeg\n',me.fullName, me.xOut, me.xPositionOut, dx, me.yOut, me.yPositionOut, dy); end
			end
			setAnimationDelta(me);
		end
		
		% ===================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function set_xPositionOut(me,value)
			me.xPositionOut = value*me.ppd;
			if ~me.inSetup; me.setRect; end
		end
		
		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function set_yPositionOut(me,value)
			me.yPositionOut = value*me.ppd;
			if ~me.inSetup; me.setRect; end
		end
		
		% ===================================================================
		%> @brief Converts properties to a structure
		%>
		%>
		%> @param me this instance object
		%> @param tmp is whether to use the temporary or permanent properties
		%> @return out the structure
		% ===================================================================
		function out=toStructure(me,tmp)
			if ~exist('tmp','var')
				tmp = 0; %copy real properties, not temporary ones
			end
			fn = fieldnames(me);
			for j=1:length(fn)
				if tmp == 0
					out.(fn{j}) = me.(fn{j});
				else
					out.(fn{j}) = me.([fn{j} 'Out']);
				end
			end
		end
		
		% ===================================================================
		%> @brief Finds and removes transient properties
		%>
		%> @param me
		%> @return
		% ===================================================================
		function removeTmpProperties(me)
			fn=fieldnames(me);
			for i=1:length(fn)
				if isempty(regexp(fn{i},'^xOut$|^yOut$','once')) && ~isempty(regexp(fn{i},'Out$','once'))
					delete(me.findprop(fn{i}));
				end
			end
		end
		
		% ===================================================================
		%> @brief Delete method
		%>
		%> @param me
		%> @return
		% ===================================================================
		function delete(me)
			me.handles = [];
			if ~isempty(me.texture)
				for i = 1:length(me.texture)
					if Screen(me.texture, 'WindowKind')~=0 ;try Screen('Close',me.texture); end; end %#ok<*TRYNC>
				end
			end
			if isprop(me,'buffertex') && ~isempty(me.buffertex)
				if Screen(me.buffertex, 'WindowKind')~=0 ; try Screen('Close',me.buffertex); end; end
			end
			if me.verbose; fprintf('--->>> Delete: %s\n',me.fullName); end
		end
		
	end%---END PRIVATE METHODS---%
end
