classdef GalvoController < handle
    properties
        device;
        daqSession;
        AO0; %analogue out channel 0
        AO1; %analogue out channel 1
        pos2volt_transform; %transforms real position to volts
    end
    
    methods
        
        function obj = GalvoController(device)
            obj.daqSession = daq.createSession('ni');
            obj.device = device;
            
            try
                obj.AO0 = obj.daqSession.addAnalogOutputChannel(device, 0, 'Voltage');
                obj.AO1 = obj.daqSession.addAnalogOutputChannel(device, 1, 'Voltage');
            catch
                warning(['GalvoController failed to initialise on ' device])
            end
            
            %try loading pos2volt calibration
            try
                obj.loadcalibPOS2VOLT; 
                disp('Loaded position<->voltage calibration');
            catch
                disp('did not load position<->voltage calibration');
            end
        end
        
        function moveNow(obj,v)
            obj.daqSession.outputSingleScan(v);
        end
        
        function calibPOS2VOLTAGE(obj,ThorCam)
            %Requires a ThorCam object for identifying the laser positions
            
            %Use grid paper marking mm
            %Uses thor camera calibration to get measure of real position
            %of a laser dot
            
            V_in = -1:0.5:1;
            [Vy,Vx] = meshgrid(V_in);
            Vx = Vx(:);
            Vy = Vy(:);
            
            %Go through each voltage, issue to galvo, and determine the
            %real position of that laser dot
            obj.moveNow([0 0]); pause(0.1);
            
            pos = [];
            for p = 1:length(Vx)
                %Issue voltage to Galvo
                obj.moveNow([Vx(p) Vy(p)]);
                
                %Use camera to determine the real position of the laser
                %dot. Camera must be calibrated already
                pause(0.5); %allow time for laser to move and new image to enter camera memory
                pos(p,:) = ThorCam.getStimPos('manual');
            end
            
            [~,~,obj.pos2volt_transform] = procrustes([Vx Vy],pos);
            obj.pos2volt_transform.c = mean(obj.pos2volt_transform.c,1);
            
            pos2volt_transform = obj.pos2volt_transform;
            
            mfiledir = fileparts(mfilename('fullpath'));
            filename = fullfile(mfiledir,'calib','calib_POS-VOLT.mat');
            save(filename,'pos2volt_transform');
        end
        
        function v = generateWaveform(obj,frequency,volts,totalTime)
            rate = obj.daqSession.Rate;
            t = 0:(1/rate):totalTime; t(1)=[];
            
            numDots = size(volts,1);
            
            waveX = nan(size(t));
            waveY = nan(size(t));
            
            for d = 1:numDots
                idx = square(2*pi*frequency*t/numDots - (d-1)*(2*pi)/numDots,100/numDots)==1;
                waveX(idx) = volts(d,1);
                waveY(idx) = volts(d,2);
            end
            
            v = [waveX' waveY'];
            
        end
        
        function v=pos2v(obj,pos)
            if isempty(obj.pos2volt_transform)
                error('need to calibrate');
            end
            v = bsxfun(@plus,obj.pos2volt_transform.b * pos * obj.pos2volt_transform.T, obj.pos2volt_transform.c);
        end
        
        function issueWaveform(obj,V_IN)
            obj.daqSession.queueOutputData(V_IN);
            obj.daqSession.startBackground;
        end
        
        function registerTrigger(obj,pinID) %Any issued waveforms will wait for an input from this trigger
            obj.daqSession.addTriggerConnection('external', pinID, 'StartTrigger');
        end
        
        function removeTrigger(obj)
            obj.daqSession.removeConnection(1);
        end
        
        function stop(obj)
            obj.daqSession.stop;
        end
        
        function loadcalibPOS2VOLT(obj)
            mfiledir = fileparts(mfilename('fullpath'));
            filename = fullfile(mfiledir,'calib','calib_POS-VOLT.mat');
            t = load(filename);
            obj.pos2volt_transform = t.pos2volt_transform;
        end
        
        function delete(obj)
            delete(obj.daqSession);
        end
    end
    
end