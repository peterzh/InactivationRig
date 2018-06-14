# Very basic readme
The following classes handle low-level inactivation with hardware:
-GalvoController: handles connecting to and issuing commands to the galvo motors
-LaserController: same as above but for laser
-ThorCamController: same as above but for the thorcam ccd camera
-MonitorController: useful for monitoring any inputs on the national instruments board. Not often used, but can be useful for verifying that the NI board is correctly sending out the commands.

The laserGalvoExpt class then handles bringing all these controller classes together for the purposes of running the experiment. 

laserGalvoExpt_callback is a callback function which is registered to the remote experiment server, and is run whenever the remote experimental PC broadcasts an update about its state. The specifics of the experiment are configured here.



# (outdated) instructions for running an experiment on rigs Zym1 and Zym2

*On the galvo PC, load one MATLAB instance for each rig. Then type command L = lasergalvoexpt('zym1') or L = lasergalvoexpt('zym2'). This will load a video feed. 
*If using a light isolation cone, ensure it is in the UP position, so light from the monitors can illuminate the surface of the brain.
*Ensure the brain is in focus, and centred within the view of the camera. The focus can be adjusted by adjusting the height of the laser-galvo-camera unit.
*On galvo PC, run L.calibstereotaxic and click first on BREGMA and then click on the midline towards LAMBDA. This calibrates the coordinate system for the galvo experiment. Check that the grid of points make sense given the shape of the mouse implant.
*To create a connection from expServer to the galvo PC, run L.registerListener. This only needs to be run once when running multiple experiments. The only time you need to re-run this command is when you restart expServer. In this case, run L.clearListener, then L.registerListener.

==Start experiment==
*If required, move the light isolation down to be flush with the top of the implant
*Run experiment on MC
*On galvo PC, you should start seeing text printed on the console window. Each line corresponds to a new trial. If coordinates are printed, this means that galvo motors are being positioned to that coordinate. If the text is '''bold''' the laser should be ON at that location.
*The background colour of the video feed is green if repeatNum<5, Yellow if repeatNum is 6-10, and Red if repeatNum is 10+.

==Ending==
*When done, please ensure you switch off the laser controller (the light grey box) via the button on the top-right. This disables the laser diode.
