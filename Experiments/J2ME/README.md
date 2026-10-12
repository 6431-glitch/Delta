# J2ME prototype

Isolated on `experiment/j2me`, based on the local `1.1.1` merge. This is a standalone engine validation app, not yet a Delta library platform.

## Build

Requires Xcode and a JDK supporting `javac --release 8`. Initialize the pinned source with `git submodule update --init Experiments/J2ME/JarBox`.

```sh
python3 Experiments/J2ME/prepare.py /private/tmp/DeltaJ2MEPrototype
xcodebuild -project /private/tmp/DeltaJ2MEPrototype/J2MEEmulator.xcodeproj \
  -scheme J2MEEmulator -configuration Debug -sdk iphonesimulator \
  -derivedDataPath /private/tmp/DeltaJ2MESmokeBuild \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES ARCHS=arm64 build
```

Use a fresh output directory each time. The preparation script leaves the vendor submodule unchanged, rebuilds the Java API, compiles the original smoke MIDlet, and applies the local `Aurora/*.swift` UI overlays, and changes the test app's bundle identifier to `page.ducnguyen.Delta.J2MESmoke`. The upstream runtime JAR is pinned with the source; rebuilding that runtime from source is still pending.

Launch the installed app with `SIMCTL_CHILD_DELTA_J2ME_SMOKE=1 xcrun simctl launch --console-pty <simulator-id> page.ducnguyen.Delta.J2MESmoke`. Without that environment variable, it opens the J2ME Games importer. For normal testing, leave `DELTA_J2ME_SMOKE` unset in Xcode’s scheme. The smoke fixture displays a Canvas and stores a launch counter in RMS; press a keypad button to test key events. Logs use the `DELTA_SMOKE` prefix.

The preparation script repairs an upstream Canvas bug: the first full paint used a zero-sized clip rectangle. Full paints now initialize the clip to the Canvas size.

## Progress

- [x] Pin JarBox at `8afc8d808ca22160139333d1d58138c7dca91169`.
- [x] Build the upstream app for arm64 iOS Simulator.
- [x] Build an original MIDlet and a separately identified prototype app.
- [x] Confirm runtime log `JIT_ENABLE=0`, successful MIDlet startup, and RMS write.
- [x] Identify and repair the initial Canvas clipping bug in the prototype preparation step.
- [x] Verify the repaired framebuffer visually, keypad delivery (`53`, the 5 key), and persistence across relaunch (RMS counter 1 → 2).
- [x] Verify the smoke MIDlet calls `destroyApp`, returns successfully, and logs native-state cleanup on exit.
- [ ] Stress repeated sessions in the same process and verify no surviving VM threads.
- [ ] Test on a signed physical iPhone, then test representative permitted games and audio/3D.
- [x] Integrate a dedicated runtime/session controller, JAR/JAD imports, Library platform selection, phone controls, and per-game RMS storage into Delta.
- [ ] Resolve pause/resume and save-state capability before exposing Delta's gameplay actions.

## Test your own JAR

Java ME is now integrated into Delta's main Library on `experiment/j2me`. Use **Library → +** to import a JAR (and optional same-name JAD). Use **Game Actions → Game Settings** to configure its screen. The separate **Delta J2ME** prototype below remains available for engine isolation.

1. Prepare/build the prototype using the commands above, or open the generated `J2MEEmulator.xcodeproj` in Xcode and run the `J2MEEmulator` scheme. For an iPhone, select your signing team and device.
2. Leave `DELTA_J2ME_SMOKE` unset so the app opens **J2ME Games**.
3. Save your `.jar` game in Files. Tap **Import JAR**, select it, and tap **Open**. If you have a same-name `.jad`, select both together; you can also attach the descriptor after importing its same-name game.
4. Tap the imported game's icon to play. Exit returns to the game list. Long-press its icon → **Screen Configuration** to choose a phone resolution, enter a custom size, choose 240 × 320, or return to **Automatic**. Settings are saved per game and applied on its next launch. FPS and 3D enhancement remain in the same game menu.

