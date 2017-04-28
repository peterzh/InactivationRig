classdef LaserController < handle
    properties
        device='Dev2';
        daqSession;
        AO0;
    end
    
    methods
        function obj = LaserController(device)
            obj.daqSession = daq.createSession('ni');
            obj.AO0 = obj.daqSession.addAnalogOutputChannel(device, 0, 'Voltage');
            
        end
        
        function issueWaveform(obj,V_IN)
            obj.daqSession.queueOutputData(V_IN);
            obj.daqSession.startBackground;
        end
        
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
        
    end
end
