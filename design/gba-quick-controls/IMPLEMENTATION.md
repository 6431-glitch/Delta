# GBA quick save/load controls

- [x] Dismiss the iOS 26 gameplay action menu through Resume when tapping empty space outside its cards.
- [x] Add outside-panel dismissal to the legacy pause presentation.
- [x] Add an icon-only Quick Save control 8 points to the right of the active skin's L button.
- [x] Add an icon-only Quick Load control 8 points to the left of the active skin's R button.
- [x] Restrict these controls to GBA touch-controller layouts and anchor them to skin shoulder frames across orientation changes.
- [x] Reuse the existing quick-save slot and save/load handlers; stop repeated taps when either quick control is used.
- [x] Preserve wireless multiplayer and Hardcore load restrictions; disable loading before a quick save exists.
- [x] Add accessibility labels/hints and hide the icons during repeat-button selection.
- [x] Verify final arm64 Simulator build and whitespace checks.
- [ ] Verify actual GBA saving/loading, portrait/landscape placement, custom skins, and tap-outside versus menu/toolbar interactions on device.

Quick controls are added to the game controller's root view because ControllerView routes touch hits directly to its skin input view. Their frames are derived from the active skin's L/R button rectangles; skins without those items do not display these controls. No changes are made to other systems or core controller skin assets.
