classdef laserGalvoExpt < handle
    %object which handles interfacing the galvo setup with MC
    
    properties
        rig;
        
        galvoCfg;
        laserCfg;
        thorcamCfg;

        thorcam;
        galvo;
        laser;
        monitor;
        
        expServerObj;
        galvoCoords;
        
        log;
        filepath;
        
        UDPService;
        AlyxInstance;
    end
    
    methods
        function obj = laserGalvoExpt(rig)
            obj.rig = rig;
            if nargin < 1
                error('Please enter rig name as first argument');
            end
            
            switch(rig)
                case 'zym2'
                    obj.galvoCfg = struct;
                    obj.galvoCfg.device = 'Dev1';
                    obj.galvoCfg.calibFile = 'C:\Users\Experiment\Documents\MATLAB\InactivationRig\calib\zym2_calib_POS-VOLT.mat';
                    
                    obj.laserCfg = struct;
                    obj.laserCfg.device = 'Dev2';
                    obj.laserCfg.channel = 'ao0';
                    obj.laserCfg.calibFile = 'C:\Users\Experiment\Documents\MATLAB\InactivationRig\calib\zym2_calib_VOLT-LPOWER.mat';
                    
                    obj.thorcamCfg = struct;
                    obj.thorcamCfg.camID = 1;
                    obj.thorcamCfg.exposure = 100;
                    obj.thorcamCfg.calibFile = 'C:\Users\Experiment\Documents\MATLAB\InactivationRig\calib\zym2_calib_PIX-POS.mat';
                    
                    UDPListenPort = 10002;
                case 'zym1'
                    obj.galvoCfg = struct;
                    obj.galvoCfg.device = 'Dev4';
                    obj.galvoCfg.calibFile = 'C:\Users\Experiment\Documents\MATLAB\InactivationRig\calib\zym1_calib_POS-VOLT.mat';
                    
                    obj.laserCfg = struct;
                    obj.laserCfg.device = 'Dev3';
                    obj.laserCfg.channel = 'ao0';
                    obj.laserCfg.calibFile = 'C:\Users\Experiment\Documents\MATLAB\InactivationRig\calib\zym1_calib_VOLT-LPOWER.mat';
                    
                    obj.thorcamCfg = struct;
                    obj.thorcamCfg.camID = 2;
                    obj.thorcamCfg.exposure = 10;
                    obj.thorcamCfg.calibFile = 'C:\Users\Experiment\Documents\MATLAB\InactivationRig\calib\zym1_calib_PIX-POS.mat';
          
                    UDPListenPort = 10001;
                otherwise
                    error('Invalid selection');
            end
            
            %Get camera object
            obj.thorcam = ThorCamController(obj.thorcamCfg);
            set(get(obj.thorcam.vidAx,'parent'),'name',obj.rig);
            
            %Get galvo controller object
            obj.galvo = GalvoController(obj.galvoCfg);
            
            %Get laser controller object
            obj.laser = LaserController(obj.laserCfg);
            
            %Setup monitor channels
%             obj.monitor = MonitorController(obj.monitorDevice);
            
            %Set equal rates
            obj.galvo.daqSession.Rate = 5e3;
            obj.laser.daqSession.Rate = 5e3;
            obj.monitor.daqSession.Rate = 5e3;
            
            %Create basicServices UDP listener to receive alyxInstance info
            %from expServer
            obj.UDPService = srv.BasicUDPService(rig);
            obj.UDPService.ListenPort = UDPListenPort;
            obj.UDPService.StartCallback = @obj.udpCallback;
            obj.UDPService.bind;
            
            disp('Please run stereotaxic calibration, then register listener');
        end
        
        function udpCallback(obj,src,evt)
            response = regexp(src.LastReceivedMessage,...
                '(?<status>[A-Z]{4})(?<body>.*)\*(?<host>\w*)', 'names');
            [~, obj.AlyxInstance] = dat.parseAlyxInstance(response.body);
        end
        
        function calibStereotaxic(obj)
            obj.thorcam.calibPIX2STE;
            load 26CoordSet;
            obj.thorcam.vidCustomCoords = coordSet;
        end
        
        function calibCameraWithMouse(obj)
                obj.galvo.calibPOS2VOLTAGEWithMouse(obj.thorcam, obj.laser);
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
                
                pause(1);
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
            
