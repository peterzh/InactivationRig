classdef laserGalvoExpt < handle
    %object which handles interfacing the galvo setup with MC
    
    properties
        galvoDevice='Dev1';
        laserDevice='Dev2';
        
        thorcam;
        galvo;
        laser;
                
        expServerObj;
        galvoCoords;
        
        %TO BE REMOVED
%         LED_daqSession;
%         LEDch;
%         monitor_daqSession;
%         monitor_led;
%         monitor_gx;
%         monitor_gy;
%         
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
            
            %Set equal rates
            obj.galvo.daqSession.Rate = 20e3;
            obj.laser.daqSession.Rate = 20e3;
            
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
            
            numDots = size(pos,1);
            laserFreqAtEachSite = 40;
            
            switch(mode)
                case 'multisite' %Illuminate each location
                    laserFreq = laserFreqAtEachSite*numDots;
                    laserV = obj.laser.generateWaveform('trunacedSin',laserFreq,laserAmplitude,totalTime);

                case 'onesite'
                    laserFreq = laserFreqAtEachSite;
                    pos = pos(1,:); %Get first position
                    pos = [pos; -pos(1) pos(2)]; %add 2nd position at the mirror location
                    laserV = obj.laser.generateWaveform('sinHalf',laserFreq,laserAmplitude,totalTime);
                case 'multisite_laseroff'
                    laserV = 0;
            end
            
            v = obj.galvo.pos2v(pos);
            galvoFreq = laserFreqAtEachSite*numDots;
            galvoV = obj.galvo.generateWaveform(galvoFreq,v,totalTime);

            %Register the trigger for galvo and LEDs to start together
            obj.galvo.registerTrigger('Dev1/PFI0');
            obj.laser.registerTrigger('Dev2/PFI0');
            
            %shift galvo waveform to ensure galvos move slightly earlier
            %compare to the LED waveform because galvo has a delay to
            %action
            galvo_laser_delay = 1e-3; %Delay between laser UP state and galvo movement
            numEle = obj.galvo.Rate*galvo_laser_delay;
            galvoV = circshift(galvoV,numEle);

            %issue voltage trace to analogue-out channels of galvo
            obj.galvo.issueWaveform(galvoV);
            obj.laser.issueWaveform(laserV);
            
            obj.laser.daqSession.wait();
            obj.stop;
            
            %Remove triggers
            obj.galvo.removeTrigger;
            obj.laser.removeTrigger;
            
        end
        
        function registerListener(obj)
            %Connect to expServer, registering a callback function
            s = srv.StimulusControl.create('zym2');
            s.connect(true);
            anonListen = @(srcObj, eventObj) laserGalvoExpt_callback(eventObj, obj);
            addlistener(s, 'ExpUpdate', anonListen);
            obj.expServerObj = s;
        end
        
        function stop(obj)
            obj.laser.stop;
            obj.galvo.stop;
            
            %issue TTL force stop to laser
        end
        
        function saveLog(obj)
            log = obj.log;
            save(obj.filePath, 'log');
        end
        
        function ste = coordID2ste(coordList,id)
            hemisphere = sign(id);
            ste = coordList(abs(id),:);
            
            if hemisphere == -1
                ste(1) = -ste(1);
            end
            
        end
        
        function delete(obj)
            obj.thorcam.delete;
            obj.galvo.delete;
            obj.laser.delete;
            obj.expServerObj.delete;
        end
        
    end
end