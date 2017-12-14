classdef LaserController < handle
    %Code which handles a laser output, connected to AO0 channel on a NIDAQ
    %board. 
    properties
        laserCfg;
        daqSession;
        AO0;

        volt2laserPower;
    end
    
    methods
        function obj = LaserController(laserCfg)
            obj.laserCfg = laserCfg;
            obj.daqSession = daq.createSession('ni');
            try
                obj.AO0 = obj.daqSession.addAnalogOutputChannel(obj.laserCfg.device, obj.laserCfg.channel, 'Voltage');
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
%             obj.daqSession.outputSingleScan(0);
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
                case 'square'
                    volt = -0.5*amplitudeVoltage*square(2*pi*frequency*t) + 0.5*amplitudeVoltage;
                    
                case 'DC'
                    volt = ones(length(t),1)*amplitudeVoltage;
            end
            
            volt(end)=0;
        end

        function issueWaveform(obj,V_IN)
%             disp('STARTING ISSUING WAVEFORM');
            obj.daqSession.queueOutputData(V_IN);
%             disp('QUEUED DATA');
            obj.daqSession.startBackground;
%             disp('STARTED BACKGROUND');

        end
        
        function registerTrigger(obj,pinID) %Any issued waveforms will wait for an input from this trigger
            obj.daqSession.addTriggerConnection('external', pinID, 'StartTrigger');
        end
        
        function removeTrigger(obj)
            obj.daqSession.removeConnection(1);
        end
        
        function calibPOWER2VOLT(obj,range)
            %Issues different voltages to the laser to calibrate the power,
            %requires manually inputting the laser power
            
            volts = linspace(range(1),range(2),20)';
            power_DC = nan(size(volts));
            power_40Hz = nan(size(volts));
            power_80HzHalf = nan(size(volts));
            
            t = table(volts,power_DC,power_40Hz,power_80HzHalf);
            
            for i = 1:length(t.volts)
                laserV = obj.generateWaveform('DC',[],t.volts(i),10,[]);
                obj.issueWaveform(laserV);
                
                t.power_DC(i) = input('Power [mW]:');
                obj.stop;
            end
            
            for i = 1:length(t.volts)
                %Set laser power
%                 obj.daqSession.outputSingleScan(volts(i));
                
                laserV = obj.generateWaveform('truncatedCos',40,t.volts(i),10,[]);
                obj.issueWaveform(laserV);
                
                t.power_40Hz(i) = input('Power [mW]:');
                obj.stop;
            end
            
            for i = 1:length(t.volts)
                laserV = obj.generateWaveform('truncatedCosHalf',80,t.volts(i),10,2);
                obj.issueWaveform(laserV);
                
                t.power_80HzHalf(i) = input('Power [mW]:');
                obj.stop;                 
            end
                     
            figure;
            plot(t.volts,t.power_DC,'ko-',t.volts,t.power_40Hz,'ro-',t.volts,t.power_80HzHalf,'bo-'); ylabel('Power [mW]'); xlabel('Volts');
            legend('DC','40Hz without scanning galvo','80Hz with scanning galvo (40Hz per-site)');

            %If any duplicate entries, manually trim away in calibration
            tab0 = tabulate(t.power_DC);
            tab1 = tabulate(t.power_40Hz);
            tab2 = tabulate(t.power_80HzHalf);
            
            if any(tab0(:,2)>2) || any(tab1(:,2)>2) || any(tab2(:,2)>2)
                warning('Duplicate power entries, please manually remove');
                keyboard;
            end
            %Trim the values where power is zero
%             idx = t.power_40Hz==0 | t.power_80HzHalf ==0;
            
%             volts(power==0)=[];
%             power(power==0)=[];

%             if any(diff(power) < 0)
%                 error('Not monotonically increasing power');
%             end
%             
            volt2laserPower = t;
            save(obj.laserCfg.calibFile,'volt2laserPower');
            obj.volt2laserPower = volt2laserPower;
        end
        
        function loadcalibPOWER2VOLT(obj)
            t = load(obj.laserCfg.calibFile);
            obj.volt2laserPower = t.volt2laserPower;
            
            t = obj.volt2laserPower;
            figure;
            h0 = plot(t.volts,t.power_DC,'ko-',t.volts,t.power_40Hz,'ro-',t.volts,t.power_80HzHalf,'bo-'); ylabel('Power [mW]'); xlabel('Volts');
            legend(h0,'DC','40Hz without scanning galvo','80Hz with scanning galvo (40Hz per-site)');
%             hold on;
%             h1 = line(get(gca,'xlim'),[1 1]*max(t.power_DC));
%             set(h1,'LineStyle','--','Color','k');
%             h2 = line(get(gca,'xlim'),[1 1]*max(t.power_40Hz));
%             set(h2,'LineStyle','--','Color','r');
%             h3 = line(get(gca,'xlim'),[1 1]*max(t.power_80HzHalf));
%             set(h3,'LineStyle','--','Color','b');
        end
        
        function v = power2volt(obj,desiredPower,type)
            if isempty(obj.volt2laserPower)
                error('Need to calibrate laser power to voltage');
            end
            
            volts = obj.volt2laserPower.volts;
            
            switch(type)
                case 'DC'
                    power = obj.volt2laserPower.power_DC;
                case '40Hz'
                    power = obj.volt2laserPower.power_40Hz;
                case '80HzHalf'
                    power = obj.volt2laserPower.power_80HzHalf;
                otherwise
                    error('unspecified');
            end
            
            %Trim away zero power
            idx = power==0;
            volts(idx)=[];
            power(idx)=[];
            
            if desiredPower > max(power)
                error('power desired outside of calibrated range');
            end
            
            %Local interpolation from the calibration data
            v = interp1(power,volts,desiredPower);            
        end
        
        function stop(obj)
            obj.daqSession.stop;
            obj.daqSession.outputSingleScan(0);
        end
        
        function delete(obj)
            delete(obj.daqSession);
        end
        
    end
end