%             rate = obj.galvo.daqSession.Rate;
%             t = 0:(1/rate):totalTime; t(1)=[];
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
            obj.monitor.registerTrigger([obj.monitorDevice '/PFI0']);
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
            
                        obj.monitor.daqSession.DurationInSeconds = totalTime;
                        [data,time] = obj.monitor.daqSession.startForeground;
                        plot(1000*time,data,'k-',1000*time,laserV,'k:');
            
            obj.galvo.daqSession.wait;
            
            %             %Remove triggers
            obj.galvo.removeTrigger;
            obj.laser.removeTrigger;
            obj.monitor.removeTrigger;
            %             close(f);
            
        end
        
        function diode(obj,type)
            volts = round(linspace(3,5,3),1);
            figure('color','w');
            
            h = [];
            for v = 1:length(volts)
                h(v) = subplot(length(volts),1,v);
                
                switch(type)
                    case 'scan'
                        obj.scanManual('onesite',[-3 0;3 0],0.1,volts(v));
                    case 'laserOnly'
                        laserFreq = 20;
                        laserVolt = 5;
                        totalTime = 0.5;
                        
                        laserV = obj.laser.generateWaveform('square',laserFreq,laserVolt,totalTime);
                        
                        %Register the trigger for laser and monitor
                        obj.laser.registerTrigger([obj.laserDevice '/PFI0']);
                        obj.monitor.registerTrigger([obj.monitorDevice '/PFI0']);
                        disp('registered triggers');
                        
                        rate = obj.galvo.daqSession.Rate;
                        t = 0:(1/rate):totalTime; t(1)=[];

                        %issue voltage trace to analogue-out channels of galvo
                        obj.laser.issueWaveform(laserV);
                        
                        obj.monitor.daqSession.DurationInSeconds = totalTime;
                        [data,time] = obj.monitor.daqSession.startForeground;
                        plot(time*1000,data,'k-',time*1000,laserV,'k:');
                         obj.laser.daqSession.wait;                   
                        %             %Remove triggers
                        obj.laser.removeTrigger;
                        obj.monitor.removeTrigger;
                    case 'continuous'
                        numSamples = 1000;
                        data = nan(numSamples,1);
                        for i = 1:numSamples
                            data(i) = obj.monitor.daqSession.inputSingleScan;
                            pause(0.1);
                            plot(data);
                        end
                end
                set(gca,'box','off');
                %                 ylim([0 10]);
                ylabel(num2str(volts(v)));
                
                if v < length(volts)
                    set(gca,'xtick','','xcolor','w');
                end
            end
            
            linkaxes(h,'xy');
            xlabel('Time(msec)');
        end
        
        function registerListener(obj)
            %Connect to expServer, registering a callback function
            s = srv.StimulusControl.create(obj.rig);
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
        
        function appendToLog(obj,ROW)
            if isempty(obj.log)
                obj.log=ROW;
            else
                fields = fieldnames(obj.log);
                for f = 1:length(fields)
                    obj.log.(fields{f}) = [obj.log.(fields{f}); ROW.(fields{f})];
                end
            end
        end
        
        function saveLog(obj)
            log = obj.log;
            save(obj.filepath, '-struct', 'log');
            
            %If alyx instance available, register to database
            if isempty(obj.AlyxInstance)
                return;
            end
            
            subsessionURL = obj.AlyxInstance.subsessionURL;
            [dataset,filerecord] = alyx.registerFile2(obj.filepath, 'mat', subsessionURL, 'galvoLog', [], obj.AlyxInstance);
            keyboard;
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