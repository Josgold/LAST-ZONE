# LAST ZONE

A 3D Android battle-royale game prototype built with **Godot 4**.

## Current prototype
- Circular island test area surrounded by a simple ocean
- Low-poly trees, rocks, shrubs, and a small military outpost
- Improved procedural sky, atmospheric fog, filmic tone mapping, ambient occlusion, and directional shadows
- More reflective ocean material and a sandy shoreline detail
- Additional low-poly grass tufts for more varied island ground detail
- Varied tree sizes and fuller multi-part low-poly canopies
- Improved colour-coded supply pickup visuals with readable accent bands
- Dark semi-transparent gameplay HUD panel for clearer information
- On-screen graphics preset switch: Low, Balanced, and High
- Low preset disables ambient occlusion, fog, and directional shadows to reduce graphics load
- Barracks, hangar, supply house, guard house, and workshop
- Watchtower, landing-pad marking, tents, supply crates, perimeter fencing, and lamps
- Simple connecting roads around the outpost
- Third-person low-poly player model with helmet, vest, shoulder pads, belt, boots, backpack, and separate animated arms and legs
- Lightweight alternating arm-and-leg gait animation while moving
- Island landmark signposts for the lookout, supply depot, and landing pad
- Enhanced outpost buildings with layered roof trim, framed windows, corner supports, and entrance steps
- Smoothed third-person camera follow to reduce abrupt movement
- Lightweight player idle breathing and movement bob animation, with a subtle movement lean
- Orbit camera
- WASD + Space keyboard controls, with Shift to sprint
- On-screen hold-to-sprint button for touch devices
- Joystick control reference stored directly, avoiding reliance on a fixed scene node path
- Touch joystick tracks its active finger so a second touch does not accidentally cancel movement
- Virtual on-screen movement joystick with a draggable thumb for 360-degree movement
- Large rounded JUMP, SPRINT, and USE action buttons on the right side of the screen
- Drag the right side of the screen to look around on touch devices, keeping camera-look separate from the left movement joystick
- Dynamic compass HUD showing the camera heading and nearest cardinal direction
- Visual-only 18 m safe-area preview ring around the island centre to help orient exploration
- Hold the right mouse button and move the mouse to look around on desktop
- Basic prototype HUD identifying the solo field-test mode
- Interactable outpost pickups: medkit, shield cell, and supply token
- Basic health, shield, and supply-token counters
- Keyboard interaction with E and an on-screen USE button

## Open the project
1. Install Godot 4.x on a Windows, Linux, or macOS computer.
2. Download or clone this repository.
3. In Godot, choose **Import** and select the `project.godot` file.
4. Open the project and press **F6** or **F5** to run.

## Development status
This is still an early offline prototype. The latest environment, character-model, animation, camera, building-detail, landscape, pickup, HUD, graphics-preset, compass, safe-area preview, and redesigned touch-control additions, including the latest joystick input fix, have not yet been tested in the Godot editor on the target computer. Visual effects may need adjustment for mobile performance. The pickup system is a local prototype only. Online multiplayer, matchmaking, player accounts, combat gameplay, safe-zone logic, full match flow, Android export configuration, and performance testing are not implemented yet.

## Next milestones
1. Test and refine the expanded island, character limbs and gait, landmark signs, smoothed camera, sprint controls, and touch controls.
2. Add more exploration points and environment interactions, then turn the safe-area preview into a timed match mechanic.
3. Add match flow, a shrinking safe area, and non-graphic hit/health feedback.
4. Design secure online rooms and authoritative multiplayer networking.
5. Optimize and export an Android test build.

## Technology
- Godot 4 / GDScript
- GitHub for source control
- A dedicated authoritative server will be evaluated for real-time matches.
