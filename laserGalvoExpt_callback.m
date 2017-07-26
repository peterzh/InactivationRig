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
<<<<<<< HEAD
<<<<<<< HEAD
    disp(['Starting Experiment: ' expRef]);
    %START LOG FILE
    LGObj.log = []; LGObj.filepath = [];
    LGObj.filepath = [dat.expPath(expRef, 'expInfo', 'm') '\' expRef '_galvoLog.mat'];
    
    LGObj.galvoCoords = [];
=======
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
    disp(['STARTED EXPERIMENT: ' expRef]);
    %START LOG FILE
    LGObj.log = []; LGObj.filepath = [];
    LGObj.filepath = [dat.expPath(expRef, 'expInfo', 'm') '\' expRef '_galvoLog.mat'];
<<<<<<< HEAD
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
    
    %Start galvo rates
    LGObj.galvo.daqSession.Rate = 10e3;
    LGObj.laser.daqSession.Rate = 10e3;
    
    %Register triggers
    LGObj.galvo.registerTrigger([LGObj.galvoDevice '/PFI0']);
    LGObj.laser.registerTrigger([LGObj.laserDevice '/PFI0']);

    %Reduce camera update rate to 1.5Hz
    LGObj.thorcam.setUpdateRate(1.5);
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
<<<<<<< HEAD
=======
    LGObj.stop;
<<<<<<< HEAD
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
    LGObj.thorcam.vidHighlight = [];
    
    tic;    
    allT = tic;
    
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
        laserDuration = values{strcmp(names,'events.laserDuration')};
        repeatNum = values{strcmp(names,'events.repeatNum')};
        if repeatNum >= 10
            LGObj.thorcam.vidColor = [0.9 0 0];
        elseif repeatNum >= 5
            LGObj.thorcam.vidColor = [1 1 0];
        else
            LGObj.thorcam.vidColor = [0 1 0];
        end
    catch me
        error('Problem loading trial information from eventObj');
    end
    
    ROW = struct;
    ROW.delay_readVar = toc;
<<<<<<< HEAD
<<<<<<< HEAD
    tic;
    
    fprintf(['%03d) '], trialNum);
=======
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
    
    disp('--');
    disp(['trialNum: ' num2str(trialNum)]);
%     disp(['galvoType: ' num2str(galvoType)]);
%     disp(['laserType: ' num2str(laserType)]);
%     disp(['galvoPos: ' num2str(galvoPos)]);

<<<<<<< HEAD
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
    stereotaxicCoords = LGObj.coordID2ste(LGObj.galvoCoords, galvoPos);
    
    %Setup waveforms depending on the trial configurations
    if galvoType == 1 %UNILATERAL SINGLE SCAN MODE

        %Just place the galvo at the location now, and
        %then trigger the laser output by the TTL pulse
        %(if laser should be on)

        pos = LGObj.thorcam.ste2pos(stereotaxicCoords);
        volt = LGObj.galvo.pos2v(pos);
        
        ROW.delay_getCoords = toc;
<<<<<<< HEAD
<<<<<<< HEAD
        tic;
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
        
        LGObj.galvo.moveNow(volt);
        
        ROW.delay_moveGalvo = toc;
<<<<<<< HEAD
<<<<<<< HEAD
        tic;
        
        ROW.delay_preallocLaserWaveform = NaN;
        ROW.delay_issueLaser = NaN;
        ROW.delay_vidHighlight = NaN;
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
        
        if laserType>0 %If laser ON
            laserFrequency = 40;
            laserVolt = laserPower;
<<<<<<< HEAD
            laserV = LGObj.laser.generateWaveform('truncatedCos',laserFrequency,laserVolt,laserDuration,[]);
            
            ROW.delay_preallocLaserWaveform = toc;
            tic;
            

            try
%                 disp(['laser ONSET DELAY: ' num2str(laserOnsetTime)]);
            catch
            end
            
%             disp(['    delay_preallocLaserWaveform: ' num2str(ROW.delay_preallocLaserWaveform)]);
            
            LGObj.laser.issueWaveform(laserV);
            fprintf(['<strong>%+0.1fML %+0.1fAP </strong>'], stereotaxicCoords(1), stereotaxicCoords(2));
            fprintf(['%0.1fv '], laserPower);
            fprintf('for %0.1fs',laserDuration);
            
            ROW.delay_issueLaser = toc;
            tic;
            
%             disp(['    delay_issueLaser: ' num2str(ROW.delay_issueLaser)]);
=======
            laserV = LGObj.laser.generateWaveform('truncatedCos',laserFrequency,laserVolt,10,[]);
            
            ROW.delay_preallocLaserWaveform = toc;
            
            disp(['laser ON voltage=: ' num2str(laserPower)]);
            LGObj.laser.issueWaveform(laserV);
            
            ROW.delay_issueLaser = toc;
<<<<<<< HEAD
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
            
            %Display coordinate on video feed
            LGObj.thorcam.vidHighlight = stereotaxicCoords;
            
            ROW.delay_vidHighlight = toc;
<<<<<<< HEAD
<<<<<<< HEAD
            tic;
            
%             disp(['    delay_vidHighlight: ' num2str(ROW.delay_vidHighlight)]);
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
        end
        
                
    elseif galvoType == 2 % MULTI SCAN MODE
        stereotaxicCoords = [stereotaxicCoords; -stereotaxicCoords(1), stereotaxicCoords(2)];
        pos = LGObj.thorcam.ste2pos(stereotaxicCoords);
        
<<<<<<< HEAD
        ROW.delay_getCoords = toc;
        tic;
        ROW.delay_moveGalvo = NaN;
        ROW.delay_preallocLaserWaveform = NaN;
        ROW.delay_issueLaser = NaN;
        ROW.delay_vidHighlight = NaN;
=======
        disp(['galvo scan Stereotaxic: ' num2str(stereotaxicCoords(1,1)) ',' num2str(stereotaxicCoords(1,2)) ' & ' num2str(stereotaxicCoords(2,1)) ',' num2str(stereotaxicCoords(2,2))]);

<<<<<<< HEAD
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
        if laserType> 0 %Laser on for ONE location (the first one in the list)
            laserVolt = laserPower;

            if laserType == 1
<<<<<<< HEAD
<<<<<<< HEAD
                fprintf(['<strong>%+0.1fML %+0.1fAP</strong> <-> %+0.1fML %+0.1fAP '], stereotaxicCoords(1,1), stereotaxicCoords(1,2), stereotaxicCoords(2,1), stereotaxicCoords(2,2));
                LGObj.scan('onesite',pos,laserDuration,laserVolt);
                ROW.delay_issueLaser = toc;
                tic;
                
            elseif laserType == 2
                fprintf(['<strong>%+0.1fML %+0.1fAP</strong> <-> <strong>%+0.1fML %+0.1fAP</strong> '], stereotaxicCoords(1,1), stereotaxicCoords(1,2), stereotaxicCoords(2,1), stereotaxicCoords(2,2));

                LGObj.scan('multisite',pos,laserDuration,laserVolt);
                ROW.delay_issueLaser = toc;
                tic;
=======
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
                disp(['laser ON at 1st site. volt=' num2str(laserPower)]);
                LGObj.scan('onesite',pos,5,laserVolt);
                
            elseif laserType == 2
                disp(['laser ON at both sites. volt=' num2str(laserPower)]);
                LGObj.scan('multisite',pos,5,laserVolt);
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
            end
            
            fprintf(['%0.1fv '], laserPower);
            fprintf('for %0.1fs',laserDuration);

            LGObj.thorcam.vidHighlight = stereotaxicCoords;
            ROW.delay_vidHighlight = toc;
            tic;
        else
            LGObj.scan('multisite',pos,laserDuration,0);
            fprintf(['%+0.1fML %+0.1fAP <-> %+0.1fML %+0.1fAP '], stereotaxicCoords(1,1), stereotaxicCoords(1,2), stereotaxicCoords(2,1), stereotaxicCoords(2,2));

        end

    
    end
<<<<<<< HEAD
    
    %Save these details to a log
=======
    toc;
    
    %Save these details to a log
%     ROW = struct;
<<<<<<< HEAD
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
    ROW.trialNum = trialNum;
    ROW.laserType = laserType;
    ROW.galvoPos = galvoPos;
    ROW.galvoType = galvoType;
    ROW.laserPower = laserPower;
<<<<<<< HEAD
<<<<<<< HEAD
    ROW.tictoc = toc(allT);
%     disp(['    total time: ' num2str(ROW.tictoc)]);
    LGObj.appendToLog(ROW);
    fprintf('\n');
% 
% elseif isstruct(eventObj.Data) && any(strcmp({eventObj.Data.name},'events.galvoAndLaserEnd'))
%     tic
%     LGObj.stop; %This can sometimes take a while
%     off_time = toc;
%     fprintf('OFF (%0.2fs)\n',off_time);
=======
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
    ROW.tictoc = toc;
    LGObj.appendToLog(ROW);

elseif isstruct(eventObj.Data) && any(strcmp({eventObj.Data.name},'events.galvoAndLaserEnd'))
    disp('GALVO AND LASER OFF');
    LGObj.stop;
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
    
elseif iscell(eventObj.Data) && strcmp(eventObj.Data{2}, 'experimentEnded')
    LGObj.stop;
    
    %Remove triggers
    LGObj.galvo.removeTrigger;
    LGObj.laser.removeTrigger;
    
    %Save log 
    LGObj.saveLog;
<<<<<<< HEAD
<<<<<<< HEAD
    
    %Return thorcam update rate to 2Hz
    LGObj.thorcam.setUpdateRate(2);
    LGObj.thorcam.vidColor = [1 0 0];
    
    fprintf('Experiment Ended.\n');
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
=======
>>>>>>> 1e44d8c63d3ce6453c296ddf30678fd5fe46fe70
end

end
