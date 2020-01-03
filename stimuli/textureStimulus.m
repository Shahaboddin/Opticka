% ========================================================================
%> @brief textureStimulus is the superclass for texture based stimulus objects
%>
%> Superclass providing basic structure for texture stimulus classes
%>
% ========================================================================	
classdef textureStimulus < baseStimulus	
	properties %--------------------PUBLIC PROPERTIES----------%
		type char = 'picture'
		%> filename to load
		fileName char = ''
		%> if N > 0, then this is a number of images from 1:N, e.g.
		%> fileName = base.jpg, multipleImages=5, then base1.jpg - base5.jpg
		%> update() will randomly select one from this group.
		multipleImages double = 0
		%> contrast multiplier
		contrast double = 1
		%>
		interpMethod char = 'nearest'
		%>scale up the texture in the bar
		pixelScale double = 1 
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> scale is set by size
		scale = 1
		%>
		family = 'texture'
		%>
		matrix
		%> current randomly selected image
		currentImage = ''
		width
		height
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList = {'picture'}
		fileNameList = 'filerequestor';
		interpMethodList = {'nearest','linear','spline','cubic'}
		%> list of imagenames if multipleImages > 0
		fileNames = {};
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties='type|fileName|multipleImages|contrast|scale|interpMethod|pixelScale';
		%>properties to not create transient copies of during setup phase
		ignoreProperties = 'scale|fileName|interpMethod|pixelScale'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
	
		% ===================================================================
		%> @brief Class constructor
		%>
		%> This parses any input values and initialises the object.
		%>
		%> @param varargin are passed as a list of parametoer or a structure 
		%> of properties which is parsed.
		%>
		%> @return instance of opticka class.
		% ===================================================================
		function me = textureStimulus(varargin)
			if nargin == 0;varargin.family = 'texture';end
			me=me@baseStimulus(varargin); %we call the superclass constructor first
			me.size = 0; %override default
			if nargin>0
				me.parseArgs(varargin, me.allowedProperties);
			end
			
			checkFileName(me);
			
			me.ignoreProperties = ['^(' me.ignorePropertiesBase '|' me.ignoreProperties ')$'];
			me.salutation('constructor','Texture Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup this object in preperation for use
		%> When displaying a stimulus object, the main properties that are to be
		%> modified are copied into cache copies of the property, both to convert from 
		%> visual description (c/d, Hz, degrees) to
		%> computer metrics; and to be animated and modified as independant
		%> variables. So xPosition is copied to xPositionOut and converted from
		%> degrees to pixels. The animation and drawing functions use these modified
		%> properties, and when they are updated, for example to change to a new
		%> xPosition, internal methods ensure reconversion and update any dependent
		%> properties. This method initialises the object in preperation for display.
		%>
		%> @param sM screenManager object for reference
		%> @param in matrix for conversion to a PTB texture
		% ===================================================================
		function setup(me,sM,in)
			
			reset(me);
			me.inSetup = true;
			
			checkFileName(me);
			
			if isempty(me.isVisible)
				me.show;
			end
			
			if ~exist('in','var')
				in = [];
			end
			
			if isempty(me.isVisible)
				me.show;
			end
			
			me.sM = sM;
			me.ppd=sM.ppd;
			
			me.texture = []; %we need to reset this

			fn = fieldnames(textureStimulus);
			for j=1:length(fn)
				if isempty(me.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},me.ignoreProperties, 'once')) %create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
				end
				if isempty(regexp(fn{j},me.ignoreProperties, 'once'))
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if me.multipleImages > 0 && ~isempty(me.fileName)
				[p,f,e]=fileparts(me.fileName);
				for i = 1:me.multipleImages
					me.fileNames{i} = [p filesep f num2str(i) e];
				end
			end
			
			loadImage(me, in);
			
			if isempty(me.findprop('doDots'));p=me.addprop('doDots');p.Transient = true;end
			if isempty(me.findprop('doMotion'));p=me.addprop('doMotion');p.Transient = true;end
			if isempty(me.findprop('doDrift'));p=me.addprop('doDrift');p.Transient = true;end
			if isempty(me.findprop('doFlash'));p=me.addprop('doFlash');p.Transient = true;end
			me.doDots = false;
			me.doMotion = false;
			me.doDrift = false;
			me.doFlash = false;
			
			if me.speed>0 %we need to say this needs animating
				me.doMotion=true;
 				%sM.task.stimIsMoving=[sM.task.stimIsMoving i];
			else
				me.doMotion=false;
			end
			
			if me.sizeOut > 0
				me.scale = me.sizeOut / (me.width / me.ppd);
			end
			
			me.inSetup = false;
			
			computePosition(me);
			setRect(me);
			
		end
		
		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function loadImage(me,in)
			ialpha = [];
			if ~exist('in','var'); in = []; end
			if ~isempty(in) && ischar(in)
				[me.matrix, ~, ialpha] = imread(in);
				me.currentImage = in;
			elseif ~isempty(in) && isnumeric(in)
				me.matrix = in;
				me.currentImage = '';
			elseif ~isempty(me.fileNames{1}) && exist(me.fileNames{1},'file')
				[me.matrix, ~, ialpha] = imread(me.fileNames{1});
				me.currentImage = me.fileNames{1};
			else
				me.matrix = uint8(ones(me.size*me.ppd,me.size*me.ppd,3)); %white texture
				me.currentImage = '';
			end
			
			me.width = size(me.matrix,2);
			me.height = size(me.matrix,1);
			
			me.salutation('loadImage',['Load: ' regexprep(me.currentImage,'\','/')],true);
			
			me.matrix = me.matrix .* me.contrast;
			
			if isempty(ialpha)
				me.matrix(:,:,4) = uint8(me.alpha .* 255);
			else
				me.matrix(:,:,4) = ialpha;
			end
			
			if isinteger(me.matrix(1))
				specialFlags = 4; %4 is optimization for uint8 textures. 0 is default
			else
				specialFlags = 0; %4 is optimization for uint8 textures. 0 is default
			end
			me.texture = Screen('MakeTexture', me.sM.win, me.matrix, 1, specialFlags);
		end

		% ===================================================================
		%> @brief Update this stimulus object structure for screenManager
		%>
		% ===================================================================
		function update(me)
			if me.multipleImages > 0
				if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
					try Screen('Close',me.texture); end %#ok<*TRYNC>
				end
				me.loadImage(me.fileNames{randi(me.multipleImages)});
			end
			me.scale = me.sizeOut;
			resetTicks(me);
			computePosition(me);
			setRect(me);
		end
		
		% ===================================================================
		%> @brief Draw this stimulus object
		%>
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				Screen('DrawTexture',me.sM.win,me.texture,[],me.mvRect,me.angleOut);
			end
			me.tick = me.tick + 1;
		end
		
		% ===================================================================
		%> @brief Animate an structure for screenManager
		%>
		% ===================================================================
		function animate(me)
			if me.isVisible && me.tick >= me.delayTicks
				if me.mouseOverride
					getMousePosition(me);
					if me.mouseValid
						me.mvRect = CenterRectOnPointd(me.mvRect, me.mouseX, me.mouseY);
					end
				end
				if me.doMotion == 1
					me.mvRect=OffsetRect(me.mvRect,me.dX_,me.dY_);
				end
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for screenManager
		%>
		% ===================================================================
		function reset(me)
			if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
				try Screen('Close',me.texture); end %#ok<*TRYNC>
			end
			resetTicks(me);
			me.texture=[];
			me.scale = 1;
			me.mvRect = [];
			me.dstRect = [];
			me.removeTmpProperties;
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief setRect
		%>  setRect makes the PsychRect based on the texture and screen values
		%>  This is overridden from parent class so we can scale texture
		%>  using the size value
		% ===================================================================
		function setRect(me)
			if ~isempty(me.texture)
				%setRect@baseStimulus(me) %call our superclass version first
				me.dstRect=Screen('Rect',me.texture);
				me.dstRect = ScaleRect(me.dstRect, me.scale, me.scale);
				if me.mouseOverride && me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
				else
					me.dstRect=CenterRectOnPointd(me.dstRect, me.xOut, me.yOut);
				end
				if me.verbose
					fprintf('---> stimulus TEXTURE dstRect = %5.5g %5.5g %5.5g %5.5g\n',me.dstRect(1), me.dstRect(2),me.dstRect(3),me.dstRect(4));
				end
				me.mvRect = me.dstRect;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function checkFileName(me)
			if isempty(me.fileName) || exist(me.fileName,'file') ~= 2 %use our default
				p = mfilename('fullpath');
				p = fileparts(p);
				me.fileName = [p filesep 'Bosch.jpeg'];
				me.fileNames{1} = me.fileName;
			elseif exist(me.fileName,'dir') == 7
				findFiles(me);
			end
		end
		
		
		
		% ===================================================================
		%> @brief findFiles
		%>  
		% ===================================================================
		function findFiles(me)	
			if exist(me.fileName,'dir') == 7
				d = dir(me.fileName);
				n = 0;
				for i = 1: length(d)
					if d(i).isdir;continue;end
					[~,f,e]=fileparts(d(i).name);
					if regexpi(e,'png|jpeg|jpg|bmp|tif')
						n = n + 1;
						me.fileNames{n} = [me.fileName filesep f e];
					end
				end
			end
		end
		
	end
	
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
	end
end