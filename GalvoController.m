classdef GalvoController < handle
    properties
        daqSession;
        daqDevices;
        AOX; %analogue out channel X
        AOY; %analogue out channel Y
        pos2volt_transform; %transforms real position to volts
    end
    
    methods
        
        function obj = GalvoController(device)
            obj.daqSession = daq.createSession('ni');
            obj.daqDevices = daq.getDevices;
            
            obj.AOX = obj.daqSession.addAnalogOutputChannel(device, 0, 'Voltage');
            obj.AOY = obj.daqSession.addAnalogOutputChannel(device, 1, 'Voltage');
            
            %try loading pos2volt calibration
            try
                obj.loadcalibPOS2VOLT; 
                disp('Loaded position<->voltage calibration');
            catch
                disp('did not load calibration');
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
            
            [~,~,obj.pos2volt_transform] = procrustes([Vx Vy],pos);
            obj.pos2volt_transform.c = mean(obj.pos2volt_transform.c,1);
            
            pos2volt_transform = obj.pos2volt_transform;
            
            mfiledir = fileparts(mfilename('fullpath'));
            filename = fullfile(mfiledir,'calib','calib_POS-VOLT.mat');
            save(filename,'pos2volt_transform');
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