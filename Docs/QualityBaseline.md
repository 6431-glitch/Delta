# Quality upgrade baseline

Recorded 2026-10-14. Starting commit: `c7f11f9` (existing feature work checkpoint).

## Setup

- [x] Xcode 26.6 (17F113), Swift 6.3.3, arm64 macOS toolchain available.
- [x] Workspace: `Delta.xcworkspace`; app scheme: `Delta`; configurations: Debug/Release.
- [x] Additional shared schemes: DeltaFeatures, DeltaPreviews, Systems, mogenerator.
- [x] App targets iPhone/iPad. App project deployment target is iOS 17.4; individual library targets have older minima.
- [x] OperatorKit binary supplies iOS arm64 and iOS Simulator arm64/x86_64 slices; no native macOS slice.
- [x] Submodule revisions captured by `git submodule status`; use the Git-pinned revisions, not latest upstream heads.
- [ ] Runtime smoke tests and device performance baseline. No simulator was booted at initial inspection; authenticated cloud/device checks require configured accounts/devices.

For a fresh clone, initialize submodules recursively and install the Podfile dependencies with CocoaPods. Preserve the workspace's pinned SPM revisions. J2ME generation uses the checked-in preparation scripts invoked by its native build phase; see `Experiments/J2ME/README.md`. Do not replace local forks with upstream packages while reproducing this baseline.

## Repeatable checks

Run from the repository root:

```sh
python3 Scripts/Quality/check.py
xcodebuild -workspace Delta.xcworkspace -scheme Delta -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/quality-ios \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO ARCHS=arm64 build
python3 Scripts/Quality/check.py \
  --model .build/quality-ios/Build/Products/Debug-iphonesimulator/Delta.app/Delta.momd \
  --nuke .build/quality-ios/SourcePackages/checkouts/Nuke
```

The runner propagates failures and labels skipped integration checks. It places Swift module caches in writable temporary directories. Xcode and the optional Nuke HTTP test may need access to developer caches/local sockets outside a restricted sandbox.

## Initial results

- [x] Six iCloud state contracts passed: identity, revisions, account tokens, chunk transport, and Core Data callback confinement.
- [x] Artwork assignment validation: ten checks passed.
- [x] Artwork cover layout: nine checks passed.
- [x] Game replacement: swap, rollback, empty-file rejection, artwork preservation, and temporary-file cleanup passed.
- [x] Save-state snapshot fixtures: all seven conventional systems passed, including rapid rotation/FRC updates.
- [x] J2ME audio handles: lifetime, duplicate close, stale token, teardown, and concurrent cleanup passed.
- [x] Schema migrations and Nuke HTTP/cache checks passed against the fresh built model and pinned checkout (16 Nuke checks).
- [x] Debug arm64 Simulator build passed.
- [ ] Release/device build and live sync verification.

The Delta scheme has no XCTest testables. Root SwiftPM tests cover sync contracts, not the entire app. Tests involving managed schemas need the built `.momd`. SaveStateUpgrade now accepts `--model` instead of a machine-specific build path.

## Static indicators

The initial review counted 234 app Swift files, 110 textual `DatabaseManager.shared` occurrences, and 11 files outside J2ME referencing its runtime. Gameplay/library/database/settings files mix feature orchestration with persistence and concrete engines. Treat these as substitution-cost indicators, not defect counts.

## Outstanding acceptance gates

- [ ] Exercise conventional gameplay and save/load using a legally available fixture.
- [ ] Exercise J2ME import, start, pause, resume, exit, and save restoration.
- [ ] Compare launch time, frame pacing, audio stability, and memory on the same fixture/device before and after changes.
- [ ] Validate authenticated sync upload/download/conflicts on signed devices.

Until these are available, static/contract/build checks support incremental refactoring but do not establish unchanged gameplay performance or live cloud behavior.
