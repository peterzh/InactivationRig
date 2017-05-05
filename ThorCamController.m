classdef ThorCamController < handle
    properties
        camObj;
        ImageWidth;
        ImageHeight;
        ImageBits;
        MemID;
        isCapturing=0;
        
        %calibration between pixel identity and real position
        pos2pix_transform;
        pix2pos_transform;
        
        %calibration between real position and stereotaxic coords
        pos2ste_transform;
        ste2pos_transform;
        
        %misc items related to live video feed 
        vidAx;
        vidTimer;
        vidCustomCoords;
    end
    
    methods
        function obj = ThorCamController %Create and initialise camera
            %Add NET assembly
            
            %Need to install the .dll file to the Global Assembly Cache
            %util 'gacutil -i C:\Program Files\Thorlabs\Scientific
            %Imaging\DCx Camera Support\Develop\DotNet\signed\uc480DotNet.dll
            %             NET.addAssembly('uc480DotNet');
            NET.addAssembly('C:\Program Files\Thorlabs\Scientific Imaging\DCx Camera Support\Develop\DotNet\uc480DotNet.dll');
            %             import uc480DotNet.*
            %
            
            obj.camObj = uc480.Camera;
            
            %Initialise object addressed with ID ( default 0)
            obj.camObj.Init(0)
            
            %Set display mode
            obj.camObj.Display.Mode.Set(uc480.Defines.DisplayMode.Direct3D)
            obj.camObj.Display.Mode.Set(uc480.Defines.DisplayMode.Mono)
            
            %Set color mode to Mono 8bit
            obj.camObj.PixelFormat.Set(uc480.Defines.ColorMode.Mono8)
            
            %Allocate memory for camera image
            [~,obj.MemID] = obj.camObj.Memory.Allocate(true);
            
            %Extract image width/height/bits
            [~,obj.ImageWidth,obj.ImageHeight,obj.ImageBits,~] = obj.camObj.Memory.Inquire(obj.MemID);
            
            %video feed
            obj.videoFigure;
            obj.start;
            
            %try loading pix2pos calibration
            try
                obj.loadcalibPIX2POS; 
                disp('Loaded pixel<->position calibration');
            catch
                disp('did not load pix2pos calibration');
            end
        end
        
        function videoFigure(obj)
            %Create figure for live video feed
            obj.isCapturing = 0;
            figure;
            axes; colormap(gray);
            obj.vidAx = gca;
            obj.vidTimer = timer;
            obj.vidTimer.TimerFcn=@(tHandle,tEvents)(obj.timercallback);
            obj.vidTimer.Period = 0.2;
            obj.vidTimer.TasksToExecute = Inf;
            obj.vidTimer.ExecutionMode = 'fixedRate';
            start(obj.vidTimer);
        end
        
        function start(obj)
            obj.isCapturing = 1;
            %             obj.camObj.Acquisition.Capture(uc480.Defines.DeviceParameter.Wait);
            obj.camObj.Acquisition.Capture;
            
            [~,fps]=obj.camObj.Timing.Framerate.GetCurrentFps;
            [~,fpsrange]=obj.camObj.Timing.Framerate.GetFrameRateRange;
            disp(['camera framerate: ' num2str(fps) '   min:' num2str(fpsrange.Minimum) ' max:' num2str(fpsrange.Maximum)]);
            
            [~,exposure]=obj.camObj.Timing.Exposure.Get;
            [~,exposurerange]=obj.camObj.Timing.Exposure.GetRange;
            disp(['exposure: ' num2str(exposure) '   min:' num2str(exposurerange.Minimum) ' max:' num2str(exposurerange.Maximum)]);
        end
%         
        function stop(obj)
            obj.isCapturing = 0;
            obj.camObj.Acquisition.Stop;
        end
        
        function img = getFrame(obj)
