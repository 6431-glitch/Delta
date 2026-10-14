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
- [ ] Phase 1 — centralize system descriptors and capabilities.
- [ ] Phase 2 — extract session and launch coordination.
- [ ] Phase 3 — isolate storage, import, and sync contracts.
- [ ] Phase 4 — enforce module boundaries and separate host services.
- [ ] Phase 5 — strengthen concurrency, diagnostics, and performance verification.
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

- [ ] Introduce stable system descriptors for identity, metadata, supported content recognition, runtime selection, and storage policy.
- [ ] Add a registry with duplicate-ID validation and an explicit unsupported-system result.
- [ ] Keep release/BETA/LITE availability in composition policy rather than scattered feature logic.
- [ ] Separate presentation metadata and settings-view factories from domain descriptors.
- [ ] Model optional capabilities such as save states, cheats, fast-forward, palettes, networking, and secondary cartridges.
- [ ] Distinguish engine support from per-game or policy restrictions, including achievement hardcore mode.
- [ ] Migrate file recognition and system metadata first; migrate remaining switches feature by feature.
- [ ] Replace assumptions that every system has a Delta core with explicit runtime selection or optional capability access.

Acceptance: existing IDs and preferences still resolve correctly. Unknown systems and unsupported actions produce controlled results. A fake system can be registered and discovered without adding cases to shared metadata/recognition logic. J2ME cannot accidentally enter the failing `deltaCore` path through migrated APIs.

## Phase 2 — extract session and launch coordination

Starting points: `GameViewController`, `GameCollectionViewController`, `DeepLinkController`, and `J2MELibrary`.

- [ ] Define the smallest shared session lifecycle: prepare/start, pause/resume, stop, state, and error/completion reporting.
- [ ] Define legal state transitions and idempotent cleanup behavior, including failed preparation and interrupted launch.
- [ ] Wrap existing DeltaCore and J2ME behavior in separate adapters.
- [ ] Move active-session ownership out of view controller static state.
- [ ] Make single-session limits explicit for engines that share native bridge state.
- [ ] Extract a launch coordinator with injected repository, save-readiness, configuration, and session-factory dependencies.
- [ ] Route library selection and deep links through the same validation and preparation workflow.
- [ ] Move palette, DS/DSi, JIT, networking, secondary cartridge, and graphics configuration into adapters.
- [ ] Extract save orchestration from gameplay controllers while keeping presentation in the UI layer.

Acceptance: launch coordination is testable without a view controller or real database. Normal console and J2ME launch, failure, pause, exit, and save completion paths retain behavior. Unsupported capabilities are handled explicitly. Native bridges are not treated as independently instantiable unless verified.

## Phase 3 — isolate storage, import, and sync contracts

Starting points: `DatabaseManager`, `Game`, `GameSave`, `SyncManager`, and J2ME save/import helpers.

- [ ] Introduce immutable game descriptors and stable IDs for application-service inputs and outputs.
- [ ] Add a narrow repository contract; keep Core Data objects inside persistence-owned execution boundaries.
- [ ] Extract import recognition and validation into per-system handlers behind common orchestration.
- [ ] Define artifact descriptions for ROMs, normal saves, RTC, firmware, save states, and directory-based runtime data.
- [ ] Move concrete core file discovery into adapters; preserve existing artifact identifiers and paths.
- [ ] Add a save-readiness interface so launch logic does not inspect Harmony records.
- [ ] Keep Harmony/Core Data integration behind repository/sync adapters, including any managed-model conformance needed internally.
- [ ] Consolidate file replacement and deletion workflows with explicit ownership, validation, and failure recovery.
- [ ] Preserve queue confinement and avoid passing live managed objects across asynchronous session boundaries.

Acceptance: extracted launch/import/save services do not import Harmony or concrete emulator modules. Existing library and save fixtures remain compatible. Import failure, partial writes, deletion, and sync conflict/download behavior do not silently lose or overwrite user data.

## Phase 4 — enforce module boundaries and separate host services

Prerequisite: the contracts and adapters from earlier phases work in the existing app target.

- [ ] Create enforceable domain/application targets and move only dependency-clean code into them.
- [ ] Inject audio/video services into runtime construction; retain existing render paths during migration.
- [ ] Move `GameView` ownership and attachment into presentation adapters.
- [ ] Split Apple audio/video implementations from shared session contracts.
- [ ] Define neutral audio/video descriptors where required by the selected portability scope.
- [ ] Encapsulate Objective-C/native bridges behind adapters; isolate associated-object state where portability requires it.
- [ ] Make DeltaOperator consume narrow library and active-session services instead of discovering gameplay controllers.
- [ ] Update preview dependencies to use injectable implementations for migrated services.
- [ ] Add dependency checks preventing forbidden imports and module cycles.
- [ ] Document the retained role of Xcode projects, CocoaPods, SPM, submodules, and binary frameworks; consolidate only where it removes a demonstrated problem.

Acceptance: domain/application targets compile without UIKit, concrete emulator bridges, or managed models. Presentation no longer imports vendor bridges in migrated flows. Module checks enforce the agreed direction. App resources and native linking still work in supported configurations.

## Phase 5 — strengthen concurrency, diagnostics, and performance verification

- [ ] Document main-actor presentation, repository queue ownership, native engine threads, render callbacks, and shutdown ordering.
- [ ] Audit `@unchecked Sendable` in changed boundaries and justify each retained declaration.
- [ ] Introduce cancellation and completion ownership for extracted asynchronous operations.
- [ ] Define typed errors for unsupported content, unavailable capabilities, missing artifacts, unavailable saves, and runtime failure.
- [ ] Use consistent diagnostic categories and operation identifiers in changed flows, avoiding personal game paths or credentials in logs.
- [ ] Add deterministic tests for invalid state transitions, interrupted launch, sync readiness, save failure, and session cleanup.
- [ ] Measure launch latency, frame pacing, audio stability, and memory for representative affected engines against Phase 0.
- [ ] Introduce formatting/static checks incrementally in touched code; record legacy exceptions instead of creating unrelated formatting churn.

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
