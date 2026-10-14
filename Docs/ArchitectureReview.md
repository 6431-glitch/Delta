# App architecture and platform extensibility review

Reviewed: 2026-10-14. Scope: current working tree, including ongoing local changes.

## Post-upgrade assessment — 2026-10-14

The code upgrade introduces separately linked DeltaDomain/DeltaApplication modules, descriptor-backed systems, shared preflight/lifecycle/storage contracts, native service injection, and explicit asynchronous ownership. See [QualityResults.md](QualityResults.md) for implemented changes, verification, and remaining gates.

| Area | Initial estimate | Current estimate |
| --- | --- | --- |
| Conventional console extension | 6/10 | 7/10 |
| Different runtime family | 3/10 | 5/10 |
| Shared logic on another Apple host | 3/10 | 4/10 |
| Shared logic outside Apple | 1/10 | 2/10 |
| Testability/substitution | 4/10 | 7/10 |

These remain architectural estimates, not measured port effort. No host port or device performance improvement is claimed. Legacy UI singletons, native Apple media types, and Operator observer scene glue remain. Thirty contracts, the fixture suite, builds, and limited simulator smoke checks support the new seams.

## Historical baseline review

The findings and line references below describe the initial checkout before the upgrade; they are retained as baseline evidence, not a description of every current file.

Follow-up: [Codebase quality upgrade plan](CodebaseQualityUpgrade.md) now tracks delivered code and remaining validation gates.

Verdict: **5/10 overall extensibility**. Delta has a useful emulator adapter architecture, but much of the application remains one compilation unit with concrete core knowledge, global services, and presentation mixed into orchestration. Adding another conventional console is feasible; adding a different runtime or another host OS requires substantially more work.

These are engineering estimates based on static inspection, not measured implementation effort or confirmed platform build results. No app code was modified, and no build/runtime verification was performed. Vendored emulator implementations were not exhaustively audited.

## Review completion

- [x] Inspect workspace, target structure, package manifests, and dependencies.
- [x] Trace emulator registration, rendering, input, and session construction.
- [x] Trace library import, launch, persistence, settings, and sync integration.
- [x] Compare conventional cores with the J2ME integration.
- [x] Record coupling evidence, ratings, and an incremental improvement plan.

## Ratings

Scale: 1 = substantial redesign; 5 = achievable with changes across several areas; 10 = extension mostly isolated to an adapter and registration.

| Area | Rating | Assessment |
| --- | --- | --- |
| Add a conventional emulated console | 6/10 | Existing core protocols and resource bundles help, but app switches and configuration require edits. |
| Add a runtime unlike existing consoles | 3/10 | J2ME bypasses the normal core/session route and needs special handling throughout the app. |
| Share logic with another Apple host OS | 3/10 | Domain, rendering, session, storage, and UI boundaries need separation. Reusing an iOS app on Mac is a different scope from a native macOS port. |
| Share app logic with a non-Apple host | 1/10 | UIKit, Objective-C runtime, AVFoundation, Core Data, and graphics dependencies reach into core contracts and implementations. Native emulator source may be reusable separately. |
| Testability and dependency substitution | 4/10 | Some isolated test seams exist, but database, sync, settings, and emulator selection commonly resolve global concrete services. |

## Current structure

| Component | Actual boundary | Responsibility and limitation |
| --- | --- | --- |
| `Delta` | App target | Library UI, gameplay, settings, Core Data, import, sync integration, achievements, and J2ME Swift code share the target. Most feature directories are organization, not independent modules. |
| `DeltaCore` | Separate Xcode project; also has an SPM manifest | Shared emulator contracts, execution, audio/video, input, controller skins, and UIKit views/controllers. Useful separation from the app, but internally combines runtime and presentation. |
| NES/SNES/GBC/GBA/N64/MelonDS/GPGX cores | Separate projects/adapters | Native engines are wrapped through `DeltaCoreProtocol` and `EmulatorBridging`. This is the strongest extensibility boundary. |
| `DeltaFeatures` | Static library target | Reusable feature/option machinery, with SwiftUI and Combine types in its API. Separate from app-specific settings. |
| `J2MENative` | Static native library target | Native runtime isolation exists, but its Swift integration is compiled into the app and uses a separate gameplay path. |
| Harmony and Roxas | External projects/local CocoaPods | Sync and persistence/UI infrastructure. App models adopt Harmony contracts directly; database initialization merges the Harmony model. |
| DeltaOperator | Sources in the app target | A named integration folder/submodule, but not an independent target in this project. It directly accesses app database and gameplay types. |
| `DeltaPreviews` | Framework target | Preview support includes a same-named mock `DatabaseManager`; this is a separate preview compilation seam, not general app dependency injection. |
| Root `Package.swift` | Narrow macOS test package | Builds `iCloudSyncState.swift` and its tests. It does not package the app or establish app-wide macOS support. The state helper still imports Core Data and CryptoKit. |