%             obj.camObj.Acquisition.Freeze(uc480.Defines.DeviceParameter.Wait); 
            [~,tmp] = obj.camObj.Memory.CopyToArray(obj.MemID);
            img = reshape(tmp.uint8,obj.ImageWidth,obj.ImageHeight);
        end

        function setGain(obj,index)
            %index = 0-100;
            [~,factor] = obj.camObj.Gain.Hardware.ConvertScaledToFactor.Master(index);
            obj.camObj.Gain.Hardware.Factor.SetMaster(factor)
        end
        
        function ga = getGain(obj)
            [~,ga]=obj.camObj.Gain.Hardware.Factor.GetMaster;
        end
        
        function setUpdateRate(obj,fps)
            %Hack by using different timer periods
            period = 1/fps;
            stop(obj.vidTimer);
            obj.vidTimer.Period = period;
            start(obj.vidTimer);
        end
        
        function setExposure(obj,exposure)
            obj.camObj.Timing.Exposure.Set(exposure)
        end
        
        function ex = getExposure(obj)
            [~,ex]=obj.camObj.Timing.Exposure.Get;
        end
        
        function pos = getStimPos(obj,mode) %locate position of dot 
            img = obj.getFrame;
            pix=nan(1,2); 
            
            switch(mode)
                case 'manual'
                    f=figure;
                    ax = axes('Parent',f); axis equal;
                    image(img,'Parent',ax);
                    title('Select position');
                    [pix(1),pix(2)]=ginput(1);
                    close(f);

                case 'auto'
                    %auto detect ONE bright peak
                    s = regionprops(img>240,'centroid');
                    f=figure; imshow(img); hold on;
                    plot(s(end).Centroid(1),s(end).Centroid(2),'r+');
                    hold off;
                    
                    pix=[s(end).Centroid(1),s(end).Centroid(2)];
                    
%                     SmImg = imgaussfilt(img,20);
%                     [~,pix(1)]=max(mean(SmImg,1));
%                     [~,pix(2)]=max(mean(SmImg,2));
%                     
%                     f=figure;
%                     ax = axes('Parent',f); axis equal;
%                     image(img,'Parent',ax); hold on;
%                     h=plot(pix(1),pix(2),'ro'); h.MarkerSize=10;
%                     
                    %allow user to manually correct the calibration
                    pause(2);
                    key = get(f,'CurrentKey');
                    if ~strcmp(key,'0')
                        [pix(1),pix(2)]=ginput(1);
                    end
                    
                    close(f);
            end
            pos = obj.pix2pos(pix);
        end
        
        function calibPIX2POS(obj)
            %Calib pixel position to real position, requires displaying a
            %grid. This can be done only once, and calibration saved. As
            %long as the setup isn't modified physically
            
            %create grid of points in REAL space
            [pos_y,pos_x] = meshgrid(-2:2:2);
            pos_x = pos_x(:);
            pos_y = pos_y(:);
            
            %create figure and plot camera image
            f=figure;
            ax = axes('Parent',f);
            img = obj.getFrame;
            image(img,'Parent',ax); axis equal;
            hold on;
            
            %Go through each point in REAL SPACE, and define the
            %associated point in PIXEL SPACE manually
            pix_x = [];
            pix_y = [];
            for p = 1:length(pos_x);
                disp(['X=' num2str(pos_x(p)) '  Y=' num2str(pos_y(p))]);
                [pix_x(p,1),pix_y(p,1)]=ginput(1);
                plot(pix_x(p,1),pix_y(p,1),'ro');
                tx=text(pix_x(p,1)+10,pix_y(p,1),num2str(p));
                tx.Color = [1 0 0];
            end
                    
            %procrustes analysis to find mapping from real space to pixel space 
            [~,tPos,obj.pos2pix_transform] = procrustes([pix_x,pix_y],[pos_x,pos_y]);
            
            %overlay predicted pixel-space positions of real-space grid 
            plot(tPos(:,1),tPos(:,2),'gs');
            tx=text(tPos(:,1)+10,tPos(:,2),cellfun(@num2str,num2cell(1:length(pos_x)),'uniformoutput',0));
            set(tx,'Color',[0 1 0]);
                 
            %procrustes analysis to find mapping from pixel space to real space 
            [~,~,obj.pix2pos_transform] = procrustes([pos_x,pos_y],[pix_x,pix_y]);

            %collapsing the offset (c) transform because for some reason
            %the procrustes function outputs repeat values for the offset
            obj.pix2pos_transform.c = mean(obj.pix2pos_transform.c,1);
            obj.pos2pix_transform.c = mean(obj.pos2pix_transform.c,1);
            
            pix2pos_transform=obj.pix2pos_transform;
            pos2pix_transform=obj.pos2pix_transform;

            mfiledir = fileparts(mfilename('fullpath'));
            filename = fullfile(mfiledir,'calib','calib_PIX-POS.mat');
            save(filename,'pix2pos_transform','pos2pix_transform');
            
        end
        
        function loadcalibPIX2POS(obj)
            mfiledir = fileparts(mfilename('fullpath'));
            filename = fullfile(mfiledir,'calib','calib_PIX-POS.mat');
            t = load(filename);
            
            obj.pix2pos_transform = t.pix2pos_transform;
            obj.pos2pix_transform = t.pos2pix_transform;
        end
        
        function calibPIX2STE(obj)
            %Calibrate pixel position to stereotaxic coords. Need to do
            %this everytime you headfix
            
            %get 'real pos' of bregma and lambda, requires PIX2POS calib
            %already
            if isempty(obj.pix2pos_transform)
                error('Need to do pix2pos calibration')
            end
            disp('SELECT BREGMA');
            bregmaPos = obj.getStimPos('manual');
            
            disp('SELECT LAMBDA');
            lambdaPos = obj.getStimPos('manual');
            
            %define norm vector pointing along the midline
            delta = bregmaPos-lambdaPos; 
            delta = delta/norm(delta);
