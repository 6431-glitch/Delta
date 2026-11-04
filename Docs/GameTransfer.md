# Complete game transfer — 2026-10-27

## Import failure investigation — 2026-11-04

- [x] Allow a game whose content was replaced while retaining its original game identifier. Every archive file still requires its declared size, ZIP CRC, and SHA-256 to match.
- [x] Log export staging, archive verification, manifest validation, game checks, restore progress and failures under the `Transfer` category. Logs include stage, item number, counts, sizes, error domain and code; they do not include game names or file contents.
- [x] Verify a complete multi-game restore with a replaced ROM and tampered-payload rejection on Simulator.
- [x] Verify successful and rejected transfers appear in the same OSLogStore used by the app’s error-log export.
- [ ] Identify the original physical-phone import failure if the error and diagnostics become available. The user reports the updated transfer worked.

On a build containing the diagnostics, reproduce the import, then open Settings → More → Advanced → Export Error Log on the receiving phone. Export the log before force-quitting or relaunching the app, since this export covers the current app process. The exported file can contain unrelated app diagnostics, so review it before sharing. The reported archive may already be valid; retain it and try importing it with the updated receiver. Both devices should run a build that supports whole-library transfers.

## Library transfer — 2026-11-03

- [x] Make Transfer Library available in the active SwiftUI Settings screen.
- [x] Export all playable games in one transfer from Settings → Accounts & Sync → Transfer Library (on iOS 26, choose Accounts or Overview).
- [x] Reuse validated import, conflict confirmation, recovery, and rollback for the complete archive.
- [x] Support libraries larger than eight games, while retaining bounded package validation.
- [x] Transfer contract tests pass, including a 12-game manifest round trip and duplicate rejection.
- [x] iOS Simulator Debug build passes with Xcode 27.2 after deployment target and native comparator compatibility changes in the dependency checkouts.
- [x] User reports the transfer worked between the phones on 2026-11-04; the original failure was not conclusively identified.

Close games on the source phone, choose Settings → Accounts & Sync → Transfer Library, and send the archive with AirDrop or save it to Files. On the new phone, open the archive in Delta or select it from Library → + → Files. Both installations need a version that supports library-sized transfers. Games and their game-owned data described below are included; global settings, unassigned skins, firmware, and accounts are not included. The current format supports up to 1,000 games, 20,000 files, 2 GiB per file, and 8 GiB total uncompressed data. A library exceeding these limits fails export instead of producing a partial archive. Storage is needed for temporary staging and the archive on both phones.

## Sender and receiver cleanup follow-up

- [x] Keep export/import staging in transfer-owned temporary workspaces.
- [x] Sender: remove the export workspace on share completion/cancellation or share-sheet release, including unsuccessful presentation.
- [x] Receiver: take ownership of sandbox Inbox/temporary import copies and remove them and extracted files on success, cancellation, or error. Clean unprocessed batch copies and defer busy-request cleanup until the active operation finishes.
- [x] Clean abandoned workspaces from an interrupted prior session at app launch, without sweeping active transfers.
- [x] Preserve original games/saves, user-saved transfer files in Files, and recovery backups; retain incomplete rollback data outside temporary cleanup.
- [x] Verify cleanup paths and exercise sender/receiver cleanup on Simulator: export lifetime removes sender workspace, valid/invalid Inbox imports remove receiver copies, extraction folders disappear, and saved packages remain. Debug build and all 39 contracts pass.
- [x] Merge `quality/game-transfer-cleanup` (`ed3b93d`) into `refactor/codebase-quality` locally.

Cleanup removes transfer working files on each installation, including an app-owned Inbox copy on the receiver. A transfer deliberately saved in Files is retained. The original game and its installed saves remain on both devices. Recovery packages and incomplete rollback data in Documents/Transfers/Recovery are preserved. App restart removes abandoned transfer workspaces; it never sweeps that recovery directory. Cleanup cannot control copies retained by another share destination or a file provider.

Cleanup validation (2026-10-28): 39 contracts pass (including three cleanup test groups), dependency boundaries pass, and DeltaApplication passes complete concurrency checking with warnings as errors. Debug build and the actual-model console/Java transfer round trip with sender/receiver cleanup checks pass. Evidence is under `.build/transfer-cleanup-smoke/` and `.build/transfer-cleanup-*.log`. The disposable simulator was deleted by the runner.

