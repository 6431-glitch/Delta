# Settings renovation

- [x] Inspect the live SwiftUI Settings entry point and existing destinations.
- [x] Add a navy/violet overview, readable grouped cards, and clearer section headings.
- [x] Add native glass category navigation: portrait chips and a wide-layout sidebar.
- [x] Preserve settings destinations, controller counts, account updates, and sync on dismissal.
- [x] Preserve the existing Form fallback before iOS 26 and adapt for accessibility text sizes.
- [x] Build and inspect the renovated scene in Simulator.
- [x] Verify category navigation and representative settings destinations.
- [x] Update verification results and save screenshots.

Verified on iPhone 17 Pro, iOS 26.5: portrait overview, landscape sidebar, Appearance and Accounts filtering, and opening App Icon and Delta Sync. Final arm64 Simulator build and `git diff --check` pass. Settings values were not changed during validation.

Screenshots: [Portrait](settings-portrait.png) and [Landscape](settings-landscape.png).

The existing destination screens retain their current layouts. Accessibility text-size and Reduce Transparency adaptations are implemented; dedicated runtime checks for those settings and the pre-iOS-26 fallback remain unverified.

## Native tabs and compact category cards

- [x] Embed Settings as a native TabView tab alongside Library on iOS 26+.
- [x] Remove the modal Close button in tab mode and sync when switching back to Library.
- [x] Apply a dark color scheme to the NavigationStack/Form so labels and titles remain readable.
- [x] Reduce top content margin, row padding, section spacing, and hero icon size for every category.
- [x] Inspect native tabs, corrected text contrast, and compact Appearance card in Simulator.

Final arm64 Debug build and whitespace checks pass. [Appearance tab](appearance-tab.png) shows the shared compact spacing used by Overview, Play, Appearance, Accounts, and More. Existing destination pages retain their layouts.
