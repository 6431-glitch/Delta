# GitHub Actions integration

## Current status

- [x] Prepare a read-only pull-request and push workflow with a separate Swift contract job and a recursive-checkout / simulator-build job.
- [x] Pin the checkout action to a commit and do not persist its credentials in the checkout.
- [x] Use Git-pinned submodule commits, fail explicitly if a submodule cannot be fetched, and never substitute another revision.
- [x] Parse the workflow YAML and run the Swift package tests locally.
- [x] GitHub-hosted Swift contracts and simulator build passed on PR commit `186177332b67f94150dea33898cfb90916c9f83b` (CI run 41792489824).
- [x] Publish the local dependency commits and nested compatibility changes to the public `6431-glitch` forks; update `.gitmodules` and gitlinks locally.
- [x] GitHub runner checked out exact recursive submodule commits and built the unsigned simulator app.
- [ ] Independently verify that all submodule Git LFS assets are hydrated and usable at runtime.
- [x] Commit and push the workflow and dependency fixes; both jobs passed on GitHub.
- [ ] Decide whether to make the checks required in branch protection.

The local dependency commits have been published to `integration/delta-ci` branches in the nine `6431-glitch` forks. Delta points to the DeltaCore, SNESDeltaCore, GPGXDeltaCore, MelonDSDeltaCore, N64DeltaCore, and DeltaOperator forks; DeltaCore points to the ZIPFoundation fork, SNESDeltaCore points to the snes9x fork, and N64DeltaCore points to the GLideN64 fork. The parent branch has been pushed and validated by a fresh GitHub runner checkout. A parent-repository push alone does not publish submodule objects.

Preserve exact revisions; do not silently fall back to upstream HEAD. If dependencies become private, use narrowly scoped read-only credentials in a separately reviewed workflow, including a plan for forked pull requests; the provided workflow assumes public dependencies and adds no personal tokens or signing secrets.

The GitHub-hosted run after publishing the missing DS and N64 revisions passed recursive checkout and the simulator build. A green Swift contracts job alone does not mean the app built. The workflow builds an unsigned simulator app; it does not run physical-device, AirDrop, signing, or deployment checks. On the current GitHub-hosted macOS 26 image it selects Xcode 26.6; runner images can change, so the workflow should be updated deliberately when that toolchain is retired. The nested Xcode 27 compatibility changes are published; a GitHub-hosted Xcode 27 build still needs its own validation.
