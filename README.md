Running an experiment with the galvos on Zym1 or Zym2.

==Ensure the relevant hardware is switched on/enabled==
*Galvo motor driver (black unit). Green LEDs should be lit.
*Laser diode (black square, within the rig) should have a green LED lit on top. If not, flip switch at the top.
*Laser controller (light grey unit), should be switched ON using the large left button, and the laser diode should be enabled with the button on the top-right.
*Zimbabwe PC (connect via VNC, should have orange wallpaper)

==Headfix mouse==
*usual steps

==Setup experiment on MC & expServer==
*On expServer, run srv.expServer
*Press 'B' on the expServer to turn the screens white
*Prepare experiment on MC

==Setup experiment on zimbabwe==
*On zimbabwe, load one MATLAB instance for each rig. Then type command L = lasergalvoexpt('zym1') or L = lasergalvoexpt('zym2'). This will load a video feed. 
*If using a light isolation cone, ensure it is in the UP position, so light from the monitors can illuminate the surface of the brain.
*Ensure the brain is in focus, and centred within the view of the camera. The focus can be adjusted by adjusting the height of the laser-galvo-camera unit.
*On zimbabwe, run L.calibstereotaxic and click first on BREGMA and then click on the midline towards LAMBDA. This calibrates the coordinate system for the galvo experiment. Check that the grid of points make sense given the shape of the mouse implant.
*To create a connection from expServer to the galvo PC, run L.registerListener. This only needs to be run once when running multiple experiments. The only time you need to re-run this command is when you restart expServer. In this case, run L.clearListener, then L.registerListener.

==Start experiment==
*If required, move the light isolation down to be flush with the top of the implant
*Run experiment on MC
*On zimbabwe, you should start seeing text printed on the console window. Each line corresponds to a new trial. If coordinates are printed, this means that galvo motors are being positioned to that coordinate. If the text is '''bold''' the laser should be ON at that location.
*The background colour of the video feed is green if repeatNum<5, Yellow if repeatNum is 6-10, and Red if repeatNum is 10+.

==Ending==
*When done, please ensure you switch off the laser controller (the light grey box) via the button on the top-right. This disables the laser diode.