- [x] Final Release arm64 Simulator build passes with Debug verification code excluded.

- [x] Add Transfer beside Share in the game actions menu.
- [x] Define a versioned `.deltatransfer` package and validate its manifest, paths, sizes, and checksums.
- [x] Include game content, metadata, custom cover/banner artwork, per-game settings, favorite/played state, cheats, all save-state types and thumbnails, battery/RTC saves, Java data/sidecars, and assigned skins.
- [x] Include a configured secondary cartridge and preserve its relationship.
- [x] Import packages from Files/Open In; confirm existing-game replacement and preserve a recovery package.
- [x] Restore files and database records together with rollback on failure; reject games currently in use.
- [x] Verify round trips and malformed-package rejection, build Debug, and check the menu on Simulator.
- [x] Merge `quality/game-transfer` (`4f33452`) into `refactor/codebase-quality`. Changes are local; nothing has been pushed.

Transfer copies the game; it does not remove the source. Global preferences, accounts, cloud credentials, emulator firmware, and photos saved outside Delta are not game-owned data. Save states retain their core/version metadata and still require a compatible emulator core on the receiving device.

## Package and restore behavior

The archive contains `manifest.json` and game-owned files, with a version, byte counts and SHA-256 hashes. Import checks paths, ownership, duplicate entries, ZIP CRCs, sizes, file integrity, and supported game types before installing files. Symlinks and unrelated paths are rejected. Files are staged and overwritten files retained until the database save succeeds; an error rolls back files and database changes. Existing shared controller skins must match the transferred bytes.

Transfer is available beside Share for supported games, including Java ME. Share continues to send only the game file. Choose Transfer, then AirDrop or Save to Files in the system share sheet. On the receiving installation, open the `.deltatransfer` file in Delta or select it through Library → + → Files. The receiving installation must support this transfer format.

If the game already exists, Delta asks before restoring its metadata and matching saves. Additional local save states and cheats remain. A complete recovery `.deltatransfer` is saved first under Documents/Transfers/Recovery. Games must be closed in all windows; launch is blocked while their data is being copied/restored.

Local custom artwork is embedded. Cached remote artwork is embedded when available; otherwise its original web URL is retained. All available app-managed save files and thumbnails are copied; a missing referenced game/save-state/custom-skin file fails export rather than silently producing an incomplete transfer.

## Verification

- [x] All 36 SwiftPM contracts pass, including six transfer metadata/ownership/path/rollback tests.
- [x] DeltaApplication builds with complete concurrency checking and warnings as errors.
- [x] Dependency boundaries and Info.plist validation pass.
- [x] Debug arm64 Simulator app builds.
- [x] Console/Java database round trip against the actual compiled model, preserving all metadata values and file hashes; all five state types/thumbnails, local artwork, settings, enabled cheat, custom skin, preview/secondary links, battery/RMS/receipt included. Existing-game merge retains an extra local save; tampered payload rejected.
- [x] Interactive Transfer menu and archive share sheet, registered document handler, restore confirmation, and completed restore. Recovery archive includes both linked games and every checksum verifies independently.
- [x] Release arm64 Simulator build, with Debug-only verification code excluded. Final Debug build also passes after the scene-restoration guard and low-space rollback update; the six transfer tests pass again after that update.

The full package with warnings-as-errors additionally exposes pre-existing non-Sendable sync callback captures in `iCloudSyncState.swift`; the normal test suite passes. Strict checking above applies specifically to the extracted application module.

The round-trip driver is opt-in Debug code and uses original fixtures on a disposable simulator. Fresh import uses an isolated Core Data store with the real model. Artifacts, fixture transfer and recovery package are under `.build/game-transfer-smoke/`; build/test logs are `.build/game-transfer-*.log`. No real AirDrop recipient or physical-device transfer was used.

Reproduce with:

```sh
swift test
python3 Scripts/Quality/transfer.py \
  --app .build/quality-ios/Build/Products/Debug-iphonesimulator/Delta.app
```
