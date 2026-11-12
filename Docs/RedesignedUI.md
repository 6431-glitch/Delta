# Redesigned UI transition

- [x] Set the app minimum to iOS 26, as requested.
- [x] Show the redesigned library and settings without older iOS fallback screens.
- [x] Remove the unused original Settings screen and its storyboard scenes while retaining the shared detail screens used by the redesigned settings.
- [x] Put Transfer Library in the active Accounts & Sync settings section.
- [x] Build the updated app and launch its redesigned library and Settings tabs on an iOS Simulator.
- [ ] Exercise the transfer action and remaining detail flows on Simulator and a device.
- [ ] Review the remaining app screens and replace any older interfaces that do not yet have redesigned equivalents, preserving their functionality.

Some existing controllers still supply game actions, imports, settings details, and other functionality to the redesigned interface. They must not be removed until replacements exist and are verified.
