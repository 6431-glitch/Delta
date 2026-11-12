# Save-state upgrade

- [x] Add backward-compatible model fields for synced tags and manual order; preserve existing states.
- [x] Add one Main Save per console game, checkpointing every five active gameplay minutes.
- [x] Configure per-game autosave history (0–20, default 5); retain Main Save independently.
- [x] Add search, tag/type filters, tags editing and manual ordering to grid/list.
- [x] Put Main Save first and show timing/history policy in the screen.
- [x] Keep screenshot-only previews and existing save/load, lock, import/export and compatibility checks.
- [x] Test migration, main-slot/history policy, metadata and shared-screen updates.
- [x] Build for arm64 Simulator (`/private/tmp/DeltaSaveUpgrade-build.log`).
- [ ] User/device verification of timed saves and interactions.

J2ME retains RMS saves; console VM save states are the scope. Five-minute time counts active visible gameplay, excluding paused/background time. Existing general/quick/locked states are preserved. History limits are enforced when saving; reducing the limit removes oldest history states, never Main Save or manual/locked states.

Implementation: Core Data model 14 adds nullable tags and default-zero manual order; legacy models remain in the bundle for inferred migration. Main Save uses the new type 4; its timer runs only during visible, active console play, excludes pause/background/multiplayer, and resets when changing games. + in saving mode updates this slot. Grid/list cards show state name, modified time and tags; the filter menu contains type, tags, sorting and history limit. Context menus provide Edit Tags, Move Up/Down (within a section) and Keep as Checkpoint, which preserves a Main/history snapshot outside rolling retention.

Sync: Main/manual/locked state metadata includes tags and manual order. History and quick slots keep their existing local-only policy. The history limit is a per-game local preference stored in game settings. Existing states are not deleted by migration; history limits take effect on subsequent checkpoints. Screenshot-only context previews remain in place. File replacements use the shared tested staging/rollback helper, and autosave loads copy their source instead of moving it.

Verification: `Tests/SaveStateUpgrade/run.py` uses the actual compiled v13/v14 models and a real SQLite store; exercises production tag/timing rules plus Core Data filtering and manual ordering. `Tests/SaveStateSnapshot/run.py` checks all seven console platforms. Shared replacement checks cover successful swap, empty-file rejection and failure rollback. Actual five-minute native gameplay and UI appearance still require device verification; no HD J2ME game was run.
