# Codebase quality upgrade plan

Status: In progress — baseline automation underway; device/runtime gates remain pending.
Created and last updated: 2026-10-14.
Basis: [Architecture review](ArchitectureReview.md), evaluated against the current working tree.

## Goal

Make Delta easier to extend, test, and maintain while preserving existing games, saves, preferences, sync behavior, and emulator performance. Prioritize adding emulated systems cleanly. Establish boundaries that support future host-platform work without committing to an unspecified port.

This plan proposes incremental changes. It does not authorize a rewrite of native emulator engines, replacement of Core Data/Harmony, or conversion of every screen to SwiftUI.

## Progress

- [x] Create and check out `refactor/codebase-quality` from local `main`, preserving working-tree changes.
- [x] Delete merged `experiment/j2me` branch locally.
- [x] Delete `experiment/j2me` branch from `origin`.
- [x] Complete the initial architecture assessment.
- [x] Draft the upgrade sequence, acceptance criteria, and verification requirements.
- [ ] Phase 0 — establish a reproducible baseline.
- [x] Phase 1 — centralize system descriptors and capabilities.
- [x] Phase 2 — extract session and launch coordination (code/build/contracts; runtime smoke gate remains open).
- [x] Phase 3 — isolate storage, import, and sync contracts (live sync gate remains open).
- [x] Phase 4 — enforce shared module boundaries and inject Apple host services (native binary split remains deferred).
- [x] Phase 5 — strengthen concurrency and diagnostics (device performance comparison remains pending).
- [ ] Phase 6 — demonstrate extension readiness and finish documentation.

Only check off a task when its acceptance criteria have passed. Update this document in the same change that completes the task. Record validation evidence and remaining limitations in the delivery log below.

## Principles

- Preserve persisted system identifiers, save paths, preference keys, and sync record/file identifiers unless an explicit migration is included.
- Keep each change small enough to review and revert independently.
- Extract one behavior through a working adapter before migrating its other callers.
- Introduce protocols at substitution boundaries; avoid an interface for every class.
- Keep native engine restrictions explicit, including single-session ownership.
- Preserve specialized capabilities such as J2ME forms and DS networking through adapters.
- Establish dependency direction before moving source files into new targets.

## Intended boundaries

Names below describe proposed responsibilities; final target names can follow repository conventions.

| Boundary | Owns | Must not depend on |
| --- | --- | --- |
| Domain/contracts | Game descriptors, stable IDs, system descriptors, capabilities, session and storage contracts | UIKit, concrete emulator bridges, Harmony records, managed objects |
| Application services | Launch coordination, import orchestration, save workflows | Concrete engines, view controllers, global database/sync services |
| Emulator adapters | Native bridge configuration, engine capabilities, artifact descriptions | App screens and app database models |
| Persistence/sync adapters | Core Data repositories, Harmony integration, file operations | Gameplay controllers and vendor bridge classes |
| Apple runtime services | Audio, graphics, controller integration, host lifecycle adapters | Library/settings screens |
| Presentation | UIKit/SwiftUI screens, presentation routes, icons, specialized configuration UI | Vendor bridge internals |
| App composition root | Concrete dependency construction, registration, release-variant policy | No restriction on assembling the above boundaries |

Domain and application services depend on contracts. Concrete adapters implement those contracts. The composition root connects them. Existing DeltaCore can remain behind an adapter until its internal host/UI split is complete.

## Phase 0 — establish a reproducible baseline

Why: the working tree contains ongoing feature changes, and the first review did not validate builds or runtime behavior.

- [x] Inventory app schemes, build configurations, supported devices, deployment targets, submodule revisions, and binary framework constraints.
- [x] Document clean-checkout setup and exact build/test commands, including required resources and local tooling.
- [x] Capture Debug arm64 Simulator build results; Release/device results remain an outstanding gate in QualityBaseline.md.
- [x] Inventory existing contract tests and fixture scripts; record how to run them and what they cover.
- [ ] Capture representative gameplay, import, save/load, J2ME launch/exit, and sync smoke-test results.
- [ ] Record dependency counts and performance measurements for the specific flows being changed.

