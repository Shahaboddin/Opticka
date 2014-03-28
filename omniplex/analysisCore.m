% ========================================================================
%> @brief analysisCore base class inherited by other analysis classes.
%> analysidCore is itself derived from optickaCore.
% ========================================================================
classdef analysisCore < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		doPlots@logical = true
		stats@struct
	end
	
	%--------------------ABSTRACT PROPERTIES----------%
	properties (Abstract = true)
		
	end
	
	%--------------------HIDDEN PROPERTIES------------%
	properties (SetAccess = protected, Hidden = true)
		
	end
	
	%--------------------VISIBLE PROPERTIES-----------%
	properties (SetAccess = protected, GetAccess = public)
		
	end
	
	%--------------------DEPENDENT PROPERTIES----------%
	properties (SetAccess = private, Dependent = true)
		
	end
	
	%------------------TRANSIENT PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected, Transient = true)
		%> UI panels
		panels@struct = struct()
		%> do we yoke the selection to the parent function (e.g. LFPAnalysis)
		yokedSelection@logical = false
	end
	
	%--------------------PROTECTED PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected)
		
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'doPlots'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
		%=======================================================================
		
		% ==================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ==================================================================
		function ego = analysisCore(varargin)
			if nargin == 0; varargin.name = ''; end
			ego=ego@optickaCore(varargin); %superclass constructor
			if nargin>0; ego.parseArgs(varargin, ego.allowedProperties); end
			setStats(ego);
		end
		
		% ===================================================================
			%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function showEyePlots(ego)
			if ~isprop(ego,'p') || ~isa(ego.p,'plxReader') || isempty(ego.p.eA) || ~isa(ego.p.eA,'eyelinkAnalysis')
				return
			end
			if isprop(ego,'nSelection')
				if ~isempty(ego.selectedTrials)
					for i = 1:length(ego.selectedTrials)
						disp(['---> Plotting eye position for: ' ego.selectedTrials{i}.name]);
						ego.p.eA.plot(ego.selectedTrials{i}.idx,[],[],ego.selectedTrials{i}.name);
					end
				end
			else
				ego.p.eA.plot();
			end
		end
		
		% ===================================================================
		%> @brief showInfo shows the info box for the plexon parsed data
		%>
		%> @param
		%> @return
		% ===================================================================
		function showInfo(ego)
			if ~isprop(ego,'p') || ~isa(ego.p,'plxReader')
				return
			end
			if ~isempty(ego.p.info)
				infoBox(ego.p);
			end
		end
		
		% ===================================================================
		%> @brief showInfo shows the info box for the plexon parsed data
		%>
		%> @param
		%> @return
		% ===================================================================
		function stats = setStats(ego)
			initialiseStats(ego);
			s=ego.stats;
			
			mlist1={'analytic', 'montecarlo', 'stats'};
			mt = 'p';
			for i = 1:length(mlist1)
				if strcmpi(mlist1{i},ego.stats.method)
					mt = [mt '|�' mlist1{i}];
				else
					mt = [mt '|' mlist1{i}];
				end
			end
			
			mlist2={'indepsamplesT','indepsamplesF','indepsamplesregrT','indepsamplesZcoh','depsamplesT','depsamplesFmultivariate','depsamplesregrT','actvsblT','ttest','ttest2','anova1','kruskalwallis'};
			statistic = 'p';
			for i = 1:length(mlist2)
				if strcmpi(mlist2{i},ego.stats.statistic)
					statistic = [statistic '|�' mlist2{i}];
				else
					statistic = [statistic '|' mlist2{i}];
				end
			end
			
			mlist3={'no','bonferroni','holm','fdr','hochberg'};
			mc = 'p';
			for i = 1:length(mlist3)
				if strcmpi(mlist3{i},ego.stats.correctm)
					mc = [mc '|�' mlist3{i}];
				else
					mc = [mc '|' mlist3{i}];
				end
			end
			
			mlist4={'permutation','bootstrap'};
			rs = 'p';
			for i = 1:length(mlist4)
				if strcmpi(mlist4{i},ego.stats.resampling)
					rs = [rs '|�' mlist4{i}];
				else
					rs = [rs '|' mlist4{i}];
				end
			end
			
			mlist5={'-1','0','1'};
			tail = 'p';
			for i = 1:length(mlist5)
				if strcmpi(mlist5{i},num2str(ego.stats.tail))
					tail = [tail '|�' mlist5{i}];
				else
					tail = [tail '|' mlist5{i}];
				end
			end
			
			if isprop(ego,'measureRange')
				mr = ego.measureRange;
			else mr = [-inf inf]; end
			
			if isprop(ego,'baselineWindow')
				bw = ego.baselineWindow;
			else bw = [-inf inf]; end
			
			mtitle   = ['Select Statistics Settings'];
			options  = {['t|' num2str(s.alpha)],'Set the Statistical Alpha Value (alpha):';   ...
				[mt],'Main Statistical Method (method):';...
				[statistic],'Statistical Type (statistic):';...
				[mc],'Multiple Correction Methodology (correctm):';...
				[rs],'Resampling Method (resampling):';...
				[tail],'Tail [0 is a two-tailed test] (tail):';...
				['t|' num2str(s.nrand)],'Set # Resamples for Monte Carlo Method (nrand):';   ...
				['t|' num2str(mr)],'Measurement Range (measureRange):';   ...
				['t|' num2str(bw)],'Baseline Window (baselineWindow):';   ...
				};
			            
			answer = menuN(mtitle,options);
			drawnow;
			if iscell(answer) && ~isempty(answer)
				ego.stats.alpha = str2num(answer{1});
				ego.stats.method = mlist1{answer{2}};
				ego.stats.statistic = mlist2{answer{3}};
				ego.stats.correctm = mlist3{answer{4}};
				ego.stats.resampling = mlist4{answer{5}};
				ego.stats.tail = str2num(mlist5{answer{6}});
				ego.stats.nrand = str2num(answer{7});
				if isprop(ego,'measureRange'); ego.measureRange = str2num(answer{8}); end
				if isprop(ego,'baselineWindow'); ego.baselineWindow = str2num(answer{9}); end
			end
			
			stats = ego.stats;
			
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Static = true) %-------STATIC METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief selectFTTrials cut out trials where the ft function fails
		%> to use cfg.trials
		%>
		%> @param
		%> @return
		% ===================================================================
		function ftout=subselectFieldTripTrials(ft,idx)
			ftout = ft;
			if isfield(ft,'nUnits') %assume a spike structure
				ftout.trialtime = ft.trialtime(idx,:);
				ftout.cfg.trl = ft.cfg.trl(idx,:);
				for j = 1:ft.nUnits
					sel					= ismember(ft.trial{j},idx);
					ftout.timestamp{j}	= ft.timestamp{j}(sel);
					ftout.time{j}		= ft.time{j}(sel);
					ftout.trial{j}		= ft.trial{j}(sel);
				end
			else %assume continuous
				ftout.sampleinfo = ft.sampleinfo(idx,:);
				ftout.trialinfo = ft.trialinfo(idx,:);
				if isfield(ft.cfg,'trl'); ftout.cfg.trl = ft.cfg.trl(idx,:); end
				ftout.time = ft.time(idx);
				ftout.trial = ft.trial(idx);
			end
			
		end
		
		% ==================================================================
		%> @brief find nearest value in a vector
		%>
		%> @param in input vector
		%> @param value value to find
		%> @return idx index position of nearest value
		%> @return val value of nearest value
		%> @return delta the difference between val and value
		% ==================================================================
		function [idx,val,delta]=findNearest(in,value)
			tmp = abs(in-value);
			[~,idx] = min(tmp);
			val = in(idx);
			delta = abs(value - val);
		end
		
		% ===================================================================
		%> @brief a wrapper to make plotyy more friendly to errorbars
		%>
		%> @param
		% ===================================================================
		function [h]=plotYY(x,y)
			[m,e] = stderr(y);
			if size(m) == size(x)
				h=areabar(x,m,e);
			end
		end
		
		% ===================================================================
		%> @brief variance to standard eror
		%>
		%> @param
		% ===================================================================
		function [err]=var2SE(var,dof)
			err = sqrt(var ./ dof);
		end
		
		% ===================================================================
		%> @brief preferred row col layout for multiple plots
		%> @param
		% ===================================================================
		function [row,col]=optimalLayout(len)
			row=1; col=1;
			if		len == 2,		row = 2;	col = 1;
			elseif	len == 3,	row = 3;	col = 1;
			elseif	len == 4,	row = 2;	col = 2;
			elseif	len < 7,		row = 3;	col = 2;
			elseif	len < 9,		row = 4;	col = 2;
			elseif	len < 10,	row = 3;	col = 3;
			elseif	len < 13,	row = 4;	col = 3;
			elseif	len < 17,	row = 4;	col = 4;
			elseif	len < 21,	row = 5;	col = 4;
			elseif	len < 26,	row = 5;	col = 5;
			elseif	len < 31,	row = 6;	col = 5;
			elseif	len < 37,	row = 6;	col = 6;
			else						row = ceil(len/10); col = 10;
			end
		end
		
		% ===================================================================
		%> @brief make optimally different colours for plots
		%>
		%> @param
		% ===================================================================
		function colors = optimalColours(n_colors,bg,func)
			% Copyright 2010-2011 by Timothy E. Holy
			
			% Parse the inputs
			if (nargin < 2)
				bg = [1 1 1];  % default white background
			else
				if iscell(bg)
					% User specified a list of colors as a cell aray
					bgc = bg;
					for i = 1:length(bgc)
						bgc{i} = parsecolor(bgc{i});
					end
					bg = cat(1,bgc{:});
				else
					% User specified a numeric array of colors (n-by-3)
					bg = parsecolor(bg);
				end
			end
			
			% Generate a sizable number of RGB triples. This represents our space of
			% possible choices. By starting in RGB space, we ensure that all of the
			% colors can be generated by the monitor.
			n_grid = 30;  % number of grid divisions along each axis in RGB space
			x = linspace(0,1,n_grid);
			[R,G,B] = ndgrid(x,x,x);
			rgb = [R(:) G(:) B(:)];
			if (n_colors > size(rgb,1)/3)
				error('You can''t readily distinguish that many colors');
			end
			
			% Convert to Lab color space, which more closely represents human
			% perception
			if (nargin > 2)
				lab = func(rgb);
				bglab = func(bg);
			else
				C = makecform('srgb2lab');
				lab = applycform(rgb,C);
				bglab = applycform(bg,C);
			end
			
			% If the user specified multiple background colors, compute distances
			% from the candidate colors to the background colors
			mindist2 = inf(size(rgb,1),1);
			for i = 1:size(bglab,1)-1
				dX = bsxfun(@minus,lab,bglab(i,:)); % displacement all colors from bg
				dist2 = sum(dX.^2,2);  % square distance
				mindist2 = min(dist2,mindist2);  % dist2 to closest previously-chosen color
			end
			
			% Iteratively pick the color that maximizes the distance to the nearest
			% already-picked color
			colors = zeros(n_colors,3);
			lastlab = bglab(end,:);   % initialize by making the "previous" color equal to background
			for i = 1:n_colors
				dX = bsxfun(@minus,lab,lastlab); % displacement of last from all colors on list
				dist2 = sum(dX.^2,2);  % square distance
				mindist2 = min(dist2,mindist2);  % dist2 to closest previously-chosen color
				[~,index] = max(mindist2);  % find the entry farthest from all previously-chosen colors
				colors(i,:) = rgb(index,:);  % save for output
				lastlab = lab(index,:);  % prepare for next iteration
			end
		
			function c = parsecolor(s)
				if ischar(s)
					c = colorstr2rgb(s);
				elseif isnumeric(s) && size(s,2) == 3
					c = s;
				else
					error('MATLAB:InvalidColorSpec','Color specification cannot be parsed.');
				end
			end

			function c = colorstr2rgb(c)
				% Convert a color string to an RGB value.
				% This is cribbed from Matlab's whitebg function.
				% Why don't they make this a stand-alone function?
				rgbspec = [1 0 0;0 1 0;0 0 1;1 1 1;0 1 1;1 0 1;1 1 0;0 0 0];
				cspec = 'rgbwcmyk';
				k = find(cspec==c(1));
				if isempty(k)
					error('MATLAB:InvalidColorString','Unknown color string.');
				end
				if k~=3 || length(c)==1,
					c = rgbspec(k,:);
				elseif length(c)>2,
					if strcmpi(c(1:3),'bla')
						c = [0 0 0];
					elseif strcmpi(c(1:3),'blu')
						c = [0 0 1];
					else
						error('MATLAB:UnknownColorString', 'Unknown color string.');
					end
				end
			end
		
		end
		
	end %---END STATIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
		% ===================================================================
		%> @brief Allows two analysis objects to share a single plxReader object
		%>
		%> @param
		% ===================================================================
		function inheritPlxReader(ego,p)
			if exist('p','var') && isa(p,'plxReader')
				if isprop(ego,'p')
					ego.p = p;
				end
			end
		end
		
		% ===================================================================
		%> @brief set trials / var parsing from outside, override dialog, used when 
		%> yoked to another analysis object
		%> 
		%> @param in structure
		%> @return
		% ===================================================================
		function setSelection(ego, in)
			if isfield(in,'yokedSelection') && isprop(ego,'yokedSelection')
				ego.yokedSelection = in.yokedSelection;
			else
				ego.yokedSelection = false;
			end
			if isfield(in,'cutTrials') && isprop(ego,'cutTrials')
				ego.cutTrials = in.cutTrials;
			end
			if isfield(in,'selectedTrials') && isprop(ego,'selectedTrials')
				ego.selectedTrials = in.selectedTrials;
				ego.yokedSelection = true;
			end
			if isfield(in,'map') && isprop(ego,'map')
				ego.map = in.map;
			end
			if isfield(in,'plotRange') && isprop(ego,'plotRange')
				ego.plotRange = in.plotRange;
			end
			if isfield(in,'selectedBehaviour') && isprop(ego,'selectedBehaviour')
				ego.selectedBehaviour = in.selectedBehaviour;
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		%> @return
		% ===================================================================
		function initialiseStats(ego)
			if ~isfield(ego.stats,'alpha') || isempty(ego.stats.alpha)
				ego.stats(1).alpha = 0.01;
			end
			if ~isfield(ego.stats,'method') || isempty(ego.stats.method)
				ego.stats(1).method = 'analytic';
			end
			if ~isfield(ego.stats,'statistic') || isempty(ego.stats.statistic)
				ego.stats(1).statistic = 'indepsamplesT';
			end
			if ~isfield(ego.stats,'correctm') || isempty(ego.stats.correctm)
				ego.stats(1).correctm = 'no';
			end
			if ~isfield(ego.stats,'nrand') || isempty(ego.stats.nrand)
				ego.stats(1).nrand = 1000;
			end
			if ~isfield(ego.stats,'tail') || isempty(ego.stats.tail)
				ego.stats(1).tail = 0;
			end
			if ~isfield(ego.stats,'parameter') || isempty(ego.stats.parameter)
				ego.stats(1).parameter = 'trial';
			end
			if ~isfield(ego.stats,'resampling') || isempty(ego.stats.resampling)
				ego.stats(1).resampling = 'permutation';
			end
		end
	end %---END PROTECTED METHODS---%
	
end %---END CLASSDEF---%