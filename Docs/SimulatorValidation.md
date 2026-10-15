# Simulator validation — 2026-10-15

Follow-up validation on an existing user simulator. The runner supports `--device UDID` for an already booted device; it does not erase, shut down, or delete that device. Installing the Debug app updates its installed build, and importing the original test fixtures adds them to its library.

- [x] Inspect simulator availability; all devices initially shut down.
- [x] Add existing-device support to the smoke runner; command-line and syntax checks pass.
- [x] User selected iPhone 17 Pro, iOS 26.5 (`4FFBF522-1DE8-4306-B5C8-E89F786D5E78`); booted successfully.
- [x] Build the current Debug app (`.build/quality-sim-validation-build.log`: BUILD SUCCEEDED).
- [x] Verify NES import, rendered frame, pause/resume, save/load, and stop.
- [x] Verify Java import, rendered frame, pause/resume, shutdown, and checkpoint.
- [x] Verify Java RMS persistence across relaunch; backup contents changed and captured frame shows `RMS launches: 2`.
- [x] Inspect captured NES/Java frames and reopen the normal app.
- [ ] Merge validation changes into `refactor/codebase-quality`.

Console smoke uses injected silent audio. These checks do not establish audible playback, physical controller/Operator behavior, signed-device cloud sync, or comparable device performance.

Results: all three runs (`console`, `java`, `java-repeat`) passed. Reports, runtime logs, rendered frames and screenshots are in `.build/quality-user-sim-2026-10-15/`; runner output is `.build/quality-user-sim-2026-10-15.log`. Unsigned Simulator logs contain missing Keychain entitlement errors (`-34018`), so account/Keychain behavior is not validated. The first Java launch reports the expected missing RMS store before creating it; relaunch restores it successfully.

To repeat on an already booted device:

```sh
python3 Scripts/Quality/smoke.py \
  --app .build/quality-ios/Build/Products/Debug-iphonesimulator/Delta.app \
  --device 4FFBF522-1DE8-4306-B5C8-E89F786D5E78 \
  --output .build/quality-user-sim-2026-10-15
```
