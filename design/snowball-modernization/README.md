# Snowball Fight artwork modernization

User scope: preserve gameplay; refresh title and menu presentation; replace the childlike original female sprites with a new adult cast wearing tank tops, athletic shorts and boots. User selected the new adult cast. Compatibility repair is explicitly out of scope.

- [x] Inspect archive integrity, image dimensions, animation frame counts and title/menu paths.
- [x] Confirm new adult replacements for the female character roles.
- [x] Generate new title artwork and two adult character animation sheets, refined to lighter outfits and a slimmer silhouette.
- [x] Pack all raster assets at 3× physical density while preserving original logical image dimensions and frame boundaries.
- [x] Refresh title/menu presentation without altering game logic.
- [x] Package a separate HD JAR and verify archive/class/image contracts.
- [x] Inspect packed assets and the 528 × 624 native renderer snapshot; document runtime limits.

Original JAR: `/Users/ducnguyen/Downloads/Snowball-Fight_J2ME_EN_v112.jar` (preserved). Sarah role: 4 idle, 4 throwing, 2 hit frames; Vic role: same counts. Replacement images retain the original logical dimensions and frame boundaries, with all PNGs packed at 3× width and height. Original male player, male enemy, animals, difficulty, physics and collision logic remain unchanged.

Clothing direction updated by user: lighter athletic outfits on the new adult cast. A cropped-outfit edit was rejected by Image Gen; final direction uses regular tank tops and mid-thigh sports shorts.

## HD output

- [x] Output a 528 × 624 framebuffer (exactly 3× the original 176 × 208 ratio).
- [x] Add opt-in 2D rendering and asset-density metadata to the JAR and Delta renderer.
- [x] Keep Java Canvas/image dimensions and gameplay coordinates unchanged.
- [x] Scale mutable contexts, source-region crops, RGB reads and memory accounting consistently.
- [x] Leave ordinary JARs on 1× rendering by default; verify baseline behavior.
- [x] Complete a full arm64 Simulator build.
- [ ] User to verify HD gameplay on their iPhone and provide feedback. Further HD gameplay retesting by the agent was explicitly cancelled.

Deliverable: `output/snowball-modernized/Snowball-Fight-Modernized-HD.jar`. Rebuild Delta with the renderer changes before importing it. Automatic screen configuration reads 176 × 208 as the logical size; actual rendering is 528 × 624. Existing manual screen overrides remain authoritative. This density extension targets this updated Delta build; other emulators may treat the image assets as ordinary larger images.

The title screen adds keyboard/D-pad navigation for five existing actions (Play, How to Play, Leaderboard, Difficulty, About). All original title loading methods and all other game class files remain byte-for-byte unchanged. The original JAR in Downloads is preserved. New character sheets replace the two female presentation roles; other gameplay raster art is integer-upscaled rather than repainted.

Validation: `tools/package.py` checks archive CRCs, all 29 PNG dimensions at exact 3× density, and unchanged gameplay/loading methods. `tools/run_hd_checks.py` runs the same miniJVM interpreter and real Core Graphics rendering code on macOS with forms/audio/input fixtures. Tests cover 1× baseline and 3× HD logical dimensions, mutable images, RGB reads, crop/rotation, menu mappings and selection wraparound. Native frame capture is `verification/title-menu-hd.png`; exact framebuffer dimensions checked as 528 × 624. The original leaderboard route was separately exercised in the host probe. These checks do not certify physical-device playback or audio.

Regenerate the local renderer overlay with `tools/build_hd_renderer.py`; the pinned JarBox checkout is untouched. The app reads opt-in `Delta-J2ME-Render-Scale` and `Delta-J2ME-Asset-Scale` properties, bounds scale to 1–3, and limits the framebuffer's longest edge to 2048 pixels. Pixel-density changes increase memory use; physical pixel allocations and releases use the scaled dimensions in the native heap accounting.

## Latest simulator evidence

The HD JAR reached the title menu in the iOS simulator. Play was not tested; physical-device loading behavior remains unverified. The user will test the game. The subsequently reported native audio close crash is addressed by the app ownership fix documented in `design/j2me-controls/IMPLEMENTATION.md`.
