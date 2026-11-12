# Module boundaries and composition

Updated 2026-10-14.

## Enforced boundaries

`DeltaDomain` imports Foundation only. It owns system/capability descriptions, storage artifacts, session contracts, lifecycle transitions, and exclusive ownership tokens.

`DeltaApplication` imports Foundation and DeltaDomain only. It owns launch preflight, import inspection dispatch, callback-based session lifecycle, and the weak active-session registry. Dependencies enter through protocols or initializer callbacks; these modules do not resolve database/sync singletons.

The iOS app links both as local SwiftPM products from the root package. Their sources are not also compiled into the app target. `Scripts/Quality/boundaries.py` checks imports, forbidden managed/UI/global types, and concrete core imports in migrated presentation. SwiftPM's dependency graph enforces the one-way module relationship.

App adapters under `Delta/Emulation/Adapters` implement Core Data/Harmony repositories, Java metadata/persistence, native configuration/artifact lookup, and Operator library integration. System is now a descriptor-backed struct with generic fallbacks rather than a closed enum. Existing screens can still use legacy services while migrations proceed; the boundary check is deliberately scoped to extracted services and migrated presentation.

## Apple backend compatibility

DeltaCore remains the Apple backend. `EmulatorRenderingServices` injects audio/video construction and input-focus policy into `EmulatorCore`. Default factories preserve the previous AudioManager, VideoManager, rendering options, and keyboard-focus rules.

`EmulatorCore+Presentation.swift` owns the public GameView attachment facade. VideoManager's weak view collection is now the single source of attachment state; EmulatorCore no longer keeps a duplicate collection or inspects scene/window properties in its input loop.

EmulatorCore.audioManager now exposes EmulatorAudioManaging rather than the concrete class; AudioManager is the default implementation. Common app callers compile against the interface, but clients requiring a concrete AudioManager must cast explicitly and rebuild. The controller has an overridable construction hook so hosts/tests can inject services. AVAudioFormat remains in the Apple backend API. This extraction does **not** make the native framework portable outside Apple platforms or put audio/video into separate binary targets. A host port would need further backend separation and neutral media descriptors. No host port is selected in this upgrade.

## Operator and previews

The Operator delegate receives an `OperatorLibraryService`; it no longer imports managed models or locates gameplay controllers. The app's stateless OperatorLibraryAdapter confines database access and resolves save flushing through the weak active-session registry.

Operator's observer/toast/scene-navigation sources remain app UI integration and still use scene lookup. They are not a standalone cross-platform module. The observer's hardware behavior is retained rather than rewritten without a physical-device validation path.

DeltaPreviews retains its existing lightweight mocks. Its deployment target is aligned to the app/DeltaFeatures minimum of iOS 17.4; the previously mismatched iOS 14 target failed compilation against DeltaFeatures. Its Debug arm64 Simulator build now passes.

## Build mechanisms

- SwiftPM: local neutral modules and contract tests; existing remote app products stay pinned.
- Xcode projects: app and native Apple emulator adapters/engines.
- CocoaPods: existing Roxas/Harmony/UI/database dependencies.
- Submodules: engine sources and Operator integration; quality changes have their own local phase/integration branches.
- Binary OperatorKit: iOS/device and Simulator slices only.

No broad dependency-manager migration is necessary for these boundaries. Submodule commits and parent gitlinks must be published together if this local work is later pushed; they have not been pushed by this task.

## Validation

- [x] Domain/application contracts compile and pass on macOS.
- [x] Full app links both products in the Debug arm64 Simulator build.
- [x] Dependency checks pass.
- [x] Rendering construction/input focus/attachment adapter checks pass using host doubles.
- [x] Active-session registry tests cover weak ownership, state filtering, and stale unregister tokens.
- [x] Preview framework builds after minimum-target alignment.
- [ ] Physical audio/video/controller/Operator hardware validation.
- [ ] Native backend binary separation for a future selected host port.
