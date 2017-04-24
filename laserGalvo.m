classdef laserGalvo < handle
    %object which handles interfacing the galvo setup with MC
    
    properties
        device='Dev1';
        thorcam;
        galvo;
                
        expServerObj;
        coordList;
        probLaser; %probability of a laser trial
        
        LED_daqSession;
        LEDch;
        
        monitor_daqSession;
        monitor_led;
        monitor_gx;
        monitor_gy;
        
        mode;
        mouseName;
        expNum;
        expDate;
        log;
        filepath;
    end
    
    methods
        function obj = laserGalvo
            
            %Get camera object
            obj.thorcam = ThorCam;
            
            %Get galvo controller object
            obj.galvo = GalvoController(obj.device);
            
            %Add LED output channels to the galvo session
            obj.LED_daqSession = daq.createSession('ni');
            obj.LEDch = obj.LED_daqSession.addCounterOutputChannel('Dev1', 'ctr0', 'PulseGeneration');
            obj.LED_daqSession.IsContinuous=1;

            obj.monitor_daqSession = daq.createSession('ni');
            obj.monitor_daqSession.Rate = 60e3;
            obj.monitor_led = obj.monitor_daqSession.addAnalogInputChannel('Dev1', 'ai1', 'Voltage');
            obj.monitor_gx = obj.monitor_daqSession.addAnalogInputChannel('Dev1', 'ai3', 'Voltage');
            obj.monitor_gy = obj.monitor_daqSession.addAnalogInputChannel('Dev1', 'ai2', 'Voltage');
            
            obj.monitor_led.TerminalConfig = 'SingleEnded';
            obj.monitor_gx.TerminalConfig = 'SingleEnded';
            obj.monitor_gy.TerminalConfig = 'SingleEnded';
            
            try
                obj.registerListener;
            catch
                warning('Failed to register expServer listener');
            end
            
            disp('Please run stereotaxic calibration');
        end
        
        function configureExpt(obj,mode,coordinates,probabilityOfLaser)
            modes = {'unilateral_static','unilateral_scan','bilateral_scan'};
            m = strcmp(mode,modes);
            
            if ~any(m==1)
                error('not possible');
            end

            obj.mode = mode;
                        
            switch(coordinates)
                case 'allSites'
                    obj.coordList = fliplr([...
                        -4*ones(8,1) (-3.5:3.5)'; ...
                        -3*ones(8,1) (-3.5:3.5)'; ...
                        -2*ones(8,1) (-3.5:3.5)'; ...
                        -1*ones(8,1) (-3.5:3.5)'; ...
                        0*ones(8,1) (-3.5:3.5)'; ...
                        1*ones(6,1) (-2.5:2.5)'; ...
                        2*ones(4,1) (-1.5:1.5)'; ...
                        3*ones(2,1) (-0.5:0.5)']);
                otherwise
                    error('invalid coordinate profile');
            end
            
            obj.probLaser = probabilityOfLaser; %probability of trial being a laser trial
            
            obj.log = struct;
        end
        
        function monitor(obj)
            
            %set monitoring to trigger when there is a pulse on PFI0
            try
                obj.monitor_daqSession.addTriggerConnection('external', 'Dev2/PFI2', 'StartTrigger');
            catch
            end
            obj.monitor_daqSession.DurationInSeconds = 3;
            
            
            tDelays = linspace(0.3/1000,0.8/1000,3);
%             
            figure;
            for i = 1:length(tDelays)
%                 obj.scan(1,tDelays(i));
                obj.scan(3);
                data = obj.monitor_daqSession.startForeground;
                
                tAxis = (0:length(data)-1)/obj.monitor_daqSession.Rate;
                
                h(i)=subplot(length(tDelays),1,i);
                plot(tAxis, data); ylabel(num2str(tDelays(i)));
                obj.stop;
            end
            linkaxes(h,'x');
        end
        
        function calibStereotaxic(obj)
            obj.thorcam.calibPIX2STE;
        end
        
        function calibVoltages(obj)
            obj.galvo.calibPOS2VOLTAGE(obj.thorcam);
        end
        
        function interact(obj)
            disp('Exit by pressing q');
            
            f=figure;
            ax = axes('Parent',f);
            while 1 == 1
                img = obj.thorcam.getFrame;
                image(img,'Parent',ax);
                [pix_x,pix_y,button] = ginput(1);
                
                if button==113 %q button
                    break;
                end
                
                pos = obj.thorcam.pix2pos([pix_x pix_y]);
                obj.galvo.setV(obj.galvo.pos2v(pos));
                disp(['X=' num2str(pos(1)) ' Y=' num2str(pos(2))]);
                
                pause(0.5);
            end
            
            
            
        end
        
        function scan(obj,pos,totalTime)
            %scan galvo between multiple points rapidly used for bilateral
            %inactivation
            
%             pos = [2 2;
%                    2 -2;
%                    -2 -2;
%                    -2 2];
%             
            v = obj.galvo.pos2v(pos);
            
%             v = [-1 -1; 1 1; 0 2; 0 3];
            numDots = size(v,1);
            
            %Setup LED stimulation
            obj.LEDch.Frequency = 40*numDots; %we want 40Hz laser at each location, therefore laser needs to output 40*n Hz if multiple sites
            obj.LEDch.DutyCycle = 0.90;
            
%             DAQ_Rate = numSamples*obj.LEDch.Frequency; %sample rate processed on the galvo DAQ session
            obj.galvo.daqSession.Rate = 20e3;
            DAQ_Rate = obj.galvo.daqSession.Rate; %get back real rate
            
            %galvo needs to place the laser at each location for the length
            %of the LED's single cycle.
            t = [0:(1/DAQ_Rate):totalTime]; t(1)=[];
            
            waveX = nan(size(t));
            waveY = nan(size(t));

            for d = 1:numDots
                idx = square(2*pi*obj.LEDch.Frequency*t/numDots - (d-1)*(2*pi)/numDots,100/numDots)==1;
                waveX(idx) = v(d,1);
                waveY(idx) = v(d,2);
            end
            
            V_IN = [waveX' waveY'];
            
            %Register the trigger for galvo and LEDs
            try
                obj.galvo.daqSession.addTriggerConnection('external', 'Dev1/PFI0', 'StartTrigger');
                obj.LED_daqSession.addTriggerConnection('external', 'Dev1/PFI1', 'StartTrigger');
            catch
            end
            
            %Trim galvo waveform to ensure galvos move slightly earlier
            %compare to the LED waveform
            LED_dt = 1/obj.LEDch.Frequency; %the amount of time taken for the LED to cycle once
            galvoDelay = 0.3/1000; %0.4ms delay required to move the galvos
            delay = 0.5*(1-obj.LEDch.DutyCycle)*LED_dt + galvoDelay;
            trimSamples = round(DAQ_Rate * delay);
            V_IN = circshift(V_IN,-trimSamples);
            
            
            
            %issue voltage trace to analogue-out channels of galvo
            obj.galvo.issueWaveform(V_IN);

            %start laser background
            obj.LED_daqSession.startBackground;
            
            obj.galvo.daqSession.wait();
            obj.stop;
        end
        
        function scanOnePos(obj,pos,totalTime) 
            if size(pos,1)>1
                error('only specify one position!');
            end
            
            %add a 2nd point which is the contralateral partner
            pos = [pos; -pos(1) pos(2)];
            
            %Move galvos between all sites in POS but only illuminate the
            %laser on the first of them
            v = obj.galvo.pos2v(pos);
            numDots = size(v,1);
            
            obj.galvo.daqSession.Rate = 20e3;
            DAQ_Rate = obj.galvo.daqSession.Rate; %get back real rate
            
            t = [0:(1/DAQ_Rate):totalTime]; t(1)=[];
            
            waveX = nan(size(t));
            waveY = nan(size(t));
            
            obj.LEDch.Frequency = 40*numDots;
            obj.LEDch.DutyCycle = 0.90;
            
            for d = 1:numDots
                idx = square(2*pi*obj.LEDch.Frequency*t/numDots - (d-1)*(2*pi)/numDots,100/numDots)==1;
                waveX(idx) = v(d,1);
                waveY(idx) = v(d,2);
            end
            
            V_IN = [waveX' waveY'];
            
            %Trim galvo waveform to ensure galvos move slightly earlier
            %compare to the LED waveform
            LED_dt = 1/obj.LEDch.Frequency;
            galvoDelay = 0.3/1000; %0.4ms delay required to move the galvos
            delay = 0.5*(1-obj.LEDch.DutyCycle)*LED_dt + galvoDelay;
            trimSamples = round(DAQ_Rate * delay);
            V_IN = circshift(V_IN,-trimSamples);

            %Register the trigger for galvo and LEDs
            try
                obj.galvo.daqSession.addTriggerConnection('external', 'Dev2/PFI0', 'StartTrigger');
                %                 obj.LED_daqSession.addTriggerConnection('external', 'Dev2/PFI1', 'StartTrigger');
            catch
            end
            
            
            obj.LEDch.Frequency = 40;
            obj.LEDch.DutyCycle = obj.LEDch.DutyCycle/numDots; 
            
            %issue voltage trace to analogue-out channels of galvo
            obj.galvo.issueWaveform(V_IN);
            
            %start laser background
            obj.LED_daqSession.startBackground;
            
        end
        
        function registerListener(obj)
            %Connect to expServer, registering a callback function
            s = srv.StimulusControl.create('zym2');
            s.connect(true);
            anonListen = @(srcObj, eventObj) laserGalvo_callback(eventObj, obj);
            addlistener(s, 'ExpUpdate', anonListen);
            obj.expServerObj = s;
        end

        function stop(obj)
            obj.LED_daqSession.stop;
            obj.galvo.daqSession.stop;
            obj.monitor_daqSession.stop;
            
        end
        
         function saveLog(obj)
            log = obj.log;
            save(obj.filePath, 'log');        
        end
        
        function delete(obj)
            obj.thorcam.delete;
            obj.galvo.delete;
            delete(obj.LED_daqSession);
            delete(obj.monitor_daqSession);
        end
        
    end
end