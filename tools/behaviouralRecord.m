% ========================================================================
%> @brief Create and update behavioural record.
%> 
% ========================================================================
classdef behaviouralRecord < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> verbosity
		verbose				= true
		response			= []
		rt1					= []
		rt2					= []
		date				= []
		info				= ''
		xAll				= []
		yAll				= [];
		correctStateName	= '^correct'
		breakStateName		= '^(breakfix|incorrect)'
		rewardTime			= 150;
		rewardVolume		= 3.6067e-04; %for 1ms
	end
	
	properties (GetAccess = public, SetAccess = protected)
		trials
	end
	
	properties (SetAccess = ?runExperiment, Transient = true)
		%> handles for the GUI
		h
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		tick
		startTime
		radius
		time
		inittime
		average
		averages
		%> allowed properties passed to object upon construction
		allowedProperties = 'verbose'
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
		%> @return instance of class.
		% ===================================================================
		function me = behaviouralRecord(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','Behavioural Record'));
			me=me@optickaCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function plot(me)
			createPlot(me);
			updatePlot(me);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function createPlot(me, eL)
			reset(me);
			me.date = datestr(now);
			if ~exist('eL','var')
				eL.fixation.radius = 1;
				eL.fixation.time = 1;
				eL.fixation.initTime = 1;
			end
			t = {['INFORMATION @ ' me.date]};
			t{end+1} = ['RUN = ' me.comment];
			t{end+1} = ['RADIUS = ' num2str(eL.fixation.radius)];
			t{end+1} = ' ';
			t{end+1} = ['TIME = ' num2str(eL.fixation.time)];
			t{end+1} = ' ';
			t{end+1} = ['INIT TIME = ' num2str(eL.fixation.initTime)];
			
			if ismac
				nfont = 'avenir next';
				mfont = 'menlo';
			elseif ispc
				nfont = 'calibri';
				mfont = 'consolas';
			else %linux
				nfont = 'Liberation Sans'; %get(0,'defaultAxesFontName');
				mfont = 'Fira Code';
			end
			me.h.root = figure('NumberTitle', 'off', 'Toolbar', 'none');
			me.h.panel = uiextras.BoxPanel('Parent',me.h.root, ...
				'Title',me.fullName, ...
				'FontSize',12, ...
				'TitleColor',[0.8 0.79 0.78], ...
				'BackgroundColor',[0.83 0.83 0.83]);
			me.h.vbox = uiextras.VBoxFlex( 'Parent', me.h.panel );
			me.h.hbox = uiextras.HBoxFlex('Parent', me.h.vbox);
			me.h.info = uicontrol('Style','edit', ...
				'Parent', me.h.vbox, ...
				'Tag','bRInfoText', ...
				'String', t, ...
				'BackgroundColor', [1 1 1], ...
				'HorizontalAlignment', 'center', ...
				'Max', 100, ...
				'FontSize', 10, ...
				'FontName',mfont);
			me.h.vbox2 = uiextras.VBox('Parent', me.h.hbox);
			me.h.axis1 = axes('Parent', me.h.vbox2,'Units','pixels');
			me.h.axis4 = axes('Parent', me.h.vbox2,'Units','pixels');
			me.h.vbox3 = uiextras.VBox('Parent', me.h.hbox);
			me.h.axis2 = axes('Parent', me.h.vbox3,'Units','pixels');
			me.h.axis3 = axes('Parent', me.h.vbox3,'Units','pixels');
			me.h.axis5 = axes('Parent', me.h.vbox3,'Units','pixels');
			axis([me.h.axis1 me.h.axis2 me.h.axis3 me.h.axis4], 'square');
			opticka.resizeFigure(0,[900 980]);
			set(me.h.vbox,'Sizes',[-5 -1])
			set(me.h.hbox,'Sizes',[-2 -1])
			set(me.h.vbox2,'Sizes',[-2 -1])
			set(me.h.vbox3,'Sizes',[-1 -1 -1])

			plot(me.h.axis1, 1, 0,'ko');
			hist(me.h.axis2, 0, 0:0.1:2);
			colormap('turbo')
			bar(me.h.axis3,rand(2,2),'stacked')
			set(me.h.axis3,'XTickLabel', {'all';'newest'})
			plot(me.h.axis4, 1, 0,'ko-');
			
			set([me.h.axis1 me.h.axis2 me.h.axis3 me.h.axis4], ...
				'Box','on','XGrid','on','YGrid','on','ZGrid','on');
			axis([me.h.axis2 me.h.axis3 me.h.axis4 me.h.axis5], 'tight');
			
			
			xlabel(me.h.axis1, 'Run Number')
			xlabel(me.h.axis2, 'Time')
			xlabel(me.h.axis3, 'Group')
			xlabel(me.h.axis4, '#')
			xlabel(me.h.axis5, 'X')
			ylabel(me.h.axis1, 'Yes / No')
			ylabel(me.h.axis2, 'Number #')
			ylabel(me.h.axis3, '% success')
			ylabel(me.h.axis4, '% success')
			ylabel(me.h.axis5, 'Y')
			title(me.h.axis1,'Success () / Fail ()')
			title(me.h.axis2,'Response Times')
			title(me.h.axis3,'Hit (blue) / Miss (red)')
			title(me.h.axis4,'Average (n=10) Hit / Miss %')
			title(me.h.axis5,'Last Eye Position')
			hn = findobj(me.h.axis2,'Type','patch');
			set(hn,'FaceColor','k','EdgeColor','k');
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function updatePlot(me, eT, sM, task)
			if me.tick == 1
				reset(me);
				me.startTime = clock;
			end
			if exist('sM','var')
				if ~isempty(regexpi(sM.currentName,me.correctStateName,'once'))
					me.response(me.tick) = 1;
					me.rt1(me.tick) = sM.log(end).stateTimeToNow * 1e3;
				elseif ~isempty(regexpi(sM.currentName,me.breakStateName,'once'))
					me.response(me.tick) = -1;
					me.rt1(me.tick) = 0;
				else
					me.response(me.tick) = 0;
					me.rt1(me.tick) = 0;
				end
			end
			if exist('eT','var')
				me.rt2(me.tick) = eT.fixInitLength * 1e3;
				me.radius(me.tick) = eT.fixation.radius;
				me.time(me.tick) = eT.fixation.time;
				me.inittime(me.tick) = eT.fixation.initTime;
				me.xAll = eT.xAll;
				me.yAll = eT.yAll;
			end
			
			hitn = length( me.response(me.response > 0) );
			breakn = length( me.response(me.response < 0) );
			totaln = length(me.response);
			missn = totaln - hitn;
			
			hitmiss = 100 * (hitn / totaln);
			breakmiss = 100 * (breakn / missn);
			if length(me.response) < 10
				average = 100 * (hitn / totaln);
			else
				lastn = me.response(end-9:end);				
				average = (length(lastn(lastn > 0)) / length(lastn)) * 100;
			end
			me.averages(me.tick) = average;
			hits = [hitmiss 100-hitmiss; average 100-average; breakmiss 100-breakmiss];
			
			%axis 1
			set(me.h.axis1,'NextPlot','replacechildren')
			plot(me.h.axis1, 1:length(me.response), me.response,'k.-','MarkerSize',12);
			set(me.h.axis1,'NextPlot','add')
			if ~isempty(me.radius)
				plot(me.h.axis1, 1:length(me.response), me.radius,'r.','MarkerSize',10);
				plot(me.h.axis1, 1:length(me.response), me.inittime,'g.','MarkerSize',10);
				plot(me.h.axis1, 1:length(me.response), me.time,'b.','MarkerSize',10);
			end
			axis(me.h.axis1, 'tight');
			%axis 2
			if ~isempty(me.rt1) 
				if max(me.rt1) == 0 && max(me.rt2) > 0
					histogram(me.h.axis2, [me.rt2'], 8);
				elseif max(me.rt1) > 0 && max(me.rt2) == 0
					histogram(me.h.axis2, [me.rt1'], 8);
				elseif max(me.rt1) > 0 && max(me.rt2) > 0
					histogram(me.h.axis2, [me.rt1' me.rt2'], 8);
				end
				axis(me.h.axis2, 'tight');
			end
			
			%axis 3
			bar(me.h.axis3,hits,'stacked')
			set(me.h.axis3,'XTickLabel', {'all';'newest';'break/abort'})
			axis(me.h.axis3, 'tight');
			ylim(me.h.axis3,[0 100])
			
			%axis 4
			plot(me.h.axis4, 1:length(me.averages), me.averages,'k.-','MarkerSize',12);
			axis(me.h.axis4, 'tight');
			ylim(me.h.axis4,[0 100])
			
			%axis 5
			if ~isempty(me.xAll)
				plot(me.h.axis5, me.xAll, me.yAll, 'b.','MarkerSize',15,'Color',[0.5 0.5 0.8]); hold on
				plot(me.h.axis5, me.xAll(1), me.yAll(1), 'g.','MarkerSize',18);
				plot(me.h.axis5, me.xAll(end), me.yAll(end), 'r.','MarkerSize',18,'Color',[1 0.5 0]); hold off
				axis(me.h.axis5, 'ij');
				grid(me.h.axis5,'on');
				xlim(me.h.axis5,[-15 15]);
				ylim(me.h.axis5,[-15 15]);
			end
			
			set([me.h.axis1 me.h.axis2 me.h.axis3 me.h.axis4], ...
				'Box','on','XGrid','on','YGrid','on','ZGrid','on');
			
			xlabel(me.h.axis1, 'Run Number')
			xlabel(me.h.axis2, 'Time (ms)')
			xlabel(me.h.axis3, 'Group')
			xlabel(me.h.axis4, '#')
			xlabel(me.h.axis5, 'x')
			ylabel(me.h.axis1, 'Yes / No')
			ylabel(me.h.axis2, 'Number #')
			ylabel(me.h.axis3, '% success')
			ylabel(me.h.axis4, '% success')
			ylabel(me.h.axis5, 'y')
			title(me.h.axis1,['Success (' num2str(hitn) ') / Fail (all=' num2str(missn) ' | break=' num2str(breakn) ' | abort=' num2str(missn-breakn) ')'])
			title(me.h.axis2,sprintf('Time:  total: %g | fixinit: %g',mean(me.rt1),mean(me.rt2)));
			title(me.h.axis3,'Hit (blue) / Miss (red) / Break (blue) / Abort (red)')
			title(me.h.axis4,'Average (n=10) Hit / Miss %')
			title(me.h.axis5,'Last Eye Position');
			hn = findobj(me.h.axis2,'Type','patch');
			%set(hn,'FaceColor','k','EdgeColor','k');
			
			t = {['INFORMATION @ ' me.date]};
			t{end+1} = ['RUN:' me.comment];
			t{end+1} = ['INFO:' me.info];
			t{end+1} = ['RADIUS (red) b|n = ' num2str(me.radius(end)) 'deg'];
			t{end+1} = ['INITIATE FIXATION TIME (green) z|x = ' num2str(me.inittime(end)) ' secs'];
			t{end+1} = ['MAINTAIN FIXATION TIME (blue) c|v = ' num2str(me.time(end)) ' secs'];
			t{end+1} = ' ';
			if ~isempty(me.rt1)
				t{end+1} = ['Last/Mean Init Time = ' num2str(me.rt2(end)) ' / ' num2str(mean(me.rt2)) 'secs | Last/Mean Init+Fix = ' num2str(me.rt1(end)) ' / ' num2str(mean(me.rt1)) 'secs'];
			end
			t{end+1} = ['Overall | Latest (n=10) Hit Rate = ' num2str(hitmiss) ' | ' num2str(average)];
			t{end+1} = ['Run time = ' num2str(etime(clock,me.startTime)/60) 'mins'];
			t{end+1} = sprintf('Estimated Volume at %gms TTL = %g mls', me.rewardTime, (me.rewardVolume*me.rewardTime)*hitn);
			set(me.h.info,'String', t');
			
			if ~isempty(me.response)
				n = length(me.response);
				me.trials(n).info = me.info;
				me.trials(n).tick = me.tick;
				me.trials(n).comment = me.comment;
				me.trials(n).response = me.response(n);
			end
			
			me.tick = me.tick + 1;
			
		end

		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function reset(me)
			me.tick = 1;
			me.trials = [];
			me.startTime = [];
			me.response = [];
			me.rt1 = [];
			me.rt2 = [];
			me.info = '';
			me.xAll = [];
			me.yAll = [];
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function plotPerformance(me)
			plot(me);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function clearHandles(me)
			me.h = [];
		end
		
		% ===================================================================
		%> @brief called on save
		%>
		%> @param
		% ===================================================================
		function out = saveobj(me)
			%clearHandles(me);
			fprintf('===> Saving behaviouralRecord object...\n');
			out = me;
		end
		
	end
	
	%=======================================================================
	methods (Static = true) %------------------STATIC METHODS
	%=======================================================================
		% ===================================================================
		%> @brief loadobj
		%> To be backwards compatible to older saved protocols, we have to parse 
		%> structures / objects specifically during object load
		%> @param in input object/structure
		% ===================================================================
		function lobj=loadobj(in)
			if isa(in,'behaviouralRecord') && ~isempty(in.h)
				in.clearHandles();
			end
			lobj = in;
		end
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
	
	end
end