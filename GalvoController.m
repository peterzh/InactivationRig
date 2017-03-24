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
            
            obj.AOX = obj.daqSession.addAnalogOutputChannel('Dev2', 0, 'Voltage');
            obj.AOY = obj.daqSession.addAnalogOutputChannel('Dev2', 1, 'Voltage');
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
                pause(0.5); %allow time for laser to move and new image to enter camera memory
                pos(p,:) = ThorCam.getStimPos('auto');
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
            disp('Exit by pressing q');
            
            f=figure;
            ax = axes('Parent',f);
            while 1 == 1
                img = ThorCam.getFrame;
                image(img,'Parent',ax);
                [pix_x,pix_y,button] = ginput(1);
                
                if button==113 %q button
                    break;
                end
                
                pos = ThorCam.pix2pos([pix_x pix_y]);
                obj.setV(obj.pos2v(pos));
                disp(['X=' num2str(pos(1)) ' Y=' num2str(pos(2))]);
                
                pause(0.5);
            end
    
        end
        
        function scan(obj,totalTime)
            %scan galvo between multiple points rapidly
            pos = [3 0;
                -3 0];
%                  0 0;
%                 2 2];
            
            v = obj.pos2v(pos);
            numDots = size(pos,1);
            
            LED_freq = 40*numDots; %we want 40Hz laser at each location, therefore laser needs to output 40*n Hz if multiple sites
%             LED_freq = 100*numDots;
            
            obj.daqSession.Rate = 20e3; %sample rate processed on the DAQ
            
            %galvo needs to place the laser at each location for the length
            %of the LED's single cycle. 
            
            LED_dt = 1/LED_freq; %the amount of time taken for the LED to cycle once
            Rate_dt = 1/obj.daqSession.Rate; %the amount of time taken for the DAQ to read one sample
            
            %the number of DAQ samples required to cover one LED cycle
            numSamples = round(LED_dt/Rate_dt); %which corresponds to the number of samples the galvo should position the laser at each site
            
            
            waveX = reshape(repmat(v(:,1),1,numSamples)',[],1);
            waveY = reshape(repmat(v(:,2),1,numSamples)',[],1);
            
            totalNumSamples = obj.daqSession.Rate * totalTime;
            nCycles = round(totalNumSamples/length(waveX));
            
            V_IN = repmat([waveX, waveY],nCycles,1);
            
            %add 1 sample on the end to bring the laser back to zero
            V_IN = [V_IN; obj.pos2v([0 0])];
            
            obj.daqSession.queueOutputData(V_IN);
            obj.daqSession.startBackground;
%             toc
%             obj.daqSession.stop;

        end
        
        function stop(obj)
            obj.daqSession.stop;
        end
        
        
        function delete(obj)
            delete(obj.daqSession);
        end
    end
    
end