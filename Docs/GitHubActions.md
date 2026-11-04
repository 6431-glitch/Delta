# GitHub Actions integration

## Current status

- [x] Prepare a read-only pull-request and push workflow with a separate Swift contract job and a recursive-checkout / simulator-build job.
- [x] Pin the checkout action to a commit and do not persist its credentials in the checkout.
- [x] Use Git-pinned submodule commits, fail explicitly if a submodule cannot be fetched, and never substitute another revision.
- [x] Parse the workflow YAML and run the Swift package tests locally.
- [ ] Validate the workflow on GitHub-hosted runners; local execution does not establish that the GitHub jobs pass.
- [x] Publish the local dependency commits and nested compatibility changes to the public `6431-glitch` forks; update `.gitmodules` and gitlinks locally.
- [ ] Verify a clean recursive clone, LFS hydration, and simulator build from the exact PR commit on a clean machine.
- [ ] Commit and push the workflow and dependency fixes; verify both jobs on GitHub before making either a required check or merging.

The local dependency commits have been published to `integration/delta-ci` branches in the six `6431-glitch` forks. Delta points to the DeltaCore, SNESDeltaCore, GPGXDeltaCore, and DeltaOperator forks; DeltaCore points to the ZIPFoundation fork, and SNESDeltaCore points to the snes9x fork. The parent branch must still be pushed and validated from a clean recursive checkout. A parent-repository push alone does not publish submodule objects.

Preserve exact revisions; do not silently fall back to upstream HEAD. If dependencies become private, use narrowly scoped read-only credentials in a separately reviewed workflow, including a plan for forked pull requests; the provided workflow assumes public dependencies and adds no personal tokens or signing secrets.

The simulator job must be verified against a clean checkout of the published parent commit. A green Swift contracts job alone does not mean the app built. The workflow builds an unsigned simulator app; it does not run physical-device, AirDrop, signing, or deployment checks. On the current GitHub-hosted macOS 26 image it selects Xcode 26.6; runner images can change, so the workflow should be updated deliberately when that toolchain is retired. The nested Xcode 27 compatibility changes are published; a GitHub-hosted Xcode 27 build still needs its own validation.
