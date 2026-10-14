# Replace game file and compact artwork import

User intent: replace the installed Snowball Fight JAR with a revised version while keeping its existing artwork/library entry. “Core” in this request refers to the game's JAR/ROM file; this feature does not switch emulator engines.

- [x] Add Replace Game File to Aurora Library game menus.
- [x] Choose a single raw same-platform file; validate J2ME manifest and MIDlet class presence.
- [x] Block replacement while a Java session or the selected console game is active.
- [x] Keep identifier, filename, game name, cover/backdrop, favorites, preferences and save relationships unchanged.
- [x] Update the J2ME original filename hint and discard a stale paired JAD descriptor so screen detection can read the replacement JAR's own metadata. Manual screen overrides remain authoritative.
- [x] Stage and back up files on disk, then swap atomically; restore the previous file if the database commit fails. Retain the recovery copy if restoration itself fails.
- [x] Explicitly refresh the sync record even when its stable game-file URL does not change.
- [x] Remove the large artwork import footer and retain batch import in a compact toolbar action beside Select.
- [x] Replace the SwiftUI confirmation dialog with native UIAlertController action-sheet presentation for Photos/Files/Cancel on iPhone. iPad retains its system-required popover anchor.
- [x] Pass replacement tests for successful swap, existing-file rollback, missing-file rollback, empty-file rejection, untouched artwork and staging cleanup.
- [x] Complete a full arm64 Simulator build and whitespace checks.
- [ ] Verify file picking and native action-sheet presentation in portrait/landscape on a device.

Use Library → game menu → Replace Game File, then select the revised JAR. This intentionally keeps the existing library identity rather than importing a new content-hash entry. Existing saves remain present, but whether a revised ROM/JAR can read them depends on that game's compatibility. Archives are not unpacked for replacement; supply the raw ROM/JAR.

Test: `swiftc -module-cache-path /private/tmp/DeltaNukeSwiftCache Delta/Components/Loading/GameFileReplacement.swift Tests/GameFileReplacement/verify.swift -o /private/tmp/DeltaReplacementChecks`, then run the executable. Build log: `/private/tmp/DeltaReplacement-build.log`.
