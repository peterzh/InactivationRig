function laserGalvoExpt_callback(eventObj, LGObj)
%callback function run by expServer, called with inputs:
    %eventObj: from expServer containing various information about a trial
    %LGObj: laserGalvo object containing functions for laser/galvo 


%TODO:
%{
2) ME: I should allow for different arrival times of variables

4) Figure out how to specify laser power

5) Allow for infinitely long galvo waveforms (currently manually set to
5sec but allows for earlier termination)
%}

if iscell(eventObj.Data) && strcmp(eventObj.Data{2}, 'experimentInit') %Experiment started
    expRef = eventObj.Ref;
    disp(['STARTED EXPERIMENT: ' expRef]);
    %START LOG FILE
    LGObj.log = []; LGObj.filepath = [];
    LGObj.filepath = [dat.expPath(expRef, 'expInfo', 'm') '\' expRef '_galvoLog.mat'];
    
    %Start galvo rates
    LGObj.galvo.daqSession.Rate = 30e3;
    LGObj.laser.daqSession.Rate = 30e3;
    
    %Register triggers
    LGObj.galvo.registerTrigger([LGObj.galvoDevice '/PFI0']);
    LGObj.laser.registerTrigger([LGObj.laserDevice '/PFI0']);

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
    LGObj.thorcam.vidHighlight = [];
    
    tic;
    
    names = {eventObj.Data.name};
    values = {eventObj.Data.value};
    
    try
        if isempty(LGObj.galvoCoords)
            LGObj.galvoCoords = values{strcmp(names,'events.galvoCoords')};
            LGObj.thorcam.vidCustomCoords = LGObj.galvoCoords; %Send down to thorcam object for plotting
        end
        trialNum = values{strcmp(names,'events.trialNum')};
        laserType = values{strcmp(names,'events.laserType')}; % 0=off, 1=illuminate 1 site, 2=illuminate 2 sites
        galvoPos = values{strcmp(names,'events.galvoPos')}; %Coordinate (+ right hemisphere, - left hemisphere)
        galvoType = values{strcmp(names,'events.galvoType')}; %1 = single scan mode, 2 = multi scan mode
        laserPower = values{strcmp(names,'events.laserPower')};
    catch
        error('Some necessary signals werent in the events structure. Need to implement separate buildWaveform step');
    end
    
    ROW = struct;
    ROW.delay_readVar = toc;
    
    disp('--');
    disp(['trialNum: ' num2str(trialNum)]);
%     disp(['galvoType: ' num2str(galvoType)]);
%     disp(['laserType: ' num2str(laserType)]);
%     disp(['galvoPos: ' num2str(galvoPos)]);

    stereotaxicCoords = LGObj.coordID2ste(LGObj.galvoCoords, galvoPos);
%     hemisphere = sign(galvoPos);
%     ste = LGObj.galvoCoords(abs(galvoPos),:);
%     
%     if hemisphere == -1
%         ste(1) = -ste(1);
%     end
%     stereotaxicCoords = ste;
    
    %Setup waveforms depending on the trial configurations
    if galvoType == 1 %UNILATERAL SINGLE SCAN MODE
%         disp('single scan mode');

        %Just place the galvo at the location now, and
        %then trigger the laser output by the TTL pulse
        %(if laser should be on)
        disp(['stereoTaxic: ' num2str(stereotaxicCoords(1)) ' ' num2str(stereotaxicCoords(2))]);
        
        pos = LGObj.thorcam.ste2pos(stereotaxicCoords);
        volt = LGObj.galvo.pos2v(pos);
        
        ROW.delay_getCoords = toc;
        
        LGObj.galvo.moveNow(volt);
        
        ROW.delay_moveGalvo = toc;
        
        if laserType>0 %If laser ON
            laserFrequency = 40;
            laserVolt = laserPower;
            laserV = LGObj.laser.generateWaveform('truncatedCos',laserFrequency,laserVolt,10,[]);
            
            ROW.delay_preallocLaserWaveform = toc;
            
            disp(['laser ON voltage=: ' num2str(laserPower)]);
            LGObj.laser.issueWaveform(laserV);
            
            ROW.delay_issueLaser = toc;
            
            %Display coordinate on video feed
            LGObj.thorcam.vidHighlight = stereotaxicCoords;
            
            ROW.delay_vidHighlight = toc;
        end
        
                
    elseif galvoType == 2 % MULTI SCAN MODE
        stereotaxicCoords = [stereotaxicCoords; -stereotaxicCoords(1), stereotaxicCoords(2)];
        pos = LGObj.thorcam.ste2pos(stereotaxicCoords);
        
        disp(['galvo scan Stereotaxic: ' num2str(stereotaxicCoords(1,1)) ',' num2str(stereotaxicCoords(1,2)) ' & ' num2str(stereotaxicCoords(2,1)) ',' num2str(stereotaxicCoords(2,2))]);

        if laserType> 0 %Laser on for ONE location (the first one in the list)
            laserVolt = laserPower;

            if laserType == 1
                disp(['laser ON at 1st site. volt=' num2str(laserPower)]);
                LGObj.scan('onesite',pos,5,laserVolt);
                
            elseif laserType == 2
                disp(['laser ON at both sites. volt=' num2str(laserPower)]);
                LGObj.scan('multisite',pos,5,laserVolt);
            end
        else
            LGObj.scan('multisite',pos,5,0);
        end

    
    end
    toc;
    
    %Save these details to a log
%     ROW = struct;
    ROW.trialNum = trialNum;
    ROW.laserType = laserType;
    ROW.galvoPos = galvoPos;
    ROW.galvoType = galvoType;
    ROW.laserPower = laserPower;
    ROW.tictoc = toc;
    LGObj.appendToLog(ROW);

elseif isstruct(eventObj.Data) && any(strcmp({eventObj.Data.name},'events.galvoAndLaserEnd'))
    disp('GALVO AND LASER OFF');
    LGObj.stop;
    
elseif iscell(eventObj.Data) && strcmp(eventObj.Data{2}, 'experimentEnded')
    LGObj.stop;
    
    %Remove triggers
    LGObj.galvo.removeTrigger;
    LGObj.laser.removeTrigger;
    
    %Save log 
    LGObj.saveLog;
end

end
