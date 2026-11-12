# Adding an emulated system

Updated 2026-10-14. These steps describe the implemented descriptor/module boundaries. They do not establish native host-OS portability.

## Conventional console checklist

- [ ] Add an engine adapter implementing DeltaCoreProtocol and EmulatorBridging, with a stable GameType and core identifier.
- [ ] Supply its native build target, framework dependencies, resource bundle, controller skin, and Standard.deltamapping.
- [ ] Add a SystemDescriptor at composition with stable ID/preference key, names/year, content extensions, runtime kind, and accurate capabilities.
- [ ] Extend `System.registry` composition with the descriptor. System is a struct; no enum case or exhaustive UI switches are needed.
- [ ] Register the concrete core in AppDelegate under the intended release/BETA/LITE policy, or add its factory to the System composition lookup before registration.
- [ ] Add an import inspector only if content needs metadata/validation beyond the ordinary file route.
- [ ] Add artifact/configuration policy in an adapter if the system needs firmware, multiple saves, or nonstandard native settings. Retain existing sync identifiers when replacing an implementation.
- [ ] Optionally register specialized icons/settings/controller ordering. Generic icons/core info/default mapping fallbacks work without these entries.
- [ ] Add capability, import, artifact and session contract tests; then build and smoke-test actual gameplay/save behavior.

Shared LaunchCoordinator, ImportCoordinator, StorageArtifactPolicy, and lifecycle algorithms should not need system-specific branches. Composition and adapter policies are the extension points. Current built-in metadata remains in BuiltInSystems for compatibility, and per-core fast-forward/achievement tuning remains optional app policy with safe defaults.

## Runtime with specialized UI

- [ ] Describe its content and real capabilities; do not claim VM snapshots or fast-forward unless implemented.
- [ ] Implement EmulationSession or use CallbackEmulationSession to adapt asynchronous native start/pause/stop/completion.
- [ ] Keep native process-global ownership explicit with SessionOwnership leases.
- [ ] Use shared launch preflight and stable-ID repositories before native/UI creation.
- [ ] Use LaunchPreparation for asynchronous restore so cancellation and duplicate completion cannot present a stale launch.
- [ ] Keep forms, phone commands, touch surfaces, and other specialized UI inside its presentation adapter.
- [ ] Describe save archives/directories and expose save readiness through app persistence/sync adapters.
- [ ] Deliver native results to MainActor before changing UI/session state; transfer value snapshots to worker queues.
- [ ] Retain the lease until runtime shutdown and checkpoint completion, then unregister/release ownership.

J2ME is the working reference, using JavaRuntimeAdapter, JavaGamePersistenceAdapter, and its specialized controller. A third runtime family still needs its own presentation/composition route; that is not automatic runtime plug-in loading.

## Replacing an existing core

Keep the system/game/save IDs and storage layout stable. Revisit native settings, supported capabilities, artifact policy, save-state core identifier/version, and any core-specific compatibility migration. A raw SRAM save and a native save-state snapshot have different compatibility requirements; unit tests do not prove binary snapshot compatibility between engines.

The additional-system fixture in ExtensionReadinessTests exercises registration, import, preflight, capability lookup, driver substitution, and stable artifact identity through unchanged shared services. Native replacement requires engine-specific fixture validation.

## Validation commands

```sh
python3 Scripts/Quality/check.py
python3 Scripts/Quality/boundaries.py
python3 Scripts/Quality/resources.py
python3 Scripts/Quality/smoke.py \
  --app .build/quality-ios/Build/Products/Debug-iphonesimulator/Delta.app
```

The smoke runner generates an original NES mapper-0 ROM and compiles the repository's original Java MIDlet. It creates/deletes its own iOS 26.5 simulator; it does not use a personal game library. Debug-only smoke hooks are enabled only by explicit test environment variables. Console smoke uses silent injected audio; it is not audible playback validation. Java is launched twice to check persistent RMS archive restoration.
