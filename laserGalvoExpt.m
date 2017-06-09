classdef laserGalvoExpt < handle
    %object which handles interfacing the galvo setup with MC
    
    properties
        galvoDevice='Dev1';
        laserDevice='Dev2';
        %         monitorDevice='Dev2';
        
        thorcam;
        galvo;
        laser;
        %         monitor;
        
        expServerObj;
        galvoCoords;
        
        mode;
        mouseName;
        expNum;
        expDate;
        log;
        filepath;
    end
    
    methods
        function obj = laserGalvoExpt
            
            %Get camera object
            obj.thorcam = ThorCamController;
            
            %Get galvo controller object
            obj.galvo = GalvoController(obj.galvoDevice);
            
            %Get laser controller object
            obj.laser = LaserController(obj.laserDevice);
            
            %Setup monitor channels
            %             obj.monitor = MonitorController(obj.monitorDevice);
            
            %Set equal rates
            obj.galvo.daqSession.Rate = 30e3;
            obj.laser.daqSession.Rate = 30e3;
            %             obj.monitor.daqSession.Rate = 30e3;
            
            disp('Please run stereotaxic calibration, then register listener');
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
                obj.galvo.moveNow(obj.galvo.pos2v(pos));
                disp(['X=' num2str(pos(1)) ' Y=' num2str(pos(2))]);
                
                pause(0.5);
            end
            
            
            
        end
        
        function scan(obj,mode,pos,totalTime,laserAmplitude)
            %scan galvo between multiple points rapidly used for multi-site
            %inactivation
            %This function assumes that the triggers are registered
            %elsewhere
            
            numDots = size(pos,1);
            laserFreqAtEachSite = 40;
            laserFreq = laserFreqAtEachSite*numDots;
            
            v = obj.galvo.pos2v(pos);
            galvoFreq = laserFreqAtEachSite*numDots;
            galvoV = obj.galvo.generateWaveform(galvoFreq,v,totalTime);
            
            switch(mode)
                case 'multisite' %Illuminate each location
                    laserV = obj.laser.generateWaveform('truncatedCos',laserFreq,laserAmplitude,totalTime,[]);
                case 'onesite'
                    laserV = obj.laser.generateWaveform('truncatedCosHalf',laserFreq,laserAmplitude,totalTime,numDots);
                case 'multisite_laseroff'
                    laserV = zeros(size(galvoV,1),1);
            end
            
            %shift galvo waveform to ensure galvos move slightly earlier
            %compare to the LED waveform because galvo has a delay to
            %action
            %             galvo_laser_delay = 1e-3; %Delay between laser UP state and galvo movement
            %             numEle = obj.galvo.daqSession.Rate*galvo_laser_delay;
            %             galvoV = circshift(galvoV,numEle);
            
            rate = obj.galvo.daqSession.Rate;
            t = 0:(1/rate):totalTime; t(1)=[];
            %             f=figure;
            %             plot(t,galvoV,t,laserV); xlim([0 0.1]);
            
            %issue voltage trace to analogue-out channels of galvo
            obj.galvo.issueWaveform(galvoV);
            obj.laser.issueWaveform(laserV);
        end
        
        function scanManual(obj,mode,pos,totalTime,laserAmplitude)
            %scan galvo between multiple points rapidly used for multi-site
            %inactivation
            %This function includes trigger setting up and removal, and a
            %monitor channel for a photodiode
            
            numDots = size(pos,1);
            laserFreqAtEachSite = 40;
            laserFreq = laserFreqAtEachSite*numDots;
            
            v = obj.galvo.pos2v(pos);
            galvoFreq = laserFreqAtEachSite*numDots;
            galvoV = obj.galvo.generateWaveform(galvoFreq,v,totalTime);
            
            switch(mode)
                case 'multisite' %Illuminate each location
                    laserV = obj.laser.generateWaveform('truncatedCos',laserFreq,laserAmplitude,totalTime,[]);
                case 'onesite'
                    laserV = obj.laser.generateWaveform('truncatedCosHalf',laserFreq,laserAmplitude,totalTime,numDots);
                case 'multisite_laseroff'
                    laserV = zeros(size(galvoV,1),1);
            end
            
            %Register the trigger for galvo and LEDs to start together
            obj.galvo.registerTrigger([obj.galvoDevice '/PFI0']);
            obj.laser.registerTrigger([obj.laserDevice '/PFI0']);
            %             obj.monitor.registerTrigger([obj.monitorDevice '/PFI0']);
            disp('registered triggers');
            
            %shift galvo waveform to ensure galvos move slightly earlier
            %compare to the LED waveform because galvo has a delay to
            %action
            %             galvo_laser_delay = 1e-3; %Delay between laser UP state and galvo movement
            %             numEle = obj.galvo.daqSession.Rate*galvo_laser_delay;
            %             galvoV = circshift(galvoV,numEle);
            
            rate = obj.galvo.daqSession.Rate;
            t = 0:(1/rate):totalTime; t(1)=[];
            %             f=figure;
            %             plot(t,galvoV,t,laserV); xlim([0 0.1]);
            
            %issue voltage trace to analogue-out channels of galvo
            obj.galvo.issueWaveform(galvoV);
            obj.laser.issueWaveform(laserV);
            
            %             obj.monitor.daqSession.DurationInSeconds = totalTime;
            %             [data,time] = obj.monitor.daqSession.startForeground;
            %             plot(time,data,'k-',time,laserV,'k:');
            
            obj.galvo.daqSession.wait;
            
            %             %Remove triggers
            obj.galvo.removeTrigger;
            obj.laser.removeTrigger;
            %             obj.monitor.removeTrigger;
            %             close(f);
            
        end
        
        function diode(obj)
            volts = round(linspace(1,5,8),1);
            figure('color','w');
            
            h = [];
            for v = 1:length(volts)
                h(v) = subplot(length(volts),1,v);
                obj.scanManual('onesite',[-3 0;3 0],0.1,volts(v));
                set(gca,'box','off');
                ylim([0 10]);
                ylabel(num2str(volts(v)));
                
                if v < length(volts)
                    set(gca,'xtick','','xcolor','w');
                end
            end
            
            linkaxes(h,'xy');
            xlabel('Time(sec)');
        end
        
        function registerListener(obj)
            %Connect to expServer, registering a callback function
            s = srv.StimulusControl.create('zym2');
            s.connect(true);
            anonListen = @(srcObj, eventObj) laserGalvoExpt_callback(eventObj, obj);
            addlistener(s, 'ExpUpdate', anonListen);
            obj.expServerObj = s;
        end
        
        function clearListener(obj)
            obj.expServerObj.disconnect;
            obj.expServerObj.delete;
        end
        
        function stop(obj)
            obj.laser.stop;
            obj.galvo.stop;
        end
        
        function saveLog(obj)
            log = obj.log;
            save(obj.filePath, 'log');
        end
        
        function ste = coordID2ste(obj,coordList,id)
            hemisphere = sign(id);
            ste = coordList(abs(id),:);
            
            if hemisphere == -1
                ste(1) = -ste(1);
            end
            
        end
        
        function delete(obj)
            %             obj.thorcam.delete;
            obj.galvo.delete;
            obj.laser.delete;
            try
                obj.expServerObj.delete;
            catch
            end
        end
        
    end
end