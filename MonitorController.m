classdef MonitorController < handle
    %Code which handles a laser output, connected to AO0 channel on a NIDAQ
    %board. 
    properties
        device;
        daqSession;
        AI;
        data_listener;
    end
    
    methods
        function obj = MonitorController(device)
            obj.device = device;
            obj.daqSession = daq.createSession('ni');
            try
                obj.AI = obj.daqSession.addAnalogInputChannel(device, 'ai13', 'Voltage');
            catch
                warning(['MonitorController failed to initialise on ' device])
            end

        end
        
        function acquire(obj)
%             obj.daqSession.DurationInSeconds = 10;
%             data = obj.daqSession.startForeground;
            figure;
            axis; hold on;
            
            i = 1;
            while 1 == 1
                for j=1:10
                    data(j) = obj.daqSession.inputSingleScan;
                    pause(0.001)
                end
                plot(i,mean(data),'ko'); drawnow;
                i = i + 1;
                
                pause(0.01);
            end
        end
        
%         function start(obj,duration)
%             obj.daqSession.DurationInSeconds = duration;
%             obj.data_listener = obj.daqSession.addlistener('DataAvailable', @obj.plotMonitor_callback);
%             obj.daqSession.startBackground;
%         end
        
        function registerTrigger(obj,pinID) %Any issued waveforms will wait for an input from this trigger
            obj.daqSession.addTriggerConnection('external', pinID, 'StartTrigger');
        end
        
        function removeTrigger(obj)
            obj.daqSession.removeConnection(1);
        end
        
        function stop(obj)
            obj.daqSession.stop;
        end
        
        function delete(obj)
            delete(obj.daqSession);
        end
        
        function plotMonitor_callback(~,src,event)
            plot(event.TimeStamps, event.Data)
        end
    end
end
