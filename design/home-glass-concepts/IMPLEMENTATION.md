# Aurora Wheel native implementation

Target: iOS 26+ home scene based on `10-aurora-wheel-orientation-lock.png`.

## Landscape blur edges

- [x] Extend the carousel backdrop under the leading, top, and bottom safe-area insets.
- [x] Keep wheel, header controls, and detail content in their existing safe-area layout.
- [x] Build and visually verify the backdrop reaches the screen edges.

The previous backdrop inherited the carousel's safe-area bounds. Its background now explicitly includes the leading, top, and bottom insets, without changing foreground layout. [Verified landscape screenshot](verification/landscape-blur-edges.png). Debug arm64 build and whitespace checks pass.

October 9 recheck: the current home implementation again contained the inset material rectangle. Moved it to a noninteractive background with explicit safe-area dimensions and offsets. Verified that the empty-library backdrop reaches the left and bottom edges in both landscape orientations: [opposite orientation](verification/landscape-blur-opposite.png). The final arm64 Simulator build and `git diff --check` pass.

## Inline search refinement

- [x] Replace the separate search row with an expanding glass control anchored to the search button.
- [x] Keep landscape search in the header and portrait search in the bottom dock.
- [x] Collapse search with Close, clearing the query and dismissing focus.
- [x] Build and inspect the expanded control in Simulator; confirm Close restores the search button and portrait dock actions.

Verified in iPhone 17 Pro Simulator on iOS 26.5. [Landscape inline search](verification/landscape-inline-search.png) expands in the header; [portrait inline search](verification/portrait-inline-search.png) expands within the dock. The previous separate search row is removed. Debug arm64 build and `git diff --check` pass.

- [x] Inspect existing navigation, database, launch, and artwork paths.
- [x] Implement live game data and native glass home controls.
- [x] Implement portrait hero carousel and recent games.
- [x] Implement landscape wheel, front-facing selection, and blurred edge fade.
- [x] Implement banner visibility toggle and orientation preference, subsequently expanded to apply app-wide (see `../aurora-artwork/LIBRARY.md`).
- [x] Connect import, settings, search, Favorites, library, and validated game launch.
- [x] Build and inspect portrait/landscape behavior.
- [x] Update final progress and document verification limits.

Existing covers supply the background because there is no separate banner field in the current game model. Preserve existing full-library game actions and launch validation. Do not use fictional mockup games in the live library. Orientation preference is scoped to the home, not emulation.

## Verification — October 8, 2026

- [x] Debug arm64 build succeeds for iPhone 17 Pro Simulator on iOS 26.5.
- [x] Inspect portrait hero, recent shelf, landscape wheel, edge fade, and flat selected cover.
- [x] Confirm portrait and landscape locks change layout and survive app relaunch.
- [x] Confirm banner-only mode hides every overlay except its restore button.
- [x] Confirm recent-game selection updates the hero and search finds Circuit Rush.
- [x] Confirm existing Library, Settings, and Files import picker open from home.
- [x] Confirm empty live library renders an import state; DEBUG fixture never saves games.
- [x] Run `git diff --check` without whitespace errors.
- [ ] Verify wheel dragging/snapping and library return button on a device or with working Simulator gesture automation. CUA returned `noWindowsAvailable` for coordinate/scroll actions; accessibility button actions and screenshots worked.
- [ ] Verify Play/Resume and save-state behavior with real imported ROMs. This Simulator has no games.
- [ ] Verify iPad, accessibility text sizes, and Reduce Motion/Transparency on a device.

Screenshots: [portrait](verification/portrait-home.png), [landscape](verification/landscape-wheel.png), [banner only](verification/banner-only.png). The screenshots use a standalone generated artwork fixture, not a real library. The preview is enabled only in DEBUG by `AURORA_PREVIEW_ARTWORK`, containing the absolute path of a local image. Release builds always use Core Data games.

Build command: `xcodebuild -workspace Delta.xcworkspace -scheme Delta -configuration Debug -destination 'platform=iOS Simulator,id=4FFBF522-1DE8-4306-B5C8-E89F786D5E78' -derivedDataPath /private/tmp/DeltaAuroraBuild CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES ARCHS=arm64 build`. A generic Simulator build also requests x86_64 and fails in the existing melonDS ARM assembly; verification uses the booted arm64 device. Existing dependency warnings remain.

Settings access remains connected to the existing settings screen; its visual redesign is separate from this selected home implementation.