Acceptance: another developer can reproduce setup and run the documented checks. Baseline failures are recorded and attributed before refactoring begins. Existing uncommitted work is preserved and clearly distinguished from upgrade changes.

## Phase 1 — centralize system descriptors and capabilities

Starting points: `Delta/Systems/System.swift`, `Delta/Systems/DeltaCoreProtocol+Delta.swift`, core settings, fast-forward settings, and achievements mapping.

- [x] Introduce stable system descriptors for identity, metadata, supported content recognition, runtime selection, and storage policy.
- [x] Add a registry with duplicate-ID validation and an explicit unsupported-system result.
- [x] Keep release/BETA/LITE availability in composition policy rather than scattered feature logic.
- [x] Separate presentation metadata and settings-view factories from domain descriptors.
- [x] Model optional capabilities such as save states, cheats, fast-forward, palettes, networking, and secondary cartridges.
- [x] Distinguish engine support from per-game or policy restrictions, including achievement hardcore mode.
- [x] Migrate file recognition and system metadata first; migrate remaining switches feature by feature.
- [x] Replace assumptions that every system has a Delta core with explicit runtime selection or optional capability access.

Acceptance: existing IDs and preferences still resolve correctly. Unknown systems and unsupported actions produce controlled results. A fake system can be registered and discovered without adding cases to shared metadata/recognition logic. J2ME cannot accidentally enter the failing `deltaCore` path through migrated APIs.

## Phase 2 — extract session and launch coordination

Starting points: `GameViewController`, `GameCollectionViewController`, `DeepLinkController`, and `J2MELibrary`.

- [x] Define the smallest shared session lifecycle: prepare/start, pause/resume, stop, state, and error/completion reporting.
- [x] Define legal state transitions and idempotent cleanup behavior, including failed preparation and interrupted launch.
- [x] Wrap existing DeltaCore and J2ME behavior in separate adapters.
- [x] Move active-session ownership out of view controller static state.
- [x] Make single-session limits explicit for engines that share native bridge state.
- [x] Extract shared launch preflight with injected repository, save-readiness, and runtime-validation dependencies; runtime lifecycle drivers receive injected callbacks.
- [x] Route library selection and deep links through the same validation and preparation workflow.
- [x] Move palette, DS/DSi, JIT, networking, secondary cartridge, and graphics configuration into adapters.
- [x] Extract save orchestration from gameplay controllers while keeping presentation in the UI layer.

Acceptance: launch coordination is testable without a view controller or real database. Normal console and J2ME launch, failure, pause, exit, and save completion paths retain behavior. Unsupported capabilities are handled explicitly. Native bridges are not treated as independently instantiable unless verified.

## Phase 3 — isolate storage, import, and sync contracts

Starting points: `DatabaseManager`, `Game`, `GameSave`, `SyncManager`, and J2ME save/import helpers.

- [x] Introduce immutable game descriptors and stable IDs for application-service inputs and outputs.
- [x] Add a narrow repository contract; keep Core Data objects inside persistence-owned execution boundaries.
- [x] Extract import recognition and validation into per-system handlers behind common orchestration.
- [x] Define artifact descriptions for ROMs, normal saves, RTC, firmware, save states, and directory-based runtime data.
- [x] Move concrete core file discovery into adapters; preserve existing artifact identifiers and paths.
- [x] Add a save-readiness interface so launch logic does not inspect Harmony records.
- [x] Keep Harmony/Core Data integration behind repository/sync adapters, including any managed-model conformance needed internally.
- [x] Consolidate file replacement and deletion workflows with explicit ownership, validation, and failure recovery.
- [x] Preserve queue confinement and avoid passing live managed objects across asynchronous session boundaries.

Acceptance: extracted launch/import/save services do not import Harmony or concrete emulator modules. Existing library and save fixtures remain compatible. Import failure, partial writes, deletion, and sync conflict/download behavior do not silently lose or overwrite user data.

