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
            try
                obj.AO0 = obj.daqSession.addAnalogOutputChannel(device, 0, 'Voltage');
            catch
                warning(['LaserController failed to initialise on ' device])
            end
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
                case 'trunacedSin'                 
                    galvoMoveTime = 0.5e-3;
                    numElements = rate*galvoMoveTime/2;
                    volt = 0.5*amplitudeVoltage*cos(2*pi*frequency*t) + 0.5*amplitudeVoltage;
                    cutOff = amplitudeVoltage - volt(numElements);
                    
                    %Normal sine wave
                    volt = 0.5*amplitudeVoltage*sin(2*pi*frequency*t) + 0.5*amplitudeVoltage;
                    %Truncate at output level
                    volt(volt<cutOff) = 0;
                 
                    plot(t,volt);
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
        
        function I_LD = laserCurrent(ILD_SET, ILD_MAX, VOLT_IN)
            I_LD = ILD_SET + ILD_MAX*VOLT_IN/10;
        end
        
        function stop(obj)
            obj.daqSession.stop;
        end
        
        function delete(obj)
            delete(obj.daqSession);
        end
        
    end
end