%             
%             [~, ~, obj.pos2ste_transform] = procrustes([0 0; 0 -1], [bregmaPos; bregmaPos-delta],'Scaling',false,'Reflection',false);
%             [~, ~, obj.ste2pos_transform] = procrustes([bregmaPos-delta; delta],[0 0; 0 -1],'Scaling',false,'Reflection',false);
%             obj.pos2ste_transform.c = mean(obj.pos2ste_transform.c,1);
%             obj.ste2pos_transform.c = mean(obj.ste2pos_transform.c,1);
            
            %compute UNSIGNED angle of the midline vector compared to the Y axis
            angle_to_Yaxis = acos( dot(delta,[0 1])/norm(delta) );
            
            %Since angle is unsigned, need to define whether this vector is
            %rotated clockwise or anticlockwise relative to Y axis
            obj.pos2ste_transform.offset = -bregmaPos; 
            obj.ste2pos_transform.offset = bregmaPos;
            if delta(1) > 0
                %clockwise relative to Y axis
                
                %rotation matrix to transform stereotaxic to real position
                obj.ste2pos_transform.rotation = [cos(2*pi - angle_to_Yaxis) -sin(2*pi - angle_to_Yaxis);
                                          sin(2*pi - angle_to_Yaxis) cos(2*pi - angle_to_Yaxis)];
                %rotation matrix to transform real to ste position                      
                obj.pos2ste_transform.rotation = [cos(angle_to_Yaxis) -sin(angle_to_Yaxis);
                                          sin(angle_to_Yaxis) cos(angle_to_Yaxis)];
                
            else
                %anticlockwise relative to Y axis
                obj.ste2pos_transform.rotation = [cos(angle_to_Yaxis) -sin(angle_to_Yaxis);
                                          sin(angle_to_Yaxis) cos(angle_to_Yaxis)];
                                      
                obj.pos2ste_transform.rotation = [cos(2*pi - angle_to_Yaxis) -sin(2*pi - angle_to_Yaxis);
                                          sin(2*pi - angle_to_Yaxis) cos(2*pi - angle_to_Yaxis)];
            end
            
            
            %plot REAL SPACE grid
            img = obj.getFrame;
            f=figure;
            image(img); hold on; axis equal;
            
            dots = -2:0.5:2;
            [x,y] = meshgrid(dots); x=x(:); y=y(:);
            pix = obj.pos2pix([x y]);
            plot(pix(:,1),pix(:,2),'ko');
          
            %plot STEREOTAXIC grid in REAL SPACE
            pos = obj.ste2pos([x,y]);
            pix = obj.pos2pix(pos);
            plot(pix(:,1),pix(:,2),'go');
            
        end
        
        function pos=pix2pos(obj,pix)
            %pix is [nx2]
            if isempty(obj.pix2pos_transform)
                error('need to calibrate pixel to real space');
            end
            pos = bsxfun(@plus,obj.pix2pos_transform.b * pix * obj.pix2pos_transform.T, obj.pix2pos_transform.c);
        end
        
        function pix=pos2pix(obj,pos)
            %pos is [nx2]
            if isempty(obj.pos2pix_transform)
                error('need to calibrate pixel to real space');
            end
            pix = bsxfun(@plus,obj.pos2pix_transform.b * pos * obj.pos2pix_transform.T, obj.pos2pix_transform.c);
        end
        
        function pos=ste2pos(obj,ste)
            %ste is [nx2]
            if isempty(obj.ste2pos_transform)
                error('need to calibrate real space to stereotaxic coords');
            end
            
            pos = bsxfun(@plus,ste*obj.ste2pos_transform.rotation',obj.ste2pos_transform.offset);
        end
        
        function ste=pos2ste(obj,pos)
            %pos is [nx2]
            if isempty(obj.pos2ste_transform)
                error('need to calibrate real space to stereotaxic coords');
            end
            
            ste = bsxfun(@plus,pos*obj.pos2ste_transform.rotation',obj.pos2ste_transform.offset);
        end
        
        function timercallback(obj)
            img = obj.getFrame;
            image(img,'Parent',obj.vidAx);
            set(obj.vidAx,'XLimMode','manual','YLimMode','manual','DataAspectRatio',[1 1 1],'PlotBoxAspectRatio',[3 4 4]);
            if obj.isCapturing == 1
                set(get(obj.vidAx,'parent'),'color','g');
                title(obj.vidAx,{['update rate: ' num2str(1/obj.vidTimer.AveragePeriod)],...
                                 ['gain: ' num2str(obj.getGain)],...
                                 ['exposure: ' num2str(obj.getExposure)]});
            else
                set(get(obj.vidAx,'parent'),'color','r')
            end
            
%             %if pix2pos calibration done, overlay real position grid
            if ~isempty(obj.pos2pix_transform)
                pos = -4:1:4;
                [x,y]=meshgrid(pos);
                pix = obj.pos2pix([x(:) y(:)]);
%                 hold on;
%                 plot(pix(:,1),pix(:,2),'w+');
%                 hold off;
                
                pix_x = pix(:,1); pix_y = pix(:,2);
                pix_x = reshape(pix_x,length(pos),length(pos));
                pix_y = reshape(pix_y,length(pos),length(pos));
                hold(obj.vidAx,'on');
                plot(obj.vidAx,pix_x,pix_y,'ko:');
                plot(obj.vidAx,pix_x',pix_y','ko:');
                h=plot(obj.vidAx,pix(ceil(end/2),1),pix(ceil(end/2),2),'ko'); set(h,'MarkerSize',20);
                hold(obj.vidAx,'off');
            end
          
            %if ste2pos calibration done, overlay stereotaxic grid
            if ~isempty(obj.ste2pos_transform) && isempty(obj.vidCustomCoords)
                ste = -2:1:2;
                [x,y]=meshgrid(ste);
                pos = obj.ste2pos([x(:) y(:)]);
                pix = obj.pos2pix(pos);
                
                pix_x = pix(:,1); pix_y = pix(:,2);
                pix_x = reshape(pix_x,length(ste),length(ste));
                pix_y = reshape(pix_y,length(ste),length(ste));
                hold(obj.vidAx,'on');
                plot(obj.vidAx,pix_x,pix_y,'bo-');
                plot(obj.vidAx,pix_x',pix_y','bo-');
                h=plot(obj.vidAx,pix(ceil(end/2),1),pix(ceil(end/2),2),'bo'); set(h,'MarkerSize',20);
                hold(obj.vidAx,'off');
            elseif ~isempty(obj.ste2pos_transform) && ~isempty(obj.vidCustomCoords)
                ste = obj.vidCustomCoords;
                ste = [ste; -ste(:,1) ste(:,2)];
                pos = obj.ste2pos(ste);
                pix = obj.pos2pix(pos);

                pix_x = pix(:,1); pix_y = pix(:,2);
%                 pix_x = reshape(pix_x,size(obj.vidCustomCoords,1),size(obj.vidCustomCoords,1));
%                 pix_y = reshape(pix_y,size(obj.vidCustomCoords,1),size(obj.vidCustomCoords,1));
                hold(obj.vidAx,'on');
                plot(obj.vidAx,pix_x,pix_y,'bo');
                plot(obj.vidAx,pix_x',pix_y','bo');
                hold(obj.vidAx,'off');
            end
            
        end
        
        function delete(obj)
            stop(obj.vidTimer);
            obj.stop;
            obj.camObj.Exit;
        end
        
    end
end