function laserGalvoExpt_callback(eventObj, LGObj)
%callback function run by expServer, called with inputs:
    %eventObj: from expServer containing various information about a trial
    %LGObj: laserGalvo object containing functions for laser/galvo 


%TODO:
%{
1) PIP: TTL pulse to be delivered at start of stimulus

2) ME: I should allow for different arrival times of variables

4) Figure out how to specify laser power

5) Allow for infinitely long galvo waveforms (currently manually set to
5sec but allows for earlier termination)
%}

if iscell(eventObj.Data) && strcmp(eventObj.Data{2}, 'experimentInit') %Experiment started
    disp('STARTED EXPERIMENT');

    %START LOG FILE
    
    %Start galvo rates
    LGObj.galvo.daqSession.Rate = 20e3;
    LGObj.laser.daqSession.Rate = 20e3;
      
    %Register triggers
    LGObj.galvo.registerTrigger('Dev1/PFI0');
    LGObj.laser.registerTrigger('Dev1/PFI0');
%     
% elseif isstruct(eventObj.Data) && ~any(strcmp({eventObj.Data.name},'events.buildWaveform')) 
%     %If any variables in the eventObj field, update them
%     names = {eventObj.Data.name};
%     values = {eventObj.Data.value};
%     
%     if isempty(LGObj.galvoCoords)
%             LGObj.galvoCoords = values{strcmp(names,'events.galvoCoords')};
%             LGObj.thorcam.vidCustomCoords = LGObj.galvoCoords; %Send down to thorcam object for plotting
%     end
%     
%     if any(strcmp(names,'events.trialNum')==1)
%         trialNum = values{strcmp(names,'events.trialNum')};
%     end
%     
%     if any(strcmp(names,'events.laserType')==1)
%         laserType = values{strcmp(names,'events.laserType')};
%     end
%     
% %     if any(strcmp(names,'events.trialNum')==1)
% %         trialNum = values{strcmp(names,'events.trialNum')};
% %     end
%     %Check for each variable
%     
%     %Think about what happens AFTER buildWaveform is issued, it shouldn't
%     %unnecesarrily overwrite fields
    
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

    
    stereotaxicCoords = LGObj.coordID2ste(LGObj.galvoCoords, galvoPos);
    
    tic;
    
    %Setup waveforms depending on the trial configurations
    if galvoType == 1 %UNILATERAL SINGLE SCAN MODE
        disp('single scan mode');

        %Just place the galvo at the location now, and
        %then trigger the laser output by the TTL pulse
        %(if laser should be on)
        disp(['stereoTaxic: ' num2str(stereotaxicCoords(1)) ' ' num2str(stereotaxicCoords(2))]);
        
        pos = LGObj.thorcam.ste2pos(stereotaxicCoords);
        volt = LGObj.galvo.pos2v(pos);
        LGObj.galvo.moveNow(volt);
        
        if laserType>1 %If laser ON
            laserFrequency = 40;
            laserAmplitude = laserPower;
            laserV = LGObj.laser.generateWaveform('sine',laserFrequency,laserAmplitude,10);
                    
            disp(['laser ON voltage=: ' num2str(laserPower)]);
            LGObj.laser.issueWaveform(laserV);
        end
        
                
    elseif galvoType == 2 % MULTI SCAN MODE
        stereotaxicCoords = [stereotaxicCoords; -stereotaxicCoords(1), stereotaxicCoords(2)];
        pos = LGObj.thorcam.ste2pos(stereotaxicCoords);
        
        disp(['galvo scan between: ' num2str(stereotaxicCoords(1,1)) ',' num2str(stereotaxicCoords(1,2)) ' & ' num2str(stereotaxicCoords(2,1)) ',' num2str(stereotaxicCoords(2,2))]);

        if laserType> 1 %Laser on for ONE location (the first one in the list)
            laserAmplitude = laserPower;

            if laserType == 2
                disp(['laser ON at 1st site. power=' num2str(laserPower)]);
                LGObj.scan('onesite',pos,10,laserAmplitude);
                
            elseif laserType == 3
                disp(['laser ON at both sites. power=' num2str(laserPower)]);
                LGObj.scan('multisite',pos,10,laserAmplitude);
            end
        else
            LGObj.scan('multisite',pos,5,0);
        end

    
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
    LGObj.galvo.removeTrigger;
    LGObj.laser.removeTrigger;
end

end