## Phase 4 — enforce module boundaries and separate host services

Prerequisite: the contracts and adapters from earlier phases work in the existing app target.

- [x] Create enforceable domain/application targets and move only dependency-clean code into them.
- [x] Inject audio/video services into runtime construction; retain existing render paths during migration.
- [x] Move `GameView` ownership and attachment into presentation adapters.
- [x] Keep Apple audio/video implementations behind the independently compiled shared session contracts; retain the native backend compatibility API.
- [ ] Split native audio/video into separate binary targets and define neutral media descriptors when a host port is selected (not implemented).
- [x] Encapsulate Objective-C/native bridges behind adapters; isolate associated-object state where portability requires it.
- [x] Make DeltaOperator consume narrow library and active-session services instead of discovering gameplay controllers.
- [x] Verify preview dependencies; align its minimum deployment target. Extracted services use injectable test implementations.
- [x] Add dependency checks preventing forbidden imports and module cycles.
- [x] Document the retained role of Xcode projects, CocoaPods, SPM, submodules, and binary frameworks; consolidate only where it removes a demonstrated problem.

Acceptance: domain/application targets compile without UIKit, concrete emulator bridges, or managed models. Presentation no longer imports vendor bridges in migrated flows. Module checks enforce the agreed direction. App resources and native linking still work in supported configurations.

## Phase 5 — strengthen concurrency, diagnostics, and performance verification

- [x] Document main-actor presentation, repository queue ownership, native engine threads, render callbacks, and shutdown ordering.
- [x] Audit `@unchecked Sendable` in changed boundaries and justify each retained declaration.
- [x] Introduce cancellation and completion ownership for extracted asynchronous operations.
- [x] Define typed errors for unsupported content, unavailable capabilities, missing artifacts, unavailable saves, and runtime failure.
- [x] Use consistent diagnostic categories and operation identifiers in changed flows, avoiding personal game paths or credentials in logs.
- [x] Add deterministic tests for invalid state transitions, interrupted launch, sync readiness, save failure, and session cleanup.
- [ ] Measure launch latency, frame pacing, audio stability, and memory against the unrecorded Phase 0 device baseline (still pending).
- [x] Introduce formatting/static checks incrementally in touched code; record legacy exceptions instead of creating unrelated formatting churn.

Acceptance: changed asynchronous flows have explicit ownership and failure behavior. Any performance regression is investigated against measured baselines before rollout. Validation does not claim thread safety solely because a type is marked Sendable.

## Phase 6 — prove extension readiness

- [ ] Add a test-only system adapter proving discovery, launch preparation, capability lookup, and artifact enumeration without editing shared orchestration.
- [ ] Verify switching or substituting a core preserves configuration and storage semantics.
- [ ] Document the steps required to add a conventional console and a runtime with specialized UI.
- [ ] Reassess coupling and extensibility using the same rubric as the architecture review.
- [ ] If a host port is selected, document its constraints and prove a minimal render/audio/input/session path before promising full app support.
- [ ] Update the architecture review to describe implemented boundaries and remaining coupling.

Acceptance: adding a conventional system needs an adapter, resources, descriptor, and composition registration, with no edits to shared launch/persistence/sync orchestration. A host-port result is reported only for destinations actually built and exercised.

## Validation and delivery rules

- [ ] For each implementation PR, record changed behavior, preserved contracts, tests run, and remaining limitations.
- [ ] Add tests for meaningful contracts and failure cases affected by the change; avoid tests that merely mirror implementation details.
- [ ] Build affected modules and app configurations after dependency, target, resource, or native-linking changes.
- [ ] Run appropriate existing fixture/contract checks after storage, save-state, artwork, import, or sync changes.
- [ ] Smoke-test affected user flows on a suitable simulator/device; use real devices for runtime claims that a simulator cannot establish.
- [ ] Keep a revert path for each extraction; schema/file-format migrations require a separately documented recovery strategy.

