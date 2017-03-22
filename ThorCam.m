classdef ThorCam < handle
    properties
        camObj;
        ImageWidth;
        ImageHeight;
        ImageBits;
        MemID;
        isCapturing=0;
        pos2pix_transform;
        pix2pos_transform;
    end
    
    methods
        function obj = ThorCam %Create and initialise camera
            %Add NET assembly
            %Need to install the .dll file to the Global Assembly Cache
            %util 'gacutil -i C:\Program Files\Thorlabs\Scientific
            %Imaging\DCx Camera Support\Develop\DotNet\signed\uc480DotNet.dll
            NET.addAssembly('uc480DotNet');
%             import uc480DotNet.*
%             
            %Create camera object
            obj.camObj = uc480.Camera;
            
            %Initialise object addressed with ID ( default 0)
            obj.camObj.Init(0); 
            
            %Set display mode
            obj.camObj.Display.Mode.Set(uc480.Defines.DisplayMode.Direct3D);
            
            %Set color mode to RGB 8bit
%             obj.camObj.PixelFormat.Set(uc480.Defines.ColorMode.RGBA8Packed);
            obj.camObj.PixelFormat.Set(uc480.Defines.ColorMode.Mono8);
            
            %Set camera trigger to software
%             obj.camObj.Trigger.Set(uc480.Defines.TriggerMode.Software);
            
            %Allocate memory for camera image
            [~,obj.MemID] = obj.camObj.Memory.Allocate(true);
            
            %Extract image width/height/bits
            [~,obj.ImageWidth,obj.ImageHeight,obj.ImageBits,~] = obj.camObj.Memory.Inquire(obj.MemID);
        end
        
        function obj = start(obj)
            obj.camObj.Acquisition.Capture;
            disp('Camera started');
            obj.isCapturing = 1;
        end
        
        function obj = stop(obj)
            obj.camObj.Acquisition.Stop;
            disp('Camera stopped');
            obj.isCapturing = 0;
        end
        
        function img = getFrame(obj)
            [~,tmp] = obj.camObj.Memory.CopyToArray(obj.MemID);
            img = reshape(tmp.uint8,obj.ImageWidth,obj.ImageHeight);
            img = fliplr(img');
        end
        
        function Continuous(obj)
            for i = 1:200
                obj.getFrame;
            end
        end
        
        function obj = setGain(obj)
            %TODO
        end
        
        function pos = getStimPos(obj) %locate position of dot 
            %TODO
            %image processing to find pixel position of peaks, and then use
            %calibrated transformations to get the position in real space
        end
        
        function obj = calib(obj)
            %Calib pixel position to real position, requires displaying a
            %grid
            
            [pos_y,pos_x] = meshgrid([-1 0 1]);
            pos_x = pos_x(:);
            pos_y = pos_y(:);
            
            if obj.isCapturing==0
                obj.start;
            end
            
            img = obj.getFrame;
            imshow(img); hold on;
                        
            pix_x = [];
            pix_y = [];
            for p = 1:length(pos_x);
                title(['X=' num2str(pos_x(p)) '  Y=' num2str(pos_y(p))]);
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
        
        function delete(obj)
            obj.camObj.Acquisition.Stop;
            obj.camObj.Exit;
        end
        
    end
end