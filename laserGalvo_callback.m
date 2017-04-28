function laserGalvo_callback(eventObj, LGObj)
%callback function run by expServer, called with inputs:
    %eventObj: from expServer containing various information about a trial
    %LGObj: laserGalvo object containing functions for laser/galvo 


%TODO:
%{
1) PIP: TTL pulse isn't being delivered at the start of the stimulus

2) ME: I should allow for different arrival times of variables

4) Figure out how to specify laser power

5) Allow for infinitely long galvo waveforms (currently manually set to
5sec but allows for earlier termination)
%}

if iscell(eventObj.Data) && strcmp(eventObj.Data{2}, 'experimentInit') %Experiment started
    disp('STARTED EXPERIMENT');

    %START LOG FILE
    
    %Register triggers
    LGObj.LED_daqSession.addTriggerConnection('external', 'Dev1/PFI1', 'StartTrigger');
    LGObj.galvo.daqSession.addTriggerConnection('external', 'Dev1/PFI0', 'StartTrigger');

    
elseif isstruct(eventObj.Data) && ~any(strcmp({eventObj.Data.name},'events.buildWaveform')) 
    %If any variables in the eventObj field, update them
    names = {eventObj.Data.name};
    values = {eventObj.Data.value};
    
    if isempty(LGObj.galvoCoords)
            LGObj.galvoCoords = values{strcmp(names,'events.galvoCoords')};
            LGObj.thorcam.vidCustomCoords = LGObj.galvoCoords; %Send down to thorcam object for plotting
    end
    
    if any(strcmp(names,'events.trialNum')==1)
        trialNum = values{strcmp(names,'events.trialNum')};
    end
    
    if any(strcmp(names,'events.laserType')==1)
        laserType = values{strcmp(names,'events.laserType')};
    end
    
%     if any(strcmp(names,'events.trialNum')==1)
%         trialNum = values{strcmp(names,'events.trialNum')};
%     end
    %Check for each variable
    
    %Think about what happens AFTER buildWaveform is issued, it shouldn't
    %unnecesarrily overwrite fields
    
elseif isstruct(eventObj.Data) && any(strcmp({eventObj.Data.name},'events.newTrial'))
    LGObj.stop;
    
    names = {eventObj.Data.name};
    values = {eventObj.Data.value};
    
    try
        if isempty(LGObj.galvoCoords)
            LGObj.galvoCoords = values{strcmp(names,'events.galvoCoords')};
            LGObj.thorcam.vidCustomCoords = LGObj.galvoCoords; %Send down to thorcam object for plotting
        end
        trialNum = values{strcmp(names,'events.trialNum')};
        laserType = values{strcmp(names,'events.laserType')}; % 1=off, 2=illuminate 1 site, 3=illuminate 2 sites
        galvoPos = values{strcmp(names,'events.galvoPos')}; %Coordinate (+ right hemisphere, - left hemisphere)
        galvoType = values{strcmp(names,'events.galvoType')}; %1 = single scan mode, 2 = multi scan mode
        laserPower = values{strcmp(names,'events.laserPower')};
    catch
        error('Some necessary signals werent in the events structure. Need to implement separate buildWaveform step');
    end
    
    disp('--');
    disp(['trialNum: ' num2str(trialNum)]);
    disp(['galvoType: ' num2str(galvoType)]);
    disp(['laserType: ' num2str(laserType)]);
    disp(['galvoPos: ' num2str(galvoPos)]);

    
    tic;
    %Setup waveforms depending on the trial configurations
    if galvoType == 1 %UNILATERAL SINGLE SCAN MODE
        disp('single scan mode');

        %Just place the galvo at the location now, and
        %then trigger the laser output by the TTL pulse
        %(if laser should be on)
        ste = LGObj.galvoCoords(abs(galvoPos),:);
        
        if sign(galvoPos) == 1 %RIGHT HEMISPHERE
            %do nothing
        elseif sign(galvoPos) == -1 %LEFT HEMISPHERE
            ste(1) = -ste(1); %flip ML axis coordinate
        end
        
        disp(['stereoTaxic: ' num2str(ste(1)) ' ' num2str(ste(2))]);
        
        pos = LGObj.thorcam.ste2pos(ste);
        volt = LGObj.galvo.pos2v(pos);
        LGObj.galvo.setV(volt);
        
        if laserType>1 %If laser ON
            %todo: specify laser power
            disp(['laser ON power=: ' num2str(laserPower)]);
            LGObj.LEDch.Frequency = 40;
            LGObj.LEDch.DutyCycle = 0.9;
            LGObj.LED_daqSession.startBackground; %<will wait for trigger from expServer
        end
                
    elseif galvoType == 2 % MULTI SCAN MODE
        %specify the galvo positions
        
        ste = LGObj.galvoCoords(abs(galvoPos),:);
        ste(1) = sign(galvoPos)*ste(1);
        %add the coordinate's mirror image
        ste = [ste; -ste(1), ste(2)];
        
        pos = LGObj.thorcam.ste2pos(ste);
        volt = LGObj.galvo.pos2v(pos);
        
        totalTime = 5;
        numDots = 2; %hard coded for now
        DAQ_Rate = LGObj.galvo.daqSession.Rate; %get back real rate
        t = [0:(1/DAQ_Rate):totalTime]; t(1)=[];
        waveX = nan(size(t));
        waveY = nan(size(t));
        
        %Define new LED frequency and duty cycle
        LGObj.LEDch.Frequency = 40*numDots;
        LGObj.LEDch.DutyCycle = 0.90;

        %preallocate waveforms [SQUARE WAVES]
        for d = 1:numDots
            idx = square(2*pi*LGObj.LEDch.Frequency*t/numDots - (d-1)*(2*pi)/numDots,100/numDots)==1;
            waveX(idx) = volt(d,1);
            waveY(idx) = volt(d,2);
        end
        V_IN = [waveX' waveY'];
        
        %Trim galvo waveform to ensure galvos move slightly earlier
        %compare to the LED waveform
        LED_dt = 1/LGObj.LEDch.Frequency;
        galvoDelay = 0.3/1000; %0.3ms delay required to move the galvos
        delay = 0.5*(1-LGObj.LEDch.DutyCycle)*LED_dt + galvoDelay;
        trimSamples = round(DAQ_Rate * delay);
        V_IN = circshift(V_IN,-trimSamples);
        
        %Issue galvo waveforms, will wait for a trigger later
        LGObj.galvo.issueWaveform(V_IN);
        
        disp(['galvo scan between: ' num2str(ste(1,1)) ',' num2str(ste(1,2)) ' & ' num2str(ste(2,1)) ',' num2str(ste(2,2))]);
        
        %Now setup LED waveforms as a pulse generator
        %if unilateral scan, overwrite with new duty cycle/frequency
        if laserType==2 %Laser on for ONE location (the first one in the list)
            LGObj.LEDch.Frequency = 40;
            LGObj.LEDch.DutyCycle = LGObj.LEDch.DutyCycle/numDots;
            disp('laser ON at 1st site');
        end
        
        
        
        %if laser trial, then queue that too
        if laserType > 1
            if laserType == 2
                disp(['laser ON at 1st site. power=' num2str(laserPower)]);
            elseif laserType == 3
                disp(['laser ON at both sites. power=' num2str(laserPower)]);

            end
            %todo: specify laser power
            LGObj.LED_daqSession.startBackground; %<will wait for trigger from expServer
        end
        
        %populate log fields here, get needed details from
        %eventObj
        %                     LGObj.log.trialNumber = eventObj.?
        %             LGObj.log.laser(LGObj.log.trialNumber) = laserON;
        %             LGObj.log.laserpos(LGObj.log.trialNumber) = newCoordIndex;
        
    end
    toc;
        
% elseif isstruct(eventObj.Data) && any(strcmp({eventObj.Data.name},'events.buildWaveform'))

    
elseif isstruct(eventObj.Data) && any(strcmp({eventObj.Data.name},'events.galvoAndLaserEnd'))
    disp('GALVO AND LASER OFF');
    LGObj.stop;
    
elseif isstruct(eventObj.Data) && any(strcmp({eventObj.Data.name},'events.endTrial'))
    LGObj.stop;
    
elseif iscell(eventObj.Data) && strcmp(eventObj.Data{2}, 'experimentEnded')
    LGObj.stop;
    
    %Remove triggers
    LGObj.LED_daqSession.removeConnection(1);
    LGObj.galvo.daqSession.removeConnection(1);
end

end
