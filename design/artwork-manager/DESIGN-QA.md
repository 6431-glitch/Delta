# Paired artwork manager verification

Selected reference: `paired-artwork-library.png` (concept 2).

- [x] Match the paired Game / Cover / Backdrop hierarchy and grouped rows.
- [x] Use the Aurora dark palette with a restrained purple background gradient.
- [x] Keep artwork management inside the Library navigation stack and retain native Library / Settings tabs.
- [x] Preserve source cover proportions with aspect-fit thumbnails; use landscape backdrop previews.
- [x] Provide search, platform and missing-artwork filters, and explicit batch selection.
- [x] Import multiple images from Photos or Files, with individually editable game/asset assignments.
- [x] Disable Apply for unassigned images, deleted/out-of-scope games and duplicate destinations.
- [x] Update Core Data, sync records and Nuke cache after applying artwork.
- [x] Restore existing file bytes when writing or saving fails.
- [x] Move file reading and full-size image encoding off the main thread; bound thumbnail decoding.
- [ ] Verify on-device layout and Photos / Files flows visually.

Automated assignment checks: 10 passed, including two assets for one game, two games receiving covers, missing assignments, unavailable games, duplicate covers/backdrops and invalid asset types.

Visual status: pending. No iOS Simulator was booted during this task; no device run or screenshot comparison is claimed. Native navigation provides the back affordance and system tab bar. Rows adapt their game-name column while keeping thumbnail columns stable; names can wrap. Covers fit inside bounded thumbnail slots rather than being cropped into squares.