The workspace combines Xcode projects, CocoaPods, SPM products, submodules, and a binary OperatorKit framework. Multiple build mechanisms do not inherently imply poor architecture, but they increase the configuration work needed for new targets. DeltaCore and GPGX package manifests currently declare iOS 14; the app project selects `iphoneos` and device families `1,2`.

## Coupling findings

### 1. High: engine/session code depends on presentation and concrete host services

Evidence:

- `Cores/DeltaCore/DeltaCore/Emulator Core/EmulatorCore.swift:49` exposes `Set<GameView>`.
- The same file at lines 56–57 stores concrete `AudioManager` and `VideoManager`; lines 122–123 construct them directly.
- `Cores/DeltaCore/DeltaCore/Emulator Core/Video/VideoManager.swift:52` also owns `GameView` instances, and line 59 stores `EAGLContext`.
- `Cores/DeltaCore/DeltaCore/Emulator Core/Audio/AudioManager.swift:172` configures the shared `AVAudioSession`.
- `Cores/DeltaCore/DeltaCore/Cores/DeltaCoreProtocol.swift:25` exposes `AVAudioFormat` in the core contract.

Impact: a host port cannot simply replace the app UI while leaving the shared session implementation intact. Graphics/audio and view ownership are embedded in the runtime layer. Objective-C protocols and associated-object input state add further barriers outside Apple platforms.

Recommendation: separate portable emulator/session contracts from Apple implementations and UIKit presentation. Inject audio/video services into session construction. Move view attachment into presentation adapters. For non-Apple support, use neutral audio/video descriptors and an explicit input-state owner; keep Objective-C bridges as adapters.

### 2. High: J2ME is a parallel integration path without a shared session contract

Evidence:

- `Delta/Systems/System.swift:118` declares `deltaCore` as available for every system, but its J2ME branch terminates with `preconditionFailure`.
- `Delta/Game Selection/GameCollectionViewController.swift:579` branches to `J2MELibrary.launch`.
- `Delta/J2ME/J2MELibrary.swift:30` consults a view controller's global session state; line 94 reads Harmony sync state through `SyncManager.shared`.
- `Delta/Database/DatabaseManager.swift:385` onward contains JAD/JAR metadata and import handling.
- `Delta/Database/Model/Human/Game.swift:209` contains J2ME-specific deletion behavior.
- Deep linking, core settings, controller configuration, fast-forward settings, and achievements also contain J2ME exclusions or branches.

Static count: 11 Swift files under `Delta` outside its J2ME directory reference `J2ME` or `.j2me`. This is a textual indicator, not a count of independently required integration points.

Impact: another unusual runtime would likely expand these branches. Generic consumers must know which systems can safely expose a Delta core. This is a structural hazard; the audit does not establish that an existing user flow reaches the failing branch.

Recommendation: introduce a shared `EmulationSession` lifecycle with separate DeltaCore and J2ME adapters. Expose optional capabilities for save states, cheats, fast-forward, secondary cartridges, and runtime configuration. Keep J2ME forms and platform UI specialized; share launch coordination and capability discovery rather than forcing every runtime into a console-only interface.

### 3. High: library/gameplay controllers configure concrete emulator bridges

Evidence:

- `Delta/Game Selection/GameCollectionViewController.swift:289` casts to `GBCEmulatorBridge` to set palettes.
- Line 305 casts to `MelonDSEmulatorBridge` to set DS/DSi mode, JIT, networking, and secondary game configuration.
- `Delta/Emulation/GameViewController.swift:1990` contains N64-specific graphics selection.
- Line 2302 reads MelonDS firmware paths; line 2310 casts the bridge to update WFC DNS.
- `Delta/Systems/DeltaCoreProtocol+Delta.swift:80` onward matches specific cores to determine fast-forward limits.

Impact: importing another core implementation affects presentation/orchestration files. Replacing a core for an existing system can lose behavior unless each concrete cast and identity match is revisited.

Recommendation: move system configuration and tuning into core adapters. Let controllers consume explicit capability interfaces, such as palette configuration or wireless configuration, rather than vendor bridge classes.

### 4. High: persistence, files, import policy, and sync are intertwined

Evidence:

- `Delta/Database/DatabaseManager.swift:45` subclasses `RSTPersistentContainer`; initialization merges the Harmony model.
- Its `prepare` implementation at line 111 sets up skins and concrete MelonDS BIOS records, alongside its game import responsibilities.
- `Delta/Database/Model/Human/Game.swift:25` is simultaneously a managed model and a `GameProtocol` implementation; its sync extension starts at line 239.
- Its `syncableFiles` implementation reads `MelonDSEmulatorBridge.shared` paths at line 270.
- `Delta/Database/Model/Human/GameSave.swift:48` enumerates GBC RTC files directly.

Impact: persistence and sync understand engine-specific file layouts. A new system with multiple saves, firmware, or directory-based storage requires changes beyond its adapter. Core Data is usable on other Apple platforms, but exposing managed objects throughout the app complicates reuse and background execution.

Recommendation: add repository boundaries using stable identifiers and immutable game descriptors. Let each system adapter describe its storage artifacts; persistence and sync should consume those descriptions. Keep existing Core Data/Harmony implementation behind adapters during migration.