The Files picker allows generic file types because some providers label `.jar` as ZIP/data. Import checks the extension, reports copy errors, and preserves existing same-name games by assigning a numbered filename. `On My iPhone > Delta J2ME` is exposed in Files. On Simulator, copy a JAR into the prototype's Documents folder through the app container and select it with the same picker.

- [x] Expose an explicit Import JAR action and the app's Documents folder in Files.
- [x] Verify a JAR is selectable and imports through the system Files picker.
- [x] Verify the imported MIDlet launches, receives key input, and exits back to the game list.
- [ ] Verify importing from iCloud Drive and launch compatibility on a physical iPhone.

## Aurora gameplay UI

Selected designs: option 1 in landscape and option 2 in portrait. The local UIKit overlays are applied by `prepare.py`; the pinned vendor source remains unchanged. The game viewport preserves each MIDlet's configured aspect ratio. Landscape places the directional pad and L/R soft keys left, with the full keypad right. Portrait stacks the viewport, directional pad/soft keys, and keypad. The center of the directional pad sends Fire/5; dragging supports eight directions. Canvas commands appear in the native game menu rather than covering number keys. The menu deliberately exposes no pause or save-state action while those engine capabilities remain unresolved.

- [x] Implement both adaptive layouts, Aurora control surfaces, and pressed-key feedback.
- [x] Preserve keypad press/repeat/release and native Canvas command actions.
- [x] Build the redesigned standalone app for arm64 Simulator.
- [x] Verify final portrait and landscape screenshots, keypad input, Fire, directional input, soft keys, and menu dismissal.

Verification: [portrait](verification/aurora-portrait.png), [landscape](verification/aurora-landscape.png), and [runtime log](verification/aurora-runtime.txt). These screenshots use the original smoke MIDlet, not the concept art. Physical-device ergonomics and game-specific Canvas command menus remain to be validated.

## Per-game screen configuration

- [x] Add a dedicated Screen Configuration sheet with the current size shown in the game menu.
- [x] Support common phone presets, landscape presets, custom dimensions (64–1024 pixels each), and reset to 240 × 320.
- [x] Preserve per-game settings and aspect ratio independently of device orientation.
- [x] Build successfully and verify custom 176 × 220 reaches the engine framebuffer.
- [x] Verify the selected size survives restarting the app.
- [x] Add automatic JAR/JAD and filename screen-size inference in the prototype.

## Automatic screen detection

New games use Automatic. Existing manual size selections remain authoritative. The configuration menu shows both the effective dimensions and their source. Automatic removes the manual override.

Detection order:

1. Explicit original-display-size metadata (JAD overrides the same JAR property), or paired explicit screen-width/height extensions.
2. A unique delimited dimension token in the filename, such as `176x220`, `320X240`, or `128×160`.
3. Default 240 × 320 when evidence is absent, invalid, or ambiguous.

The parser recognizes `Nokia-MIDlet-Original-Display-Size`, plus optional `MIDlet-Screen-Width`/`MIDlet-Screen-Height` and `j2me.screen.width`/`j2me.screen.height` extensions. It does not use target/scaling dimensions, image asset sizes, or guess a phone model. There is no verified game-profile database yet. Descriptor imports are local and matched by basename; they do not download `MIDlet-Jar-URL`. Display hints do not supply the engine with other JAD application properties yet.

- [x] Cache detection while scanning games off the main thread.
- [x] Preserve manual overrides and expose Automatic with source information.
- [x] Import paired JAR/JAD files and validate descriptor size/readability.
- [x] Pass 18 focused regression checks for priority, folded metadata, invalid dimensions, and ambiguous filenames.
- [x] Verify system-picker import of metadata, filename, and paired-JAD fixtures.
- [x] Verify detected sources in the game menus and 240 × 400 engine rendering from JAD metadata.
- [x] Verify existing 176 × 220 manual override survives the update and Automatic clears it.

