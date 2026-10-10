# Feature access without subscriptions

- [x] Remove RevenueCat SDK/package, manager, API resource reference, customer attributes, and launch initialization.
- [x] Remove the in-app subscription tiers, restore-purchase flow, and purchase warning screen.
- [x] Make experimental feature access and alternate app icons available without an account in every build configuration.
- [x] Remove subscription entries and feature paywall prompts from modern and legacy Settings.
- [x] Keep experimental options configurable and preserve existing preferences. Database repair and debugging options are not automatically switched on.
- [x] Final Debug arm64 Simulator build succeeds; the Xcode project passes property-list validation and `git diff --check` passes. No RevenueCat references remain in app source, project dependencies, or package pins.

Patreon account data and existing contributor credits remain intact. Patreon account changes no longer disable experimental features. Device/OS requirements and authentication for independent services such as iCloud and RetroAchievements still apply.
