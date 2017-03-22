classdef GalvoController < handle
    properties
        daqSession;
        daqDevices;
        AOX; %analogue out channel X
        AOY; %analogue out channel Y
        x2v_transform; %transforms real position to volts
    end
    
    methods
        
        function obj = GalvoController
            obj.daqSession = daq.createSession('ni');
            obj.daqDevices = daq.getDevices;
            
            obj.AOX = obj.daqSession.addAnalogOutputChannel('Dev1', 0, 'Voltage');
            obj.AOY = obj.daqSession.addAnalogOutputChannel('Dev1', 1, 'Voltage');
        end
        
        function setV(obj,v)
            %single-scan
            obj.daqSession.outputSingleScan(v);
        end
        
        function calib_VtoX(obj,ThorCam)
            %Use grid paper marking mm
            
            V_in = -1:1:1;
            [Vy,Vx] = meshgrid(V_in);
            Vx = Vx(:);
            Vy = Vy(:);
            
            %Go through each voltage, issue to galvo, and determine the
            %real position of that laser dot
            obj.setV([0 0]); pause(0.1);
            
            pos = [];
            for p = 1:length(Vx)
                %Issue voltage to Galvo
                obj.setV([Vx(p) Vy(p)]);
                
                %Use camera to determine the real position of the laser
                %dot. Camera must be calibrated already
                pause(0.5);
                pos(p,:) = ThorCam.getStimPos;
            end
            
            [~,~,obj.x2v_transform] = procrustes([Vx Vy],pos);
            obj.x2v_transform.c = mean(obj.x2v_transform.c,1);
        end
        
        function v=pos2v(obj,pos)
            if isempty(obj.x2v_transform)
                error('need to calibrate');
            end
            v = bsxfun(@plus,obj.x2v_transform.b * pos * obj.x2v_transform.T, obj.x2v_transform.c);
        end
        
        function interact(obj,ThorCam)
            imshow(ThorCam.getFrame);
            
            while 1==1
                pos = ThorCam.getStimPos;
                obj.setV(obj.pos2v(pos));
                pause(0.5);
            end
        end
        
        function scan(obj)
            %scan galvo between multiple points rapidly
            pos = [-1 -1;
                1 1;
                 0 0];
            
            v = obj.pos2v(pos);
            numDots = size(pos,1);
            
            freq = 40*numDots; %40Hz at each location, so in total the scanning should be at 40*n Hz

            obj.daqSession.Rate = 20e3;

            numSamplesOneCycle = obj.daqSession.Rate/freq;
            numSamplesPerSite = round(numSamplesOneCycle/numDots);
            
            waveX = reshape(repmat(pos(:,1),1,numSamplesPerSite)',[],1);
            waveY = reshape(repmat(pos(:,2),1,numSamplesPerSite)',[],1);

            nCycles = 200;

            obj.daqSession.queueOutputData(repmat([waveX, waveY],nCycles,1));
            tic
            obj.daqSession.startForeground;
            toc
            obj.daqSession.stop;

        end
        
        
        function delete(obj)
            delete(obj.daqSession);
        end
    end
    
end