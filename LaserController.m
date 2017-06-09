classdef LaserController < handle
    %Code which handles a laser output, connected to AO0 channel on a NIDAQ
    %board. 
    properties
        device;
        daqSession;
        AO0;
        
        volt2laserPower_transform;
    end
    
    methods
        function obj = LaserController(device)
            obj.device = device;
            obj.daqSession = daq.createSession('ni');
            try
                obj.AO0 = obj.daqSession.addAnalogOutputChannel(device, 0, 'Voltage');
            catch
                warning(['LaserController failed to initialise on ' device])
            end
            
            %try loading pos2volt calibration
            try
                obj.loadcalibPOWER2VOLT; 
                disp('Loaded power<->voltage calibration');
            catch
                disp('did not load power<->voltage calibration');
            end
            
            %Set to zero output if not already
            obj.daqSession.outputSingleScan(0);
        end
        
        function volt = generateWaveform(obj,type,frequency,amplitudeVoltage,totalTime,otherInfo)
            rate = obj.daqSession.Rate;
            t = (0:(1/rate):totalTime)'; t(1)=[];
            galvoMoveTime = 2e-3; %The amount of time allowed for galvos to move, inbetween laser cycles
            numElements = round(rate*galvoMoveTime/2);
            if numElements == 0
                numElements = 1;
            end
            
            switch(type)
                case 'truncatedCosHalf' %Cycle 1,3,5... is set to zero
                    numDots = otherInfo;
                    
                    sq = cumsum(diff(square(2*pi*frequency*t))>0); sq=[sq;0];

                    volt = -0.5*amplitudeVoltage*cos(2*pi*frequency*t) + 0.5*amplitudeVoltage;
                    
                    
                    idx = mod(sq,numDots)==0; %Indices to turn one cycle off
                    volt(~idx) = 0;
                    
                    cutOff = volt(numElements);
                    volt(volt<cutOff) = 0;
                case 'truncatedCos'                 
                    volt = -0.5*amplitudeVoltage*cos(2*pi*frequency*t) + 0.5*amplitudeVoltage;
                    cutOff = volt(numElements);

                    %Truncate at output level
                    volt(volt<cutOff) = 0;
            end
            
            volt(end)=0;
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
        
        function calibPOWER2VOLT(obj)
            %Issues different voltages to the laser to calibrate the power,
            %requires manually inputting the laser power
            
            volts = linspace(1,5,20)';
            power = nan(size(volts));
            
            for i = 1:length(volts)
                %Set laser power
%                 obj.daqSession.outputSingleScan(volts(i));
                
                laserV = obj.generateWaveform('trunacedCosHalf',80,volts(i),5,2);
                obj.issueWaveform(laserV);
                
                power(i) = input('Power [mW]:');
            end
            volt2laserPower = fit(volts,power,'linearinterp');
            
            figure;
            plot(volt2laserPower,volts,power,'o'); ylabel('Power [mW]'); xlabel('Volts');

            obj.volt2laserPower_transform = volt2laserPower;
            
            mfiledir = fileparts(mfilename('fullpath'));
            filename = fullfile(mfiledir,'calib','calib_VOLT-LPOWER.mat');
            save(filename,'volt2laserPower');
        end
        
        function loadcalibPOWER2VOLT(obj)
            mfiledir = fileparts(mfilename('fullpath'));
            filename = fullfile(mfiledir,'calib','calib_VOLT-LPOWER.mat');
            t = load(filename);
            obj.volt2laserPower_transform = t.laserPower2volt;
        end
        
        function v = power2volt(obj,power)
            if isempty(obj.laserPower2volt_transform)
                error('Need to calibrate laser power to voltage');
            end
            
            v = obj.laserPower2volt_transform*power; %TO DO
        end
        
        function stop(obj)
            obj.daqSession.stop;
            obj.daqSession.outputSingleScan(0); %Turn laser off
        end
        
        function delete(obj)
            delete(obj.daqSession);
        end
        
    end
end
