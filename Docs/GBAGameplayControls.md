# GBA gameplay controls — 2026-10-15

- [x] Remove Fast Forward from the GBA pause menu; other systems retain their menu item.
- [x] Put a Fast Forward toggle in the former in-game Quick Load position.
- [x] Place Quick Load beside Quick Save; use a shared row above the shoulders when three controls do not fit between them.
- [x] Preserve speed selection through the Fast Forward button's long-press menu, with active-state feedback and accessibility labels.
- [x] Preserve save availability, hardcore load restrictions, multiplayer restrictions, and repeat-button selection hiding.
- [x] Build the Debug Simulator app (`.build/gba-controls-build.log`: BUILD SUCCEEDED).
- [x] Verify the GBA scene in portrait/landscape, Fast Forward on/off feedback, long-press speed selection, Quick Save enabling Quick Load, Quick Load, and the pause menu without Fast Forward on iPhone 17 Pro/iOS 26.5.
- [ ] Merge the completed change into `refactor/codebase-quality`.

Verification used an original solid-blue GBA fixture and the Debug-only silent audio backend. `DELTA_QUALITY_SMOKE_INTERACTIVE=1` keeps the fixture running for manual controls checks instead of executing the automatic shutdown test. Artifacts are under `.build/gba-controls/`. Physical-device/audio validation is unchanged.