Run focused checks:

```sh
swiftc -module-cache-path /private/tmp/DeltaJ2MESwiftCache \
  Delta/J2ME/J2MEScreenProfile.swift \
  Experiments/J2ME/Tests/ScreenDetectionTests.swift \
  -o /private/tmp/DeltaJ2MEScreenTests
/private/tmp/DeltaJ2MEScreenTests
```

`Tests/create_screen_fixtures.py <built delta_smoke.jar> <output directory>` creates original fixtures for the Files picker.

## Integration findings

JarBox runs Java threads with an event-driven framebuffer callback. Delta's `EmulatorBridging` expects a frame-driven loop and explicit pause/resume/save-state methods. The upstream native JVM bridge offers initialize/run/request-stop/destroy. Delta adds cooperative interpreter suspension at VM safe points; VM snapshots remain unsupported. RMS saves are persistent files; they are not emulator save states. Audio currently uses native Apple players rather than Delta's PCM renderer. The integrated dedicated gameplay controller preserves these boundaries and hides unsupported emulator actions.

The native runtime is process-global and its destroy code discusses force-zombied threads. The integrated controller admits one J2ME session at a time. It destroys the JVM before admitting another session. Backgrounding now pauses the Java session and active audio players. Foregrounding resumes it unless it was manually paused. Exit unpauses the interpreter to let the event loop stop, destroys the JVM, checkpoints RMS, and returns to Library while the app is active. This preserves an in-memory session while iOS retains the process; it does not restore a VM after the OS terminates it.

## Source and notices

Upstream: https://github.com/ccbkv/J2MEEmulator-iOS (JarBox). Its root license is Apache-2.0. Component headers include other notices, including EPL-1.0 for Nokia's M3G implementation. Preserve the vendored notices; a complete dependency/asset notice inventory remains required before distribution. The original smoke fixture is local test code and includes no commercial game content.

## Main Library integration

- [x] Link interpreter runtime and bundle patched Java API.
- [x] Import JAR/JAD into Library with metadata and screen hints.
- [x] Launch Aurora gameplay with one session and per-game RMS storage.
- [x] Expose screen configuration and hide unsupported emulator actions.
- [x] Build and verify import, launch, controls, exit, and relaunch in Delta.

The main app links a `J2MENative` static library from the pinned submodule. UIKit adapter sources live in `Delta/J2ME`; console DeltaCore registration and controller-skin settings exclude Java ME. The Java API bundled there includes the initial Canvas clipping correction. Rebuild these resources with `python3 Experiments/J2ME/build_resources.py` (JDK on PATH). `ruby Experiments/J2ME/integrate_project.rb` updates Xcode membership idempotently when adding adapter files.

Screen overrides, original filenames, JAD display hints, phone/key preferences, touch layouts and performance settings are packaged with RMS data in a versioned save bundle. The bundle uses the normal GameSave/Harmony path, including iCloud when selected in Delta Sync. JAR files and artwork retain normal Library synchronization. Cloud saves apply before opening settings or launching a game; RMS publishes after Exit Game, and closed-game preference edits also publish. JAD display hints do not inject arbitrary descriptor properties into the VM. No fast-forward, VM save states, cheats, or live gameplay previews are exposed for Java ME.

- [x] Verify main Library JAR import and Java ME filtering through the system Files picker.
- [x] Verify manual 128 × 128 reaches the engine, persists, and Automatic clears it.
- [x] Verify paired JAR/JAD import detects JAD metadata and renders at 240 × 400.
- [x] Verify portrait/landscape layouts and numeric key delivery.
- [x] Verify RMS launch count advances from 1 to 2 after updating/reopening Delta.
- [x] Verify explicit exit and foreground return after background shutdown without an orientation alert.
- [x] Pass the main Delta Simulator build and all 18 screen detection checks against the integrated parser.
- [ ] Validate signed physical-device compatibility, representative games, audio/3D, and long-running session stress before release.

