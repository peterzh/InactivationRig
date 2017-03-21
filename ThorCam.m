classdef ThorCam < handle
    properties
        camObj;
        ImageWidth;
        ImageHeight;
        ImageBits;
        MemID;
        isCapturing=0;
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
            imshow(img); set(gca,'ydir','normal');
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
        end
        
        function delete(obj)
            obj.camObj.Acquisition.Stop;
            obj.camObj.Exit;
        end
        
    end
end