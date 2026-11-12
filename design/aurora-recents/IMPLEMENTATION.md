# Recently Played in Library

- [x] Add an All Games / Recently Played section picker above the landscape wheel.
- [x] Order up to 12 played games newest-first while respecting the current platform, favorites and search filters.
- [x] Keep wheel artwork, selected details and banner blending on the same filtered list; reset scroll identity/progress when the list changes.
- [x] Handle no played games with an empty state and Show All Games recovery.
- [x] Restore normal portrait browsing when rotating out of landscape.
- [x] Launch portrait Recently Played cards directly instead of only changing the hero selection.
- [x] Make the whole cover-and-title label tappable with a Play accessibility hint.
- [x] Complete the final arm64 Simulator build (`/private/tmp/DeltaAuroraRecents-build.log`).
- [ ] Verify interactions on a device; no HD gameplay retest performed.

Landscape wheel covers remain scroll-only. Its section picker switches between normal Library ordering and recently played games; game actions stay beside the selected game details. Portrait recent cards use the existing Library launch callback, preserving console/Java ME routing and resume behavior. This uses the existing playedDate metadata and introduces no database changes.

- [x] Default to Recently Played on initial landscape entry and when rotating into landscape; use All Games if no history exists.
- [x] Keep portrait browsing on All Games and preserve an explicit section choice during the current landscape visit.
- [x] Verify the default-section change with an arm64 Simulator build (`/private/tmp/DeltaRecentDefault-build.log`).
