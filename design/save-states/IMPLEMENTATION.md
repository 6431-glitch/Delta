# Compact save-state layouts

- [x] Add adaptive Grid and full-width List layouts with a persistent layout preference.
- [x] Provide a navigation layout toggle and explicit Grid/List menu choices.
- [x] Use compact rounded material cards, small list thumbnails, left-aligned labels, and restrained section spacing.
- [x] Remove the large navigation title and size cards from the actual available collection width.
- [x] Retain automatic, quick, general, and locked sections, compatibility filtering, sorting, preview/context menus, import/export, and save/load delegates.
- [x] Preserve selected save states when changing layout during batch editing.
- [x] Support adaptive grid columns and larger rows for accessibility text sizes.
- [x] Verify final arm64 build and whitespace checks.
- [ ] Visually inspect populated Grid/List screens and verify save/load, batch editing, rotation, and Dynamic Type on a running device.

The save-state screen uses a standard collection flow layout rather than the library's equal-spacing grid layout. Its compact cell presentation is opt-in; other grid cells keep their original constraints. Existing save-state action/delegate code is reused. The disposable QA Simulator was shut down during this task, so populated-screen visual verification remains pending.
