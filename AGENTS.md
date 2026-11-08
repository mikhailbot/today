# Verifying changes

Always verify every change on Mikhail's iPhone, not only in the simulator. Xcode is only on the macOS runner (`wip-amp-app`), so build and install from there.

- Find the phone with `xcrun devicectl list devices`.
- Build for it with `xcodebuild`, using the project's signing team, then install and launch the app with `xcrun devicectl device install app` and `xcrun devicectl device process launch`.
- If the phone isn't connected, is locked, or signing fails, tell Mikhail exactly what to do. Don't report the change as verified until it has run on the phone.
