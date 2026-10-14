# Artwork manager concepts

Design request: replace scattered cover/backdrop import actions with a dedicated management page that also supports batch operations. Selected direction: concept 2, Paired Artwork Library. Native implementation complete; device visual verification remains pending.

- [x] Resolve the brief from the existing Delta/Aurora implementation and conversation.
- [x] Inspect existing Settings and Library screenshots for visual grounding.
- [x] Generate three independent concepts with the built-in Image Gen tool.
- [x] Save all three concepts in the workspace.
- [x] Select/refine a direction with the user: concept 2.
- [x] Implement the chosen design after the user requests implementation.

Generated concepts, in display order:

1. [Artwork Gallery](artwork-gallery.png) — visual game/asset grid in selection mode.
2. [Paired Artwork Library](paired-artwork-library.png) — compact game rows with separate cover/backdrop columns and a Select entry point for batch mode.
3. [Batch Artwork Review](batch-artwork-review.png) — file-to-game and cover/backdrop assignment review before committing imports.

These raster concepts are visual exploration, not measured implementation specifications. Source proportions must be preserved in implementation (including square and 3:4 covers); backdrops should have landscape previews. Some generated thumbnails approximate the requested proportions and require correction in the chosen direction.

## Shared generation brief

Built-in Image Gen, ui-mockup mode; three independent calls. One 390 × 844 portrait iOS app viewport per image, rendered at high resolution. App content only, without device/OS chrome. Existing screenshots supplied directly as style references:

- `design/settings-redesign/settings-portrait.png`
- `design/home-glass-concepts/verification/portrait-home.png`

Aurora near-black/navy with subtle purple glow, white San Francisco typography, restrained purple accents, translucent native glass. Native pushed page rather than another root tab. Independent assets for each game, batch imports of different images per game, and staged review before applying. Original fantasy, botanical, racing, sea-adventure, space and forest game illustration fixtures. No invented service, cloud progress, destructive primary action or irrelevant statistics. Date anchor 2026-10-12; no dates displayed.

## Per-concept prompt briefs

**Artwork Gallery:** header Artwork/Done, three selected games, search and All/Missing artwork filter, six game entries in two columns, independently labeled Cover and Backdrop previews, check circles and missing-backdrop add affordance. Batch dock has Import for 3 Games and Clear selection, leading to assignment review.

**Paired Artwork Library:** Artwork/Select header, search and All games filter, six compact rows on one grouped surface, Game/Cover/Backdrop columns, explicit mixed cover shapes and landscape backdrop thumbnails. Tap an asset to edit it; Select opens batch selection. Import Artwork from Photos or Files leads to review.

**Batch Artwork Review:** Review Import/Cancel header, six images assigned to three games, six filename rows with image previews, editable game assignment and editable Cover/Backdrop classification. Summary Replace 3 covers and 3 backdrops, Apply 6 Changes primary action, and Nothing is saved until you apply. This is the staged batch step, not an automatic operation.

## Implementation

- [x] Build paired artwork rows, search, filters and batch game selection.
- [x] Add Photos and Files import with staged assignment review.
- [x] Preserve cover proportions and refresh cached artwork after saving.
- [x] Verify compilation and import validation: Simulator build succeeded; 10 assignment checks passed.
- [x] Record visual verification results in DESIGN-QA.md (device verification pending; no simulator booted).

Open **Library → All Games → Manage Artwork**, or a game’s **Artwork → Manage Artwork** menu. Tap individual asset previews for replacement, or use Select and Import Artwork for a scoped batch. The review sheet supports destination selection, Cover/Backdrop classification and removing unwanted images before Apply.

## Compact import follow-up

- [x] Remove the large bottom import card, including the landscape overlay shown in the user's screenshot.
- [x] Keep batch import accessible through the compact photo-plus toolbar action next to Select.
- [x] Use native UIAlertController action-sheet presentation for Photos and Files on iPhone; preserve the required iPad anchor.
- [x] Verify compilation.
- [ ] Verify native chooser presentation and dismissal on device.
