# Aurora cover and backdrop pickers

- [x] Add a per-game Artwork menu in portrait and landscape.
- [x] Offer independent Cover and Backdrop import choices.
- [x] Reuse Photos, Files, Clipboard, and cover database import sources.
- [x] Add a Use Cover as Backdrop reset action.
- [x] Persist backdrop separately with an additive Delta 13 Core Data model.
- [x] Include backdrop metadata and image files in Harmony sync.
- [x] Bound imported image decoding and refresh cached artwork after replacement.
- [x] Keep covers visible in the wheel, recent shelf, and portrait detail panel.
- [x] Verify inferred Delta 12 → 13 migration preserves existing model properties.
- [x] Build and inspect portrait/landscape Artwork menus in Simulator.
- [x] Document final verification and remaining limitations.

Aurora is now the Library tab. The original Library actions are exposed through Game Actions in Aurora; see [unified Library progress](LIBRARY.md).

Verification: final arm64 build passes. `Tests/ArtworkMigration/verify.swift` migrated a temporary Delta 12 SQLite store to Delta 13, preserved its cover and favorite, then persisted and reset its backdrop independently. The test uses generic managed objects and does not exercise app image decoding or live sync. Cover/Backdrop menus were inspected in portrait and landscape. The real source picker presented Photos, Clipboard, cover database, and Files; Files rendered but CUA could not interact with its UI (`noWindowsAvailable`). End-to-end photo/file selection, app relaunch after image replacement, and signed two-device sync remain unverified.
