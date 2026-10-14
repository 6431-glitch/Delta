# J2ME phone navigation and audio ownership

- [x] Replace the analog joystick with separate Up, Down, Left, Right and center Select keys.
- [x] Preserve phone mappings (2/8/4/6/5), input remapping, press/release/repeat, pause cancellation and saved control placement.
- [x] Use Aurora button surfaces and pressed feedback; release when a finger exits its button rather than selecting unintended diagonal keys.
- [x] Replace raw AVFoundation pointers with monotonically increasing opaque IDs and ARC ownership.
- [x] Serialize native calls with pause, close and cleanup; make stale and repeated closes no-ops.
- [x] Invalidate all IDs on session cleanup and reject players created after cleanup.
- [x] Transfer MIDI close/cleanup ownership to main-queue blocks without synchronously waiting while holding the audio lock.
- [x] Verify production registry lifetime, duplicate close, stale lookup, teardown, late creation, ID uniqueness and concurrent cleanup with Foundation/ARC tests.
- [x] Build Delta for arm64 iOS Simulator.
- [ ] User to test physical-device controls and audio; HD gameplay retesting is delegated to the user at their request.

Implementation keeps the pinned JarBox sources unchanged. `prepare_native.py` generates the compiled audio overlay and includes `J2MEAudioHandles.h`. Java handles no longer encode object addresses; a close atomically removes ownership once. Pause tracking drops closed players, and native calls after teardown cannot use released objects. This fixes the ownership path shown in the `n_audioClose` crash screenshot; physical reproduction is still pending.

The navigation control retains its legacy type and placement key to preserve existing touch-layout settings. The layout editor labels it Direction Pad. Select sends the same Fire/5 mapping used by the phone keypad. Numeric keys remain available separately.

Validation: `Tests/J2MEAudioHandles/verify.m` compiles against the production registry with ARC. Build log: `/private/tmp/DeltaAudioDPad-build.log`. No HD game was relaunched for this verification.

## J2ME pause panel

- [x] Replace the gameplay X with a Pause button and native dismissible pause sheet.
- [x] Add Continue, Screenshot sharing and Home, preserving the normal shutdown/save checkpoint path.
- [x] Pause input/Java/audio while the panel is open; resume on Continue, interactive dismissal or screenshot sharing completion.
- [x] Preserve phone commands and touch-layout editing in the secondary menu.
- [x] Omit Save State, Load State and Speed at the user's explicit request. The engine has persistent RMS saves, not VM snapshots or fast-forward.
- [x] Compile the final pause panel: arm64 iOS Simulator build succeeded (`/private/tmp/DeltaJ2MEPause-build.log`).
- [ ] User to verify panel interactions on device; no HD gameplay retest requested.

Screenshots share the game framebuffer without the control overlay; native forms/lists use a view capture. Home uses the existing shutdown callback to publish RMS saves. This panel does not introduce emulator state saving or timing changes.

## App-wide orientation from gameplay

- [x] Add Orientation to the shared console pause menu (all Delta cores).
- [x] Add Orientation to the J2ME pause panel.
- [x] Offer Auto, Lock Portrait and Lock Landscape using the same persisted app-wide lock as Library.
- [x] Show the selected orientation and update the title/icon after choosing.
- [x] Use native action sheets with iPad anchors and report rotation errors.
- [x] Complete the final arm64 Simulator build (`/private/tmp/DeltaOrientationMenu-build.log`).
- [ ] User to verify physical-device rotation while paused.

No per-core orientation preferences are introduced. Changes apply through `AppOrientation.apply`, which invalidates controller masks and requests geometry updates for app scenes. The Java ME panel itself follows the current mask, and selecting orientation keeps the game paused.

## Larger contiguous numpad

- [x] Remove horizontal and vertical gaps from the 3 × 4 J2ME numpad; keys fill the existing control area.
- [x] Round only the outer keypad boundary, with square internal edges and larger numeric labels.
- [x] Preserve key mappings, repeat behavior and custom control placement.
- [x] Complete the Simulator build (`/private/tmp/DeltaJ2MENumpad-build.log`).
