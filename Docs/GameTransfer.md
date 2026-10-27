# Complete game transfer — 2026-10-27

- [x] Add Transfer beside Share in the game actions menu.
- [x] Define a versioned `.deltatransfer` package and validate its manifest, paths, sizes, and checksums.
- [x] Include game content, metadata, custom cover/banner artwork, per-game settings, favorite/played state, cheats, all save-state types and thumbnails, battery/RTC saves, Java data/sidecars, and assigned skins.
- [x] Include a configured secondary cartridge and preserve its relationship.
- [x] Import packages from Files/Open In; confirm existing-game replacement and preserve a recovery package.
- [x] Restore files and database records together with rollback on failure; reject games currently in use.
- [x] Verify round trips and malformed-package rejection, build Debug, and check the menu on Simulator.
- [ ] Merge into `refactor/codebase-quality`.

Transfer copies the game; it does not remove the source. Global preferences, accounts, cloud credentials, emulator firmware, and photos saved outside Delta are not game-owned data. Save states retain their core/version metadata and still require a compatible emulator core on the receiving device.

## Package and restore behavior

The archive contains `manifest.json` and game-owned files, with a version, byte counts and SHA-256 hashes. Import checks paths, ownership, duplicate entries, ZIP CRCs, sizes, content identity, and supported game types before installing files. Symlinks and unrelated paths are rejected. Files are staged and overwritten files retained until the database save succeeds; an error rolls back files and database changes. Existing shared controller skins must match the transferred bytes.

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
