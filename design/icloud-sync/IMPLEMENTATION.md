# iCloud sync and raw ROM imports

- [x] Inspect Harmony providers, account handling, Settings, entitlements, and raw ROM imports.
- [x] Add a private CloudKit provider that preserves Harmony records and conflict handling.
- [x] Implement immutable file/record revisions, version downloads, metadata updates, and cascading deletion.
- [x] Implement incremental zone changes and account-bound tokens.
- [x] Add iCloud to Settings and configure CloudKit entitlements.
- [x] Allow generic-data raw ROMs in the game picker; normalize stored extension casing.
- [x] Compile and repair integration errors; final Debug arm64 Simulator build succeeds.
- [ ] Verify Settings and raw `.gba` import with a disposable fixture. Simulator is being used for another app and its UI changes between automation steps; no test games were inserted.
- [x] Document Apple account provisioning and two-device validation requirements.

CloudKit uses `iCloud.page.ducnguyen.Delta`, private database, custom zone `DeltaSync`. This container is configured in source; registering it and deploying the production schema requires the app owner's Apple developer account. Live cloud verification remains pending until that setup and signed, iCloud-authenticated devices are available.

## Design and verification

The provider uses the existing Harmony sync engine rather than changing the Core Data schema. Record metadata is JSON, small payloads use CKAsset, and ROMs above 16 MiB are split into ordered 16 MiB assets. Downloads verify size and SHA-1 before handing data to Harmony. Revisions are immutable and remain available for the existing version UI. Head/revision/chunk writes are atomic with `ifServerRecordUnchanged`; server conflicts become Harmony conflicts. Deleting a head cascades through its revision and chunk assets. History consumes the user's iCloud quota and currently has no automatic retention pruning.

Sync remains opt-in. Connect uses the device's existing iCloud account; Disconnect stops Delta syncing without signing out the device or deleting remote data. Operations verify the authenticated account ID, and tokens are bound to that ID. Expired tokens trigger a full zone refresh including inferred deletions. Changed accounts require disconnection/reconnection. Foreground/background sync follows the existing SyncManager lifecycle; this change does not add remote push subscriptions.

Raw ROMs were already accepted by DatabaseManager and declared in Info.plist, including `.gba`. The picker now also accepts `public.data` so providers that do not recognize Delta's UTI can select raw files. Unsupported extensions still fail validation, ZIP extraction remains supported, and stored extension casing is normalized. ZIP is optional packaging, not a requirement.

- [x] Four transport-independent tests pass (`swift test --scratch-path /private/tmp/DeltaSyncContractsBuild`): distinct/stable IDs, exact historical revision selection, account-bound tokens, and lossless chunk splitting/reassembly with failure cleanup.
- [x] Final iOS app build succeeds and `git diff --check` passes. App launches and opens Settings; the service selector has not been visually verified.
- [ ] Validate signed CloudKit upload/download on two devices, including offline edits, conflict resolution, deletions, account changes, quota failures, and expired tokens.
- [ ] Test a real `.gba` and a large DS ROM through Files and gameplay.

## Apple developer setup

- [ ] Register and associate `iCloud.page.ducnguyen.Delta` with the app ID `page.ducnguyen.Delta` in the Apple developer account; regenerate/select an iCloud-capable signing profile.
- [ ] Run a signed development build on an iCloud-authenticated device to create the `DeltaRecord`, `DeltaFile`, `DeltaRevision`, and `DeltaChunk` record types.
- [ ] Confirm `metadata` and `revisions` are Bytes fields; `payload` is Asset; `parent` is Reference; `chunks` is a String list; `size` is Int64; `sha1` is String. No custom query indexes are needed: this adapter fetches record IDs and zone changes.
- [ ] Deploy the development schema to Production before TestFlight/App Store distribution.
- [ ] Complete the two-device checks above before shipping.

Apple references: [Enable CloudKit](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app), [deploy schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema), [atomic records](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation), [zone change tracking](https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation).

## Upload crash repair

- [x] Trace the reported `RecordRepresentation.status` crash to an iCloud completion running on the Swift task executor. Harmony updates returned managed objects synchronously in that completion.
- [x] Deliver both success and failure callbacks on the supplied Core Data context for change fetching, record upload/download, and file upload. Creating an object inside `await context.perform` alone does not keep the subsequent callback on that queue.
- [x] Add regression coverage for callback delivery from a detached task on success/failure and a returned managed object's status mutation and save on a private context.
- [x] All six sync contract tests pass; the full Debug arm64 Simulator build succeeds; `git diff --check` passes.
- [ ] Retry signed iCloud sync on the affected device with Core Data concurrency debugging enabled to confirm the original upload now completes. Live CloudKit access is not exercised by the local contract tests.

The console's missing temporary `.sav` message is separate from the reported Core Data assertion. Harmony already skips absent optional save files when calculating hashes/uploading files; this fix does not create empty saves or overwrite local game data.
