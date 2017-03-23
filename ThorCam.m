classdef ThorCam < handle
    properties
        camObj;
        ImageWidth;
        ImageHeight;
        ImageBits;
        MemID;
        isCapturing;
        pos2pix_transform;
        pix2pos_transform;
        
        vidAx;
        vidTimer;

    end
    
    methods
        function obj = ThorCam %Create and initialise camera
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
            
            %Set color mode to RGB 8bit
            obj.camObj.PixelFormat.Set(uc480.Defines.ColorMode.Mono8)
            
            %Allocate memory for camera image
            [~,obj.MemID] = obj.camObj.Memory.Allocate(true);
            
            %Extract image width/height/bits
            [~,obj.ImageWidth,obj.ImageHeight,obj.ImageBits,~] = obj.camObj.Memory.Inquire(obj.MemID);
        end
        
        function start(obj)
            obj.isCapturing = 1;
            %             obj.camObj.Acquisition.Capture(uc480.Defines.DeviceParameter.Wait);
            obj.camObj.Acquisition.Capture;
            
            [~,fps]=obj.camObj.Timing.Framerate.GetCurrentFps;
            [~,fpsrange]=obj.camObj.Timing.Framerate.GetFrameRateRange;
            disp(['frames per second: ' num2str(fps) '   min:' num2str(fpsrange.Minimum) ' max:' num2str(fpsrange.Maximum)]);
            
            
            [~,exposure]=obj.camObj.Timing.Exposure.Get;
            [~,exposurerange]=obj.camObj.Timing.Exposure.GetRange;
            disp(['exposure: ' num2str(exposure) '   min:' num2str(exposurerange.Minimum) ' max:' num2str(exposurerange.Maximum)]);
            
            
            %            %create timer object to keep updating the image in the
            %            %background
            figure('color','g');
            axes;
            obj.vidAx = gca;
            set(obj.vidAx,'xtick','','ytick','','box','off','xcolor','w','ycolor','w');
            
            obj.vidTimer = timer;
            obj.vidTimer.TimerFcn=@(tHandle,tEvents)(obj.timercallback);
            obj.vidTimer.Period = 0.4;
            obj.vidTimer.TasksToExecute = Inf;
            obj.vidTimer.ExecutionMode = 'fixedRate';
            start(obj.vidTimer);
            
        end
%         
        function stop(obj)
            obj.isCapturing = 0;
            stop(obj.vidTimer);
            obj.camObj.Acquisition.Stop;
        end
        
        function img = getFrame(obj)
            if obj.isCapturing == 0
                obj.start;
            end
%             obj.camObj.Acquisition.Freeze(uc480.Defines.DeviceParameter.Wait); 
            [~,tmp] = obj.camObj.Memory.CopyToArray(obj.MemID);
            img = reshape(tmp.uint8,obj.ImageWidth,obj.ImageHeight);
        end

        
        function setGain(obj,index)
            %index = 0-100;
            [~,factor] = obj.camObj.Gain.Hardware.ConvertScaledToFactor.Master(index);
            obj.camObj.Gain.Hardware.Factor.SetMaster(factor)
        end
        
        function setFps(obj,fps)
            obj.camObj.Timing.Framerate.Set(fps)
        end
        
        function setExposure(obj,exposure)
            obj.camObj.Timing.Exposure.Set(exposure)
        end
        
        function pos = getStimPos(obj) %locate position of dot 
            %TODO
            %image processing to find pixel position of peaks, and then use
            %calibrated transformations to get the position in real space
            
            %In the mean time just show image, and click on the location
            img = obj.getFrame;
            f=figure;
            ax = axes('Parent',f);
            image(img,'Parent',ax);
            title('Click on centre of dot');
            [pix_x,pix_y]=ginput(1); 
            
            pos = obj.pix2pos([pix_x pix_y]);
        end
        
        function obj = calib(obj)
            %Calib pixel position to real position, requires displaying a
            %grid
            
            [pos_y,pos_x] = meshgrid(-2:2:2);
            pos_x = pos_x(:);
            pos_y = pos_y(:);
            
            f=figure;
            ax = axes('Parent',f);
            img = obj.getFrame;
            image(img,'Parent',ax);
            hold on;
            
            pix_x = [];
            pix_y = [];
            for p = 1:length(pos_x);
                disp(['X=' num2str(pos_x(p)) '  Y=' num2str(pos_y(p))]);
                [pix_x(p,1),pix_y(p,1)]=ginput(1);
                plot(pix_x(p,1),pix_y(p,1),'ro');
                tx=text(pix_x(p,1)+10,pix_y(p,1),num2str(p));
                tx.Color = [1 0 0];
            end
                    
            %procrustes analysis to find mapping from pixel space to
            %real position
            [~,tPos,obj.pos2pix_transform] = procrustes([pix_x,pix_y],[pos_x,pos_y]);
            
            %overlay predicted position of real grid in the image
            plot(tPos(:,1),tPos(:,2),'gs');
            tx=text(tPos(:,1)+10,tPos(:,2),cellfun(@num2str,num2cell(1:length(pos_x)),'uniformoutput',0));
            set(tx,'Color',[0 1 0]);
                 
            [~,~,obj.pix2pos_transform] = procrustes([pos_x,pos_y],[pix_x,pix_y]);

            obj.pix2pos_transform.c = mean(obj.pix2pos_transform.c,1);
            obj.pos2pix_transform.c = mean(obj.pos2pix_transform.c,1);
            
        end
        
        function pos=pix2pos(obj,pix)
            %pix is [nx2]
            if isempty(obj.pix2pos_transform)
                error('need to calibrate');
            end
            pos = bsxfun(@plus,obj.pix2pos_transform.b * pix * obj.pix2pos_transform.T, obj.pix2pos_transform.c);
        end
        
        function pix=pos2pix(obj,pos)
            %pos is [nx2]
            if isempty(obj.pos2pix_transform)
                error('need to calibrate');
            end
            pix = bsxfun(@plus,obj.pos2pix_transform.b * pos * obj.pos2pix_transform.T, obj.pos2pix_transform.c);
        end
        
        function timercallback(obj)
            if obj.isCapturing == 1
                img = obj.getFrame;
                image(img,'Parent',obj.vidAx);
            end
        end
        
        function delete(obj)
            obj.camObj.Acquisition.Stop;
            obj.camObj.Exit;
        end
        
    end
end