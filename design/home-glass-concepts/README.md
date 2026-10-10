# Delta glass home concepts

Created October 8, 2026 using the built-in ImageGen tool. Each board pairs portrait and landscape home screen concepts. The selected Aurora Wheel direction is now implemented in the native iOS 26+ home. Settings access is connected; settings screens were not part of these boards.

## Progress

- [x] Inspect existing home screen navigation and theme.
- [x] Generate five independent glass home concepts with both orientations.
- [x] Save all five boards for review.
- [x] Record the user's selection: portrait from Aurora Resume and carousel from Prism Carousel.
- [x] Generate a combined revision including landscape browse and banner-only states.
- [x] Refine landscape carousel into a large wheel arc.
- [x] Add progressive blurred fadeout at the wheel edges.
- [x] Correct the selected cover to face the user directly without tilt or perspective.
- [x] Add a main-scene orientation control and Auto/Portrait/Landscape menu to the concept.
- [x] Review the combined revision with the user and incorporate wheel, edge fade, front-facing cover, and orientation feedback.
- [x] Implement the selected direction in the native app.

See [implementation progress and verification](IMPLEMENTATION.md) for checked work, Simulator screenshots, and remaining device checks. Home source: `Delta/Game Selection/AuroraHomeView.swift`.

## Boards in displayed order

1. [Amethyst Library](01-amethyst-library.png): familiar platform tabs and cover grid.
2. [Aurora Resume](02-aurora-resume.png): resume hero and recent shelf, split view in landscape.
3. [Glass Console](03-glass-console.png): platform navigation becomes a sidebar in landscape.
4. [Prism Carousel](04-prism-carousel.png): large cover selection and a Play action.
5. [Pearl Collection](05-pearl-collection.png): light glass, thumbnail rows, floating resume control.

## Selected combination — Aurora Carousel

[Revision board](06-aurora-carousel.png), generated with the built-in ImageGen tool using boards 2 and 4 as attached references.

- Portrait preserves Aurora Resume's hero, glass Resume overlay, recent shelf, and navigation; horizontal hero swiping adds the carousel behavior.
- Landscape uses a full-screen selected-game banner with a vertical cover carousel in a blurred glass panel on the left and game details/Resume on the right.
- Blur applies to the banner behind the carousel panel; selectable game covers remain sharp.
- The eye button hides the carousel and detail controls for banner viewing. An eye-slash button restores browsing. This interaction is implemented in the native home.

Revision prompt: combine portrait from reference 2 and carousel selection from reference 4; create portrait, landscape browse, and landscape banner-only states. Landscape must have a narrow left vertical carousel with a centered selected cover and neighboring covers above/below, blurred background glass, sharp covers, full-bleed fictional Moonlight Quest banner, title/platform/description and Resume over a subtle scrim on the right. Show an eye control that hides all overlays except a restore button in banner-only mode. Keep midnight blue, teal and violet atmosphere, readable native typography, restrained glass edges, safe areas, and generous touch targets.

## Prompt set

### Main-scene orientation control

Latest review target: [orientation lock revision](10-aurora-wheel-orientation-lock.png), generated with the built-in ImageGen tool from the front-facing revision. A corrective edit removed a duplicate portrait lock button.

Prompt: preserve the current concept and add one glass orientation button in the main-scene header for each orientation. Show its menu with Auto, Lock Portrait, and Lock Landscape. Hide this control with the other overlays in banner-only view. Preserve the front-facing selected cover and blurred wheel edges.

Intended behavior: Auto follows device rotation; Lock Portrait holds the home scene upright; Lock Landscape holds the home scene horizontally. The preference applies to the home scene; gameplay orientation needs separate consideration during implementation. These controls are static mockups. The landscape icon in the final generated board resembles a portrait phone; implementation should use an accurate horizontal-phone icon for landscape lock.

### Wheel refinements

[Wheel revision](07-aurora-wheel.png), [edge fade revision](08-aurora-wheel-edge-fade.png), and [front-facing cover revision](09-aurora-wheel-front-facing.png) were generated with the built-in ImageGen tool using the preceding board as the edit reference. These precede the orientation lock revision.

Wheel prompt: preserve portrait and banner-only states; arrange landscape covers along the right arc of an invisible large wheel centered offscreen left. Selected cover is largest and sharp at center; neighboring covers recede left above/below, scale down and rotate along the arc. Keep full-screen banner, right-side details and eye toggle. Blur the glass backdrop beneath the wheel.

Edge fade prompt: preserve the wheel and selected cover; progressively blur and reduce opacity of covers toward top and bottom boundaries, dissolving outer covers before clipping. Feather the glass region into the banner while keeping controls and the selected cover sharp.

Front-facing correction prompt: change only the selected landscape cover to an upright flat rounded rectangle, horizontal top/bottom edges, vertical left/right edges, and zero roll, yaw, pitch or perspective distortion. Preserve sharp artwork, selection rim, neighboring wheel rotations, edge fade, portrait and banner-only states. Implementation must settle the selected cover at identity rotation with no perspective skew.

Implemented behavior: vertical swipe rotates the wheel and snaps the selected game to center, updating banner/details; edge blur and opacity track distance from selection. Gesture validation on a device remains pending. The native implementation confines edge blur to the wheel region.

Shared brief: production-quality native iPhone Delta game library, iOS 26+ inspired glass controls, paired 390 × 844 portrait and 844 × 390 landscape layouts on a presentation board. Adapt the layout between orientations. Preserve platform collections, Favorites, Recently Played, search, import, settings, and resume capabilities. Use readable typography, safe areas, generous spacing, opaque artwork, and fictional game covers. Use translucent blur, restrained rim highlights, and depth for navigation. Avoid clutter and invented metrics.

- Amethyst Library: charcoal and Delta purple (#8B28F7), top platform selector, two-column portrait grid and wider landscape grid, floating Library/Favorites/Recent dock.
- Aurora Resume: midnight navy, teal and violet atmosphere, one resume hero above recent covers; landscape hero on the left and library shelves on the right.
- Glass Console: smoky graphite and silver glass, console selector above portrait grid; left platform sidebar and four-column game grid in landscape.
- Prism Carousel: near-black with artwork-derived coral and indigo, large swipeable covers, selected title and Play; landscape cover strip beside selected-game details.
- Pearl Collection: pearl white and pale lavender, dark text, thumbnail list rows and resume mini-player; landscape sidebar and two columns of rows.

Generated images are conceptual; exact viewport proportions, control sizes, icon fidelity, and navigation consistency need refinement before implementation.
