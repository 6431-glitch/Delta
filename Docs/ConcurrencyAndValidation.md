# Concurrency, lifecycle, and validation contracts

Updated 2026-10-14.

## Execution ownership

- Presentation, launch preflight, session registration, leases, and asynchronous preparation completion are MainActor-owned.
- Launch repositories return immutable descriptors. Managed models remain in app adapters and are fetched on their contexts.
- JavaRuntimeAdapter receives an immutable Sendable request before dispatch. The interpreter worker does not read or mutate controller fields. Its result returns to the main queue before UI state changes.
- Java save restore/checkpoint work stays on the existing serial save queue. Managed metadata writes use their context, and completion returns to the main queue.
- JIT reconfiguration captures the active core and performs UI/session transitions together on the main queue, avoiding the former background reads of a mutable gameplay controller.
- Audio/video and native frame callbacks retain their established backend threads. Rendering/input service extraction does not change frame scheduling or claim the native engine is Sendable.

## Cancellation and shutdown

LaunchPreparation delivers one terminal result. Cancellation releases a reserved Java lease and prevents a late restore callback from presenting a game. Duplicate or reentrant callbacks do not deliver twice. Leaving the library launch surface cancels pending Java preparation; successful preparation is cleared before gameplay presentation begins.

A lease token can only release its matching reservation. Native ownership persists through runtime shutdown, save checkpoint, and foreground dismissal. The worker requests stop, wakes paused Java threads, exits/destroys the VM, and then completes saves. Backgrounded UI waits for foreground before dismissal.

A save checkpoint failure is surfaced and leaves the session terminal; it does not report a successful cloud upload. Local checkpoint completion and authenticated remote sync are separate events.

## Sendable audit

| Type | Status | Reason |
| --- | --- | --- |
| Domain descriptors/artifacts and Java runtime request | Checked value conformance | Strings, URLs, numbers, enums and value dictionaries only |
| Lifecycle/preparation/session registry | MainActor isolation | Mutable ownership has one executor |
| Operator delegate/library adapter | Checked Sendable | Immutable service dependency/stateless adapter; context access explicitly scheduled |
| DatabaseManager | Existing `@unchecked Sendable` retained | Core Data/Roxas inheritance and legacy API; accesses still require context queue discipline. Contract tests cover changed sync callback boundaries, not every database caller. |
| Native emulator bridges/audio/video | No new Sendable promise | Existing thread/lock contracts remain backend-specific |

No new unchecked Sendable declarations were added to extracted code.

## Diagnostics

Changed launch/save/JIT flows use the EmulationLifecycle unified-log category and random operation IDs. Detailed error descriptions are private. Events do not include personal ROM paths, game titles, or credentials. Existing user-exported Java diagnostics remain local artifacts and are not transmitted.

## Automated gates

- [x] `Scripts/Quality/boundaries.py`: shared-module imports/global types and migrated presentation.
- [x] SwiftPM contracts: registration, capabilities, launch/import failure, storage identity, session lifecycle, weak registry and cancellation/exactly-once completion.
- [x] Existing artwork/replacement/schema/save-state/J2ME audio/Nuke checks retain their dedicated fixture runners.
- [x] Neutral modules build under complete concurrency checking with warnings as errors.
- [ ] Debug and Release arm64 Simulator builds after final integration.
- [ ] Runtime smoke validation on original test fixtures.
- [ ] Physical performance/audio/controller and authenticated cloud/hardware verification.

The remaining device gates are explicit. No measured performance regression or improvement is claimed until comparable fixture/device measurements exist.