## J2ME feature expansion

- [x] Phone compatibility presets and per-game key mapping.
- [x] Touch layout editing, opacity, resizing, and keypad visibility.
- [x] RMS export/import/reset and existing Delta cloud synchronization.
- [x] Cooperative VM pause/resume and audio suspension.
- [x] Per-game FPS and 3D render scale.
- [x] Physical controller input and disconnect cleanup.
- [x] Compatibility error reporting and exportable session diagnostics.
- [x] Build and run focused regression/runtime checks.


### Using the additions

Game Actions → Game Settings opens phone, screen, touch, performance, saves, controller mapping and diagnostics options. Generic MIDP, Nokia and Sony Ericsson presets change platform/key hints and fallback dimensions, preserving explicit screen overrides and detected JAR/JAD dimensions. API families are supplied by the engine, not enabled by changing a preset.

The gameplay menu offers Pause/Resume and Edit Touch Layout. Drag to reposition, pinch to resize, or tap a control to enter position/size percentages. Joystick, keypad and both soft keys have independent placements; portrait and landscape save separately. Opacity and keypad visibility are configured in Game Settings. Touch and extended gamepad inputs share a held-key reducer; cancellation, pause, exit and controller connection changes release keys.

Backups use `.j2mebackup`: bounded JSON with base64 RMS files and Java preferences (32 MB decoded saves, 4096 entries). Imports reject wrong-game/version/unsafe paths and stage replacement before swapping the RMS folder. Reset/import retain one local recovery bundle; Restore Recovery Backup can undo the previous operation. Empty RMS is a syncable reset instead of deleting the cloud record. The last-applied SHA1 receipt prevents an unchanged archive from overwriting local progress. Save synchronization follows Delta's existing authentication, provider and conflict handling.

Native interpreter/audio overlays generate during the Xcode build from the pinned, unchanged vendor source. `prepare_native.py` asserts its patch points. Rebuilding Java resources includes profile-aware Canvas game actions and captured MIDlet runner/lifecycle errors. Session reports record the selected configuration and runner errors, not a full stdout trace or complete worker-thread exception log.

Validation:

- [x] Pass the Delta iOS Simulator build, including automatic native-overlay regeneration with Generated absent.
- [x] Pass 18 screen-detection and 37 backup/preferences/input-state checks.
- [x] Verify Nokia dimensions and raw Fire key `-5` reach the engine.
- [x] Verify a Java worker stops at tick 28 during manual pause, continues without a second start, and stays at tick 60 while backgrounded before resuming.
- [x] Verify 30 FPS and native 1× 3D settings persist in the settings UI.
- [x] Verify RMS/preferences archive SHA1 matches the Harmony GameSave record.
- [x] Verify system share-sheet export, reset to empty RMS, and byte-for-byte recovery/restaging.
- [ ] Verify drag/pinch and numeric layout editing on a physical device; Simulator automation did not deliver drag gestures reliably.
- [ ] Verify error-report export against representative incompatible games, audio/MIDI pause and 3D rendering on a device.
- [ ] Verify physical extended gamepads and iCloud transfer/conflicts between two signed devices.

These device checks remain release validation, not missing settings or runtime implementation. The unsigned Simulator cannot authenticate the signed iCloud/keychain environment.

Run feature checks:

```sh
swiftc -module-cache-path /private/tmp/DeltaJ2MESwiftCache \
  Delta/J2ME/J2MEPreferences.swift Delta/J2ME/J2MEBackup.swift \
  Delta/J2ME/J2MEInputState.swift Experiments/J2ME/Tests/FeatureTests.swift \
  -o /private/tmp/DeltaJ2MEFeatureTests
/private/tmp/DeltaJ2MEFeatureTests
```
