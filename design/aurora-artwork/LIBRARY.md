# Unified Aurora Library

- [x] Rename Home navigation to Library.
- [x] Keep Library and Settings as the only navigation tabs.
- [x] Move Search to the header and retain Favorites in the collection filter.
- [x] Add an Aurora grid view for the full collection in both orientations.
- [x] Remove navigation to the separate legacy Library on iOS 26.
- [x] Reuse Rename, Favorite, Share, Delete, Game Settings, Save States, save-file import/export, and Open in New Window.
- [x] Preserve game-type and RetroAchievements Hardcore restrictions in the shared action menu.
- [x] Provide per-game artwork choices within Game Actions.
- [x] Preserve validated game drag providers in the grid.
- [x] Verify native Library/Settings tabs, grid, Settings presentation, and shared game-action menu in Simulator.
- [ ] Verify search typing, drag gestures, real-game launch/save handling, and iPad multiwindow on device.
- [x] Update final verification results.

The original UIKit controller remains an internal action/launch adapter and the pre-iOS-26 library. Aurora owns the iOS 26+ library interface; both use the same game collection.

Final verification: arm64 Debug build and `git diff --check` pass. A disposable iOS 26.5 Simulator imported a non-playable `.gba` fixture through the normal file-open route. Its Aurora menu exposed Favorite, Rename, Artwork, Share, Game Settings, Save States, Manage Save File, and Delete. Rename presented successfully and was cancelled. Artwork opened its separate choices and source picker. Native TabView Library/Settings rendering and Settings category navigation were inspected; the sheet Close button is absent. The original delete confirmation and Hardcore/game-type guards are reused. Destructive actions and gameplay were not exercised.

The custom bottom dock has been removed. Search expands within the header; Favorites remains a collection filter. `AURORA_QA_TAB=settings` is a DEBUG-only initial-tab fixture for screenshots; release builds start at Library.

## App-wide orientation lock

- [x] Apply the persisted orientation preference through the application delegate to every app window, including Settings and gameplay.
- [x] Refresh supported orientations and request geometry updates for all connected app scenes when the preference changes.
- [x] Make gameplay gyro and controller-mapping orientation overrides honor explicit Portrait/Landscape locks; retain their existing behavior in Auto.
- [x] Keep Library controls synchronized with the shared preference across windows and when returning from gameplay.
- [x] Verify the arm64 Simulator build and whitespace checks.
- [ ] Verify physical-device rotation through gameplay, gyro games, controller mapping, and iPad multiwindow.

The existing `homeOrientation` defaults key is retained so previously saved choices apply app-wide after updating. Geometry-request errors are reported without discarding the saved preference.

## Scroll-only square carousel

- [x] Replace the custom drag-offset reset/spring with native ScrollView momentum and view-aligned snapping.
- [x] Remove wheel-cover buttons and its accessibility launch action; keep accessible scrolling.
- [x] Use square 1:1 cover frames in the wheel, grid, recent shelf, and portrait detail card.
- [x] Reduce neighboring-cover blur from a three-times multiplier / 8-point cap to a 1.5-times multiplier / 4-point cap after strength refinement.
- [x] Blend the frosted carousel backdrop at 85% opacity and broaden its gradual right-edge fade.
- [x] Soften wheel fades at the top and bottom.
- [x] Build and inspect a flat, centered square selected cover with softer fades.
- [x] Render visible covers in a shared stack with the centered cover above neighboring covers; retain native scrolling and snapping.
- [x] Align the centered landscape cover's leading edge with the left safe area.
- [x] Extend the artwork's vertical fade mask through the leading safe-area inset and remove the wheel's rectangular clip, so rotated neighbors are not cut at the safe-area boundary.
- [x] Initially select the first filtered game rather than the most recently played game, including the DEBUG preview.
- [x] Crossfade landscape backdrops from the wheel's fractional scroll position, including momentum and direction reversals, without a separate timed animation.
- [x] Keep neighboring backdrop views mounted with stable game identities so boundary crossings reuse loaded images.
- [x] Update the selected game/details directly from the wheel's nearest centered index, independently of native scroll-target binding; keep external selection and accessible scrolling supported without snapping during drag.
- [ ] Verify background-transition smoothness with distinct backdrops on device.
- [ ] Manually verify fling/deceleration feel on device; CUA failed with a ScreenCaptureKit capture error and cannot currently automate gestures.

Final arm64 build and whitespace checks pass. [Scroll-only wheel](scroll-only-wheel.png) uses the unsaved DEBUG artwork fixture. Native scroll targets are invisible; visible artwork shares one overlay stack. Position, transforms, and drawing depth follow the content's measured offset within the outer viewport, so the closest cover draws above its neighbors and faces the user directly when centered. Covers display their complete source images inside square frames; backdrop layout remains full screen.

- [x] Increase blur strength after visual feedback while retaining the gradual edge fades. Arm64 build and whitespace checks pass.
