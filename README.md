# LAST ZONE

A 3D Android battle-royale game prototype built with **Godot 4**.

## Current prototype
- Circular island test area surrounded by a simple ocean
- Low-poly trees, rocks, and a small military outpost
- Barracks, hangar, supply house, guard house, and workshop
- Watchtower, landing-pad marking, tents, supply crates, perimeter fencing, and lamps
- Simple connecting roads around the outpost
- Third-person temporary player model with field-colour outfit details
- Orbit camera
- WASD + Space keyboard controls
- On-screen movement and jump buttons
- Drag the right side of the screen to look around on touch devices
- Hold the right mouse button and move the mouse to look around on desktop
- Basic prototype HUD identifying the solo field-test mode
- Interactable outpost pickups: medkit, shield cell, and supply token
- Basic health, shield, and supply-token counters
- Keyboard interaction with E and an on-screen INTERACT button

## Open the project
1. Install Godot 4.x on a Windows, Linux, or macOS computer.
2. Download or clone this repository.
3. In Godot, choose **Import** and select the `project.godot` file.
4. Open the project and press **F6** or **F5** to run.

## Development status
This is still an early offline prototype. The latest environment and pickup additions have not yet been tested in the Godot editor on the target computer. The pickup system is a local prototype only. Online multiplayer, matchmaking, player accounts, combat gameplay, safe-zone logic, full match flow, Android export configuration, and performance testing are not implemented yet.

## Next milestones
1. Test and refine the expanded island, movement, camera, and touch controls.
2. Add interactable pickups and a basic inventory.
3. Add match flow, a shrinking safe area, and non-graphic hit/health feedback.
4. Design secure online rooms and authoritative multiplayer networking.
5. Optimize and export an Android test build.

## Technology
- Godot 4 / GDScript
- GitHub for source control
- A dedicated authoritative server will be evaluated for real-time matches.
