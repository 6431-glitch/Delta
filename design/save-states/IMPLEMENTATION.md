# Compact save-state layouts

- [x] Add adaptive Grid and full-width List layouts with a persistent layout preference.
- [x] Provide a navigation layout toggle and explicit Grid/List menu choices.
- [x] Use compact rounded material cards, small list thumbnails, left-aligned labels, and restrained section spacing.
- [x] Remove the large navigation title and size cards from the actual available collection width.
- [x] Retain automatic, quick, general, and locked sections, compatibility filtering, sorting, preview/context menus, import/export, and save/load delegates.
- [x] Preserve selected save states when changing layout during batch editing.
- [x] Support adaptive grid columns and larger rows for accessibility text sizes.
- [x] Verify final arm64 build and whitespace checks.
- [ ] Visually inspect populated Grid/List screens and verify save/load, batch editing, rotation, and Dynamic Type on a running device.

The save-state screen uses a standard collection flow layout rather than the library's equal-spacing grid layout. Its compact cell presentation is opt-in; other grid cells keep their original constraints. Existing save-state action/delegate code is reused. The disposable QA Simulator was shut down during this task, so populated-screen visual verification remains pending.

## GBC pause-menu load crash — 2026-10-12

- [x] Retrieve the latest Delta crash report from the paired iPhone without changing app data.
- [x] Identify `UICollectionView _Bug_Detected_In_Client_Of_UICollectionView_Invalid_Batch_Updates` with Roxas `UICollectionView(CellContent) endUpdates` delayed post-move reloads in the failing stack.
- [x] Give the save-state screen ownership of its fetched-results delegate before assigning it to the Roxas data source. Refresh the completed snapshot rather than scheduling move animations and delayed item reloads.
- [x] Invalidate changed state thumbnails and preserve batch selection by managed-object ID across moves, section changes and deletions.
- [x] Verify a successful arm64 Simulator build and whitespace checks.
- [x] Run `python3 Tests/SaveStateSnapshot/run.py`: production delegate callbacks tested with real Core Data, autosave moves, cache eviction, selection restoration, section insert/delete, informational-section offset and 20 rapid rotations.
- [ ] Retry GBC save-state loading through the pause menu on the user's device with the updated build.

Evidence: latest report `Delta-2026-10-12-115310.ips`, copied to `/private/tmp/Delta-save-state-crash.ips` for analysis. Crash is a UIKit invalid-batch-update assertion on the main thread, not an observed Gambatte native load failure. The targeted change removes delayed positional reloads from this screen only; it does not change emulator state formats or stored save-state bytes. Host regression checks use a collection-view spy and therefore do not replace the pending physical-device playback check. No Simulator was booted during this investigation.

## Cross-platform follow-up — 2026-10-12

- [x] Confirm GBC pause-menu loading works on the user's device (user reported success).
- [x] Trace shared pause-menu save-state handling and native load bridges for GBA, NES, SNES, N64, DS and Genesis.
- [x] Run the production fetched-results delegate regression suite against isolated game/core/version fixtures for GBC, GBA, NES, SNES, N64, DS and Genesis. All seven shared-screen fixture runs passed, including 20 rapid rotations each, game/core/version exclusions, compatibility membership changes, selection/cache updates, and unloaded-view behavior.
- [x] Remove the Library load delegate's forced index-path lookup: Aurora can select a game outside the hidden grid's current platform. Launch with the explicit selected game, preserving the pending save state.
- [x] Build the full app successfully for arm64 Simulator and pass whitespace checks.
- [ ] Exercise actual emulator save/load round trips on GBA, NES, SNES, N64, DS and Genesis with valid game files.

Scope of evidence: the cross-platform automated fixtures test the shared Core Data/UI delegate, not emulator serialization. Source review confirms each console uses the common screen and its own existing native state loader. J2ME runs outside DeltaCore and persists Java game data (RMS) and backups rather than using this console save-state screen. No Simulator was booted, so native playback on the other cores has not been claimed or marked complete. Build log: `/private/tmp/DeltaSaveStatePlatforms-build.log`.

## GBA delete-then-resume native crash — 2026-10-14

- [x] Identify the screenshot's `thumbExecute` / `THUMB_PREFETCH_NEXT` memory-access crash during resume; the user confirmed deleting a save state immediately before resuming.
- [x] Trace the context-menu preview lifecycle: it creates a separate live core, stops the paused gameplay core, then asynchronously stops/deallocates the preview after dismissal. Console native bridges share core memory, allowing late preview teardown to interfere with resumed gameplay.
- [x] Replace save-state context-menu live previews with stored screenshots, retaining thumbnail previews and explicit load actions.
- [x] Remove save-state-browser stop/restart/temporary-state ownership transfers; browsing and deletion leave the gameplay core paused and intact.
- [x] Use stable managed-object URI identifiers for preview commits and highlighting so deleted/moved rows cannot target another state.
- [x] Run all seven platform fixtures in `Tests/SaveStateSnapshot/run.py`; snapshot updates, deletion/selection handling and cache refresh passed.
- [x] Complete the final arm64 Simulator build (`/private/tmp/DeltaGBADeleteResume-build.log`).
- [ ] User to repeat GBA delete-state → Continue on device.

Evidence supports a preview/gameplay ownership race; it is not a reproduced device crash. No new crash report was available from the phone (the process was paused in Xcode). The screenshot's GBA program counter points into normal ROM space, while the host read address faults; logs show preview battery-save copy/restore activity. The fix removes that competing native runtime from the save-state screen across console platforms, without changing saved state bytes, the ROM or the user's battery save. Library game previews remain unchanged. The audio/glass warnings are separate diagnostics and were not established as the cause of this CPU crash. No HD J2ME gameplay was run.
