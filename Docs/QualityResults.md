# Quality upgrade results

Cleanup follow-up 2026-10-28: sender/receiver temporary-file ownership, cancelled/failed operation cleanup, interrupted-workspace cleanup and preserved recovery data are covered in [GameTransfer.md](GameTransfer.md). All 39 normal contracts and the simulator round trip with cleanup assertions pass.

Feature follow-up 2026-10-27: complete per-game Transfer export/restore is documented in [GameTransfer.md](GameTransfer.md). The normal contract suite now has 36 tests, including six transfer test groups; actual-model console/Java round trips and the transfer UI/document-handler/recovery flow pass.

Updated 2026-10-14. Integration branch: `refactor/codebase-quality`.

Follow-up 2026-10-15: fresh Debug build and NES/Java/Java RMS relaunch smoke checks pass on the user's existing iPhone 17 Pro, iOS 26.5. The device and its data were preserved. See [SimulatorValidation.md](SimulatorValidation.md) for evidence and remaining validation limits.

## Delivered code

- [x] Phase 0: repeatable validation runner, baseline inventory, parameterized schema fixtures, and preserved feature checkpoint.
- [x] Phase 1: validated system descriptors, content recognition, optional core lookup, and capability/policy separation.
- [x] Phase 2: shared launch preflight, explicit Java ownership, lifecycle drivers, native configuration adapter, and main-save orchestration extraction.
- [x] Phase 3: neutral storage artifacts, import/sidecar/replacement adapters, context-confined readiness repository, and stable-ID runtime persistence.
- [x] Phase 4: separately linked domain/application packages, dependency checks, rendering injection/view attachment extraction, Operator delegate service, and preview-target repair.
- [x] Phase 5: cancellation/exactly-once preparation, Sendable Java worker request, private diagnostics, actor-owned UI/JIT transitions, and concurrency documentation. Java save callbacks also return a typed missing-game failure instead of silently dropping completion.
- [x] Phase 6: descriptor-backed System struct, generic settings/control fallbacks, extension fixture, injectable audio interface/core-construction hook, and disposable simulator smoke runner.

Each phase has a dedicated `quality/phase-N-*` branch and is merged locally into the integration branch. DeltaCore and DeltaOperator changes use their own local phase/integration branches; the parent records their commits. Existing feature work was preserved separately in checkpoint `c7f11f9`. Nothing has been pushed.

## Verification

- [x] Thirty SwiftPM contracts pass, including the idle-resume regression found during real J2ME smoke testing.
- [x] Complete concurrency checking with warnings as errors passes for DeltaApplication/DeltaDomain.
- [x] Boundary checks pass; migrated gameplay/library presentation imports no concrete core modules.
- [x] Artwork assignment/layout, transactional replacement, all seven console save-state fixtures, Java audio handles, and renderer-interface/focus/attachment checks pass.
- [x] Actual compiled v12→v13 artwork and v13→v14 save-state schema migration fixtures pass.
- [x] Sixteen Nuke HTTP/cache integration checks pass.
- [x] Full app Debug and Release arm64 Simulator builds pass.
- [x] DeltaPreviews Debug arm64 Simulator build passes after deployment-target alignment.
- [x] Original NES fixture: import, native rendered frame, pause/resume, save/load and stop pass with injected silent audio.
- [x] Original Java fixture: import, rendered frame, native pause/resume, shutdown and save checkpoint pass.
- [x] Java relaunch in the same disposable simulator preserves/updates RMS archive data; the rendered fixture's launch counter increments.
- [x] Both missing public NES/MelonDS skins are hydrated, with pinned SHA-256, byte count and ZIP CRC verified.
- [ ] Audible playback and physical audio/controller/Operator hardware checks.
- [ ] Comparable device launch/frame-pacing/memory baseline and regression measurement.
- [ ] Signed device build and authenticated cloud upload/download/conflict validation.
- [ ] Native audio/video binary separation and a specific host-OS port (not selected).

The smoke runner deletes only the simulator it creates. Frames, reports and logs remain under `.build/quality-smoke`; these generated artifacts are ignored by Git. The console silent backend is opt-in and compiled only for Debug. Production/default audio remains AudioManager.

## Material limits and compatibility

The initial simulator run stalled in AVAudioSession activation. Silent audio isolates console execution/storage checks from that host audio issue; it does not prove audible playback. Live cloud/device behavior is not covered by local contracts.

EmulatorCore.audioManager is now an EmulatorAudioManaging interface. Existing app callers and all source frameworks build, but external clients requiring the concrete AudioManager type must cast/rebuild. Native save-state compatibility between different engines still requires engine-specific validation; the replacement-driver fixture proves shared identity/artifact behavior only.

The Git LFS client is absent on this host. `Scripts/Quality/resources.py --hydrate` restored the two public skins from their pinned identities without changing Git configuration. NES/MelonDS working trees show these hydrated files as modified until a normal LFS clean filter is installed; those binary files were not committed. Original pointer backups are in `.build/quality-lfs-pointers`. Existing GBA untracked files and `output/` remain preserved.

Large legacy UI/settings files, many app-level singleton lookups, Operator observer scene glue, and Apple-specific native contracts remain. Extracted domain/application services contain no database/sync singleton lookups or managed models. The upgrade improves extension seams rather than asserting that every legacy feature is fully modular.

## Reproduce

```sh
python3 Scripts/Quality/resources.py --hydrate
python3 Scripts/Quality/check.py \
  --model .build/quality-ios/Build/Products/Debug-iphonesimulator/Delta.app/Delta.momd \
  --nuke .build/quality-ios/SourcePackages/checkouts/Nuke
python3 Scripts/Quality/smoke.py \
  --app .build/quality-ios/Build/Products/Debug-iphonesimulator/Delta.app
```

Build commands and remaining baseline/device gates are in QualityBaseline.md. Module responsibilities are in ModuleBoundaries.md; extension instructions are in AddingSystems.md.
