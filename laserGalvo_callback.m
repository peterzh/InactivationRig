function laserGalvo_callback(eventObj, LGObj)
%callback function run by expServer, called with inputs:
    %eventObj: from expServer containing various information about a trial
    %LGObj: laserGalvo object containing functions for laser/galvo 

%General structure of the listener:
%If experiment starts: define log file, receive coordinate list

%If trial starts: depending on trial type, preallocate
%waveforms for galvo and LED to be triggered by a TTL pulse
%delivered from expServer. Save entry in log file

%If stimulus starts, then laser will have started, therefore
%wait 1.5seconds and terminate any waveforms occurring on
%galvo/LED

%If experiment ends, remove trigger connections, clean up etc



%VVVV Different field types for Pip's signals code
if iscell(eventObj.Data) && strcmp(eventObj.Data{2}, 'experimentInit')
    
elseif isstruct(eventObj.Data) && any(strcmp({eventObj.Data.name},'events.trialNum'))
    
end


%VVVV OLD CODE USED WITH NICKS CHOICEWORLD


if strcmp(eventObj.Data{1}, 'event')
    %if experiment just started
    if strcmp(eventObj.Data{2}, 'experimentInit')
        
        %setup some experiment details and log file location
        [LGObj.mouseName, LGObj.expDate, LGObj.expNum] = dat.parseExpRef(eventObj.Ref);
        p = dat.expPath(LGObj.mouseName, LGObj.expDate, LGObj.expNum, 'expInfo');
        LGObj.filePath = fullfile(p{1}, [eventObj.Ref '_laserManip.mat']);
        mkdir(p{1});
        
        %register triggers for the LED and galvos
        LGObj.LED_daqSession.addTriggerConnection('external', 'Dev2/PFI1', 'StartTrigger');
        LGObj.galvo.daqSession.addTriggerConnection('external', 'Dev2/PFI0', 'StartTrigger');
        
        %
        % if trial started, preload waveforms (laser on/off, galvo
        % positions, laser power)
    elseif strcmp(eventObj.Data{2}, 'trialStarted')
        laserON = binornd(1,LGObj.probLaser); %laser on: yes/no?
        newCoordIndex = randi(size(LGObj.coordList),1); %galvo position ID
        %laserPOWER = ? % get from expServer parameters
        
        
        %different behaviour depending on the experiment type
        switch(LGObj.mode)
            case 'unilateral_static'
                %Just place the galvo at the location now, and
                %then trigger the laser output by the TTL pulse
                %(if laser should be on)
                pos = LGObj.coordList(newCoordIndex,:);
                LGObj.galvo.setV(LGObj.galvo.pos2v(pos));
                
                if laserON==1
                    %todo: specify laser power
                    LGObj.LEDch.Frequency = 40;
                    LGObj.LEDch.DutyCycle = 0.9;
                    LGObj.LED_daqSession.startBackground; %<will wait for trigger from expServer
                end
                
            case {'bilateral_scan','unilateral_scan'}
                pos = LGObj.coordList(newCoordIndex,:);
                totalTime = 1.5;
                
                %add a 2nd point which is the contralateral partner
                pos = [pos; -pos(1) pos(2)];
                
                %Move galvos between all sites in POS
                v = LGObj.galvo.pos2v(pos);
                numDots = 2;
                
                LGObj.galvo.daqSession.Rate = 20e3;
                DAQ_Rate = LGObj.galvo.daqSession.Rate; %get back real rate
                
                t = [0:(1/DAQ_Rate):totalTime]; t(1)=[];
                
                waveX = nan(size(t));
                waveY = nan(size(t));
                
                LGObj.LEDch.Frequency = 40*numDots;
                LGObj.LEDch.DutyCycle = 0.90;
                
                for d = 1:numDots
                    idx = square(2*pi*LGObj.LEDch.Frequency*t/numDots - (d-1)*(2*pi)/numDots,100/numDots)==1;
                    waveX(idx) = v(d,1);
                    waveY(idx) = v(d,2);
                end
                
                V_IN = [waveX' waveY'];
                
                %Trim galvo waveform to ensure galvos move slightly earlier
                %compare to the LED waveform
                LED_dt = 1/LGObj.LEDch.Frequency;
                galvoDelay = 0.3/1000; %0.4ms delay required to move the galvos
                delay = 0.5*(1-LGObj.LEDch.DutyCycle)*LED_dt + galvoDelay;
                trimSamples = round(DAQ_Rate * delay);
                V_IN = circshift(V_IN,-trimSamples);
                
                %if unilateral scan, then only illuminate on
                %one cycle
                switch(LGObj.mode)
                    case 'unilateral_scan'
                        LGObj.LEDch.Frequency = 40;
                        LGObj.LEDch.DutyCycle = LGObj.LEDch.DutyCycle/numDots;
                end
                
                %Register the trigger for galvo and initiate
                %waveform wait period
                LGObj.galvo.issueWaveform(V_IN); %<will wait for trigger from expServer
                
                %if laser trial, then queue that too
                if laserON==1
                    %todo: specify laser power
                    LGObj.LED_daqSession.startBackground; %<will wait for trigger from expServer
                end
                
                %populate log fields here, get needed details from
                %eventObj
                %                     LGObj.log.trialNumber = eventObj.?
                LGObj.log.laser(LGObj.log.trialNumber) = laserON;
                LGObj.log.laserpos(LGObj.log.trialNumber) = newCoordIndex;
                
        end
        
        
        %turn off laser+galvo 1.5sec after visual stimulus
    elseif strcmp(eventObj.Data{2}, 'stimulusCueStarted')
        
        pause(1.5);
        LGObj.stop;
        
        %populate log fields here, get needed details from
        %eventObj
        LGObj.log.coordList = LGObj.coordList;
        LGObj.log.mode = LGObj.mode;
        
        LGObj.saveLog();
        
    elseif strcmp(eventObj.Data{2}, 'experimentEnded')
        %remove triggers (%might throw error if trigger was not
        %registered, e.g. when laserON==0);
        LGObj.LED_daqSession.removeConnection(1);
        LGObj.galvo.daqSession.removeConnection(1);
    end
    
end
end