### 5. Medium-high: globals make dependencies and lifecycle ownership implicit

Evidence:

- `Delta/Database/DatabaseManager.swift:49` is a singleton with a private initializer.
- `Delta/Syncing/SyncManager.swift:90` is a singleton; line 130 creates a coordinator against `DatabaseManager.shared`.
- `Cores/DeltaCore/DeltaCore/Delta.swift:29` maintains a global registry keyed by `GameType`.
- `EmulatorCore.swift:99` resolves its core from that registry instead of receiving one.
- `Cores/GPGXDeltaCore/Sources/GPGXDeltaCore/GPGX.swift:50` returns the shared native bridge; NES uses the same pattern.
- `Delta/J2ME/J2MEGameViewController.swift:20` stores session-active state on the view controller type.

Static count: 110 occurrences of `DatabaseManager.shared` across 234 app Swift files. This is an indicator of substitution cost, not proof of defects.

Impact: constructing isolated tests, sharing services across host targets, and managing multiple independent sessions become harder. Shared bridge renderer/callback assignments mean independent sessions cannot be assumed safe without checking native engine ownership.

Recommendation: inject repositories, sync access, settings, and session factories from an app composition root. If a native engine is intentionally single-session, encode that policy explicitly in session coordination; use bridge factories only where the engine supports independent instances.

### 6. Medium: registry extensibility is restricted by closed app switches

Evidence:

- `Delta/Systems/System.swift` imports every conventional core and maintains enum cases, names, icons, core lists, core lookup, type conversion, and extension detection.
- `Delta/Settings/Settings.swift:592` switches on systems for skin preference keys.
- `Delta/Settings/Cores/CoresListView.swift:39` switches on systems for settings UI.
- `Delta/Settings/Features/CustomFastForward.swift:111` switches on systems for stored options.
- `Delta/RetroAchievements/AchievementsTracker.swift:92` maps systems to achievement console IDs.
- `Delta/AppDelegate.swift:217` implements registration and release-variant filtering.

Impact: registering a core is insufficient to make a platform fully available. Metadata and policy are duplicated across features. Exhaustive switches provide compile-time reminders, but still require coordinated edits.

Recommendation: use registered system descriptors containing stable IDs, file recognition, metadata, runtime factories, storage policy, and capabilities. Keep Apple-specific icons and settings-view factories in a presentation registry. Preserve existing persisted IDs and preference keys.

### 7. Medium: large controllers and integration folders have weak enforceable boundaries

Current sizes: gameplay controller 2,980 lines; game collection controller 1,631; games controller 1,200; database manager 834; settings 686. Size alone is not a defect, but the responsibilities above demonstrate why these files are frequent change points.

`External/DeltaOperator/Sources/DeltaOperatorDelegate.swift:25` directly imports through the global database, and its save flush discovers an active gameplay controller. Its files appear in the Delta app's Sources phase at `Delta.xcodeproj/project.pbxproj:3328`.

Recommendation: extract launch coordination, save orchestration, import policy, and system configuration first. Introduce targets/packages after the dependency direction is clean; moving files alone would preserve the coupling. Operator should consume narrow library/session services if it becomes an independently reusable integration.

## Existing strengths to preserve

- Protocols for games, inputs, save states, cheats, rendering, and native bridges avoid exposing native engine internals everywhere.
- Each conventional core has a recognizable adapter and its own resources.
- Extensible raw-value `GameType` identifiers and core registration are a good foundation for descriptor-driven integration.
- Harmony already abstracts sync transports; the main concern is app/model coupling to its concrete coordination and record types.
- DeltaFeatures is an actual reusable target.
- Existing contract/fixture tests demonstrate that smaller logic seams can be tested separately.

## Recommended order of work

The following is proposed work, not implemented work.

- [ ] Introduce a system descriptor registry; migrate metadata, file recognition, and capability lookup while retaining persisted IDs.
- [ ] Add a shared session interface with DeltaCore/J2ME adapters and explicit single-session policy where required.
- [ ] Extract a launch coordinator used by library selection and deep links.
- [ ] Move vendor bridge configuration and per-system artifact discovery into adapters.
- [ ] Introduce repository, settings, and sync interfaces; inject them into extracted coordinators.
- [ ] Separate DeltaCore runtime/contracts, Apple audio/video services, and UIKit presentation into enforceable targets.
- [ ] Add focused contract tests for import/recognition, capability availability, session transitions, save artifacts, and replacement core behavior.
- [ ] Select a specific host OS and prove a minimal runtime/render/input path there before expanding full app support.

Success criterion for console extensibility: a new conventional core should need an adapter, resources, a descriptor, and composition-root registration, with no edits to shared launch, persistence, or sync orchestration. Specialized UI remains allowed through explicit presentation hooks.

Success criterion for host portability: the shared domain/session layer builds without UIKit and without directly constructing host audio/video services. Non-Apple portability additionally requires neutral contracts and replacements for Apple persistence/runtime dependencies.
