classdef timeLogger < optickaCore
	%TIMELOGGER Simple class used to store the timing data from an experiment
	%  timeLogger stores timing data for a taskrun and optionally graphs the
	%  result.
	
	properties
		screenLog		= struct()
		timer			= @GetSecs
		vbl				= 0
		show			= 0
		flip			= 0
		miss			= 0
		stimTime		= 0
		tick			= 0
		tickInfo		= 0
		startTime		= 0
		startRun		= 0
		messages struct	= struct('tick',[],'vbl',[],'message',{})
		verbose			= true
		stimStateNames	= {'stimulus','onestep','twostep'}
	end
	
	properties (SetAccess = private, GetAccess = public)
		missImportant
		nMissed
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = 'stimStateNames|timer'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief Constructor
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function me=timeLogger(varargin)
			if nargin == 0; varargin.name = 'timeLog';end
			if nargin>0; me.parseArgs(varargin,me.allowedProperties); end
			if isempty(me.name);me.name = 'timeLog'; end
			if ~exist('GetSecs','file')
				me.timer = @now;
			end
			me.screenLog.construct = me.timer();
		end
		
		% ===================================================================
		%> @brief Preallocate array a bit more efficient
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function preAllocate(me,n)
			me.vbl = zeros(1,n);
			me.show = me.vbl;
			me.flip = me.vbl;
			me.miss = me.vbl;
			me.stimTime = me.vbl;
		end
		
		% ===================================================================
		%> @brief if we preallocated, remove empty 0 values
		%>
		%> @param
		%> @return
		% ===================================================================
		function removeEmptyValues(me)
			idx = find(me.vbl == 0);
			me.vbl(idx) = [];
			me.show(idx) = [];
			me.flip(idx) = [];
			me.miss(idx) = [];
			me.stimTime(idx) = [];
			index=min([length(me.vbl) length(me.flip) length(me.show) length(me.stimTime)]);
			try
				me.vbl=me.vbl(1:index);
				me.show=me.show(1:index);
				me.flip=me.flip(1:index);
				me.miss=me.miss(1:index);
				me.stimTime=me.stimTime(1:index);
			end
		end
		
		% ===================================================================
		%> @brief print Log of the frame timings
		% ===================================================================
		function plot(me)
			me.printRunLog();
		end
		
		% ===================================================================
		%> @brief 
		% ===================================================================
		function logStim(me, name, tick)
			if contains(name, me.stimStateNames)
				me.stimTime(tick) = 1;
			else
				me.stimTime(tick) = 0;
			end
		end
		
		% ===================================================================
		%> @brief 
		% ===================================================================
		function addMessage(me, tick, message)
			
		end
		
		% ===================================================================
		%> @brief print Log of the frame timings
		%>
		%> @param
		%> @return
		% ===================================================================
		function printRunLog(me)
			if length(me.vbl) <= 5
				disp('No timing data available...')
				return
			end
			
			removeEmptyValues(me)
			
			vbl=me.vbl.*1000; %#ok<*PROP>
			show=me.show.*1000;
			flip=me.flip.*1000; 
			miss=me.miss;
			stimTime=me.stimTime;
			
			calculateMisses(me,miss,stimTime)
			
			ssz = get(0,'ScreenSize');
			figure('Name',me.name,'NumberTitle','off','Color',[1 1 1],...
				'Position', [10 1 round(ssz(3)/3) ssz(4)]);
			tl = tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
			
			nexttile;
			hold on
			vv=diff(vbl);
			vv(vv>100)=100;
			plot(vv,'ro:')
			ss=diff(show);
			ss(ss>100)=100;
			plot(ss,'b--')
			ff = diff(flip);
			ff(ff>100)=100;
			plot(ff,'g-.')
			plot(stimTime(2:end)*100,'k-')
			hold off
			legend('VBL','Show','Flip','Stim ON')
			[m,e]=me.stderr(diff(vbl));
			t=sprintf('VBL mean=%.3f ?? %.3f s.e.', m, e);
			[m,e]=me.stderr(diff(show));
			t=[t sprintf(' | Show mean=%.3f ?? %.3f', m, e)];
			[m,e]=me.stderr(diff(flip));
			t=[t sprintf(' | Flip mean=%.3f ?? %.3f', m, e)];
			title(t)
			xlabel('Frame number (difference between frames)');
			ylabel('Time (milliseconds)');
			box on; grid on; grid minor;
			
			nexttile;
			x = 1:length(show);
			hold on
			plot(x,show-vbl,'r')
			plot(x,show-flip,'g')
			plot(x,vbl-flip,'b-.')
			plot(x,stimTime-0.5,'k')
			legend('Show-VBL','Show-Flip','VBL-Flip','Simulus ON/OFF');
			hold off
			[m,e]=me.stderr(show-vbl);
			t=sprintf('Show-VBL=%.3f ?? %.3f', m, e);
			[m,e]=me.stderr(show-flip);
			t=[t sprintf(' | Show-Flip=%.3f ?? %.3f', m, e)];
			[m,e]=me.stderr(vbl-flip);
			t=[t sprintf(' | VBL-Flip=%.3f ?? %.3f', m, e)];
			title(t);
			xlabel('Frame number');
			ylabel('Time (milliseconds)');
			box on; grid on; grid minor;
			
			nexttile;
			hold on
			miss(miss > 0.05) = 0.05;
			plot(miss,'k.-');
			plot(me.missImportant,'ro','MarkerFaceColor',[1 0 0]);
			plot(stimTime/30,'k','linewidth',1);
			hold off
			title(['Missed frames = ' num2str(me.nMissed) ' (RED > 0 means missed frame)']);
			xlabel('Frame number');
			ylabel('Miss Value');
			box on; grid on; grid minor;
			
			clear vbl show flip index miss stimTime
		end
		
		% ===================================================================
		%> @brief calculate genuine missed stim frames
		%>
		%> @param
		%> @return
		% ===================================================================
		function calculateMisses(me,miss,stimTime)
			removeEmptyValues(me)
			if nargin == 1
				miss = me.miss;
				stimTime = me.stimTime;
			end
			me.missImportant = miss;
			me.missImportant(me.missImportant <= 0) = -inf;
			me.missImportant(stimTime < 1) = -inf;
			me.missImportant(1) = -inf; %ignore first frame
			me.nMissed = length(find(me.missImportant > 0));
		end
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function [avg,err] = stderr(me,data)
			avg=mean(data);
			err=std(data);
			err=sqrt(err.^2/length(data));
		end
		
	end
	
end

