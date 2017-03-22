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
        
        function setV(v)
            %single-scan
            obj.daqSession.outputSingleScan(v);
        end
        
        function calib_VtoX(obj,ThorCam)
            %Use grid paper marking mm
            
            V_in = -3:0.5:3;
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
        end
        
        function calib_XtoS(obj,ThorCam)
            %calibrate realPos to stereotaxis pos according to bregma +
            %lambda
            
            %Get bregma position
            bregPos = ThorCam.getStimPos;
            
            %get lambda pos
            lambdaPos = ThorCam.getStimPos;
            
            
            %derive translation and rotation transformations
            %
        end
        
        
        
        function MCLISTENER
        end
        
    end
    
end