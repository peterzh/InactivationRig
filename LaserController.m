classdef LaserController < handle
    %Code which handles a laser output, connected to AO0 channel on a NIDAQ
    %board. 
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
        
        function volt = generateWaveform(obj,type,frequency,amplitudeVoltage,totalTime)
            rate = obj.daqSession.rate;
            t = 0:(1/rate):totalTime; t(1)=[];
            
            switch(type)
                case 'square'
                    volt = 0.5*amplitudeVoltage*square(2*pi*frequency*t) + 0.5*amplitudeVoltage;
                case 'sin'
                    volt = 0.5*amplitudeVoltage*sin(2*pi*frequency*t) + 0.5*amplitudeVoltage;
                case 'sinHalf' %Cycle 1,3,5... is set to zero
                    volt = 0.5*amplitudeVoltage*sin(2*pi*frequency*t) + 0.5*amplitudeVoltage;
                    
                    idx = mod(cumsum(volt==min(volt)),2)==0; %Indices to turn one cycle off
                    volt(idx) = 0;
            end
            
            warning('TODO: add phase shift');
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