Suggested first implementation PR: add descriptors for one conventional system and J2ME, preserve existing identifiers, migrate recognition/metadata through compatibility adapters, and prove registry/capability behavior. Expand migration only after that seam works.

## Success measures

| Measure | Baseline | Completion evidence |
| --- | --- | --- |
| Shared launch paths | Console/J2ME branching across controllers and deep links | One coordinator with distinct runtime adapters |
| Core configuration in UI | Concrete GBC/MelonDS bridge casts | Configuration performed through adapters/capabilities |
| Dependency substitution | 110 textual `DatabaseManager.shared` occurrences in the initial audit | Zero global service lookups in extracted application services; document remaining UI lookups |
| Per-system storage knowledge | BIOS/RTC/J2ME details in database/model code | Artifact policy in adapters with compatibility fixtures |
| Enforced boundaries | Most features are folders inside Delta | Domain/application compilation and forbidden-import checks pass |
| Host portability | Static review only; no port verified | A specified host path is built and exercised if included in scope |

Counts are baseline indicators, not stand-alone quality targets. Reduced file size or singleton counts do not establish correct architecture without the behavioral evidence above.

## Delivery log

| Date | Completed work | Validation | Remaining work |
| --- | --- | --- | --- |
| 2026-10-14 | Architecture assessment and upgrade draft | Static source/target inspection; plan reviewed for ordering and acceptance criteria | All implementation phases; build/runtime baseline |
| 2026-10-14 | Check out `refactor/codebase-quality`; remove local and remote `experiment/j2me` | No commits unique to the experiment branch relative to local main; Git confirmed branch creation and both deletions | Upgrade implementation; new branch has not been pushed |

Baseline evidence and outstanding gates: [QualityBaseline.md](QualityBaseline.md).

| 2026-10-14 | Phase 0 automation delivered on `quality/phase-0-baseline` | Debug arm64 Simulator build, six sync contracts, artwork/replacement/snapshot/audio fixtures, schema migrations, 16 Nuke checks passed | Runtime/device/performance baseline remains open; Phase 0 is not fully accepted |

| 2026-10-14 | Phase 1 descriptor/capability seam | Ten SwiftPM contracts and existing fixture suite passed; full Debug arm64 Simulator build passed | Legacy System enum remains a compatibility facade; runtime and storage adapters follow in subsequent phases |

| 2026-10-14 | Phase 2 launch preflight, session ownership/drivers, vendor configuration and main-save extraction | Nineteen SwiftPM contracts and existing fixtures passed; Debug arm64 Simulator build passed | UIKit continues to own console presentation and multi-scene prompts; gameplay/save completion smoke tests remain pending |

| 2026-10-14 | Phase 3 storage artifacts, metadata inspectors, sidecar/replacement adapters and stable-ID runtime persistence | Twenty-five SwiftPM contracts, full fixture/schema/Nuke integration suite and Debug arm64 Simulator build passed | Existing Core Data/Harmony implementations remain behind app adapters; live cloud behavior still requires signed devices |

| 2026-10-14 | Phase 4 linked modules, dependency checks, native rendering injection, Operator delegate service and preview alignment | Twenty-seven SwiftPM tests, rendering adapter checks, existing fixture suite, full app and preview Debug arm64 Simulator builds passed | Native backend remains Apple-only; Operator observer UI glue and physical hardware verification remain |

Current boundaries: [ModuleBoundaries.md](ModuleBoundaries.md).

| 2026-10-14 | Phase 5 cancellation/exactly-once preparation, immutable native-worker request, private diagnostics and actor-owned JIT transitions | Twenty-nine SwiftPM tests and fixture suite passed; shared modules passed complete concurrency checking with warnings as errors; Debug arm64 Simulator build passed | No new unchecked Sendable declarations; performance/device comparison remains pending |

Execution contracts: [ConcurrencyAndValidation.md](ConcurrencyAndValidation.md).
