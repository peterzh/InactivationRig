classdef laserGalvo < handle
    %object which handles interfacing the galvo setup with MC
    
    properties
        thorcam;
        galvo;
        
        expServerObj;
        coordList;
    end
    
    methods
        function obj = laserGalvo
            
            %Get camera object
            obj.thorcam = ThorCam;
            
            %Get galvo controller object
            obj.galvo = GalvoController;
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
        
        function scan(obj,totalTime)
            %scan galvo between multiple points rapidly
            x = [-2:1:2];
            y = -x;
            pos = [x' y'];
            
            v = obj.galvo.pos2v(pos);
            numDots = size(pos,1);
            
            LED_freq = 40*numDots; %we want 40Hz laser at each location, therefore laser needs to output 40*n Hz if multiple sites
            
            DAQ_Rate = 20e3; %sample rate processed on the DAQ
            
            %galvo needs to place the laser at each location for the length
            %of the LED's single cycle.
            
            LED_dt = 1/LED_freq; %the amount of time taken for the LED to cycle once
            Rate_dt = 1/DAQ_Rate; %the amount of time taken for the DAQ to read one sample
            
            %the number of DAQ samples required to cover one LED cycle
            numSamples = round(LED_dt/Rate_dt); %which corresponds to the number of samples the galvo should position the laser at each site
            
            waveX = reshape(repmat(v(:,1),1,numSamples)',[],1);
            waveY = reshape(repmat(v(:,2),1,numSamples)',[],1);
            
            totalNumSamples = DAQ_Rate * totalTime;
            nCycles = round(totalNumSamples/length(waveX));
            
            V_IN = repmat([waveX, waveY],nCycles,1);
            
            %add 1 sample on the end to bring the laser back to zero
            V_IN = [V_IN; obj.galvo.pos2v([0 0])];
            
            %issue voltage trace to analogue-out channels
            obj.galvo.issueWaveform(V_IN,DAQ_Rate);
        end
        
        function registerListener(obj)
            %Connect to expServer, registering a callback function
            s = srv.StimulusControl.create(getExpServerName());
            s.connect(true);
            anonListen = @(srcObj, eventObj) obj.GalvoListener(eventObj, obj);
            addlistener(s, 'ExpUpdate', anonListen);
            obj.expServerObj = s;
        end
        
        function GalvoListener(eventObj, galvoObj)
            if strcmp(eventObj.Data{1}, 'event')
                
                %if stimulus started
                if strcmp(eventObj.Data{2}, 'stimulusCueStarted')
                    
                    %wait 1.5sec for laser to be on
                    pause(1.5);
                    
                    %after, move the galvo to the next location (ONLY
                    %UNILATERAL INACTIVATION)
                    numCoords = size(galvoObj.coordList, 1);
                    newCoordIndex = randi(numCoords,1);
                    v = galvoObj.pos2v(galvoObj.coordList(newCoordIndex,:));
                    
                    tic
                    galvoObj.setV(v)
                    toc
                end
                
            end
        end
        
        function delete(obj)
            obj.thorcam.delete;
            obj.galvo.delete;
        end
        
    end
end