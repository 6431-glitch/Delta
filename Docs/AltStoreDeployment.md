# Epsilon AltStore deployment

- [x] Select the existing `6431-glitch/altrepo` AltStore Classic source.
- [x] Adapt catalog metadata and draft-first publishing logic to Epsilon, preserving other apps and using Epsilon-specific release tags.
- [x] Run the adapted catalog and publisher contract tests.
- [x] Add merge-triggered GitHub-hosted signing and publishing, with helper contract tests and an unsigned device archive check.
- [ ] Provision the Epsilon signing certificate, provisioning profile, and narrowly scoped AltStore publishing token as protected environment secrets.
- [ ] Commit and merge the Epsilon changes and workflow before publishing.
- [ ] Produce and verify a signed Epsilon IPA and publish it to the AltStore source.
- [ ] Verify installation and updating on a physical phone, including iCloud sync and existing library preservation.

A signed archive requires a valid Apple signing identity and a provisioning profile for `page.ducnguyen.Delta`, including the CloudKit entitlement. The existing public source entry and SeamlessReader assets must be preserved. Epsilon uses its own release tag namespace to avoid collisions. Never commit credentials. A local unsigned archive is not evidence of an installable IPA.

## One-time GitHub setup

In the Delta repository's `altstore` Actions environment, set these secrets:

- `EPSILON_CERTIFICATE_P12_BASE64`: base64-encoded signing certificate and private key in a password-protected PKCS#12 file.
- `EPSILON_CERTIFICATE_PASSWORD`: the PKCS#12 password.
- `EPSILON_PROFILE_BASE64`: base64-encoded device distribution provisioning profile for the same team, bundle ID, and iCloud container.
- `ALTSTORE_PUBLISH_TOKEN`: a fine-grained token with Contents read and write access to `6431-glitch/altrepo` (the catalog and release repository).

Set the environment variable `EPSILON_TEAM_ID` to the Apple Developer team ID. Restrict access to the environment and token. The private key and token grant sensitive access; do not post them in chat or commit them. The signing setup needs its first real-device validation before it can be considered proven.

After setup, merging a pull request to `main` starts the workflow; it tests, archives, signs, uploads an immutable release and checksum, then updates the source while preserving the other entries. Each workflow run gets a new build number. A manual dispatch on `main` can recover a missed deployment. If a run has already published its assets, a retry with different signed bytes is intentionally rejected; dispatch a new run to use a fresh build number. Direct pushes do not deploy.
