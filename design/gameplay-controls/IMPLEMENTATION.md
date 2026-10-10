# Repeated gameplay taps

- [x] Replace the pause menu's Hold Buttons action with Repeat Buttons.
- [x] Retain button selection and emit alternating press/release events through the game's controller mappings.
- [x] Stop repetition when a real game-control press arrives, allowing normal controls to take over.
- [x] Add long-press interval presets and a custom 50–5000 ms interval, persisted across launches.
- [x] Default to one tap every 200 ms, split equally between pressed and released phases.
- [x] Suspend pulses while paused/inactive and release pressed inputs on stop, game changes, and controller/player focus loss.
- [x] Leave Fast Forward behavior and menu unchanged, per the user's latest request.
- [x] Verify final arm64 Simulator build and whitespace checks.
- [ ] Verify actual-game repeat cadence, manual interruption, pause/resume, custom interval entry, and external-controller disconnect on device.

The repeat timer uses wall-clock time, so Fast Forward does not multiply the tap cadence. Analog inputs are excluded; only discrete game buttons are repeated. Input release uses the emulator bridge to avoid a stuck press when the normal controller receiver rejects events from an inactive scene.

Fast Forward inspection: standard core limits are 3× for GBA and 4× for NES/SNES/GBC/Genesis. N64 and DS depend on hardware. Per-game or system preferences can override the selected rate; no fixed 16× default was found. No Fast Forward change is included.

## Numeric Fast Forward display

- [x] Keep existing speed limits, choices, tap-to-toggle, and long-press configuration.
- [x] Show the configured fast-forward multiplier on the pause-menu button even while disabled.
- [x] Replace the Default option's name with its resolved numeric speed; it still inherits the system preference.
- [x] Share rate resolution between the button, inherited menu option, and emulator to preserve per-game/system precedence and clamping.
- [x] Update the label and actual rate immediately after choosing a speed, before database merge notifications.
- [x] Give menu rows distinct identities when the inherited numeric speed matches an explicit option.
- [x] Verify final build and whitespace checks.
- [ ] Inspect numeric labels and default inheritance during real gameplay on device.

This later request supersedes the earlier instruction to leave Fast Forward untouched. No 16× rate or speed remapping is introduced.
