# Where to work

Work on this repo on the macOS runner `wip-amp-app`, not in an orb. Only that Mac has Xcode, the simulators and a cable to Mikhail's iPhone, so an orb can't build, run or verify the app.

# Verifying changes

Always verify every change on Mikhail's iPhone, not only in the simulator. Build and install from `wip-amp-app`.

- Find the phone with `xcrun devicectl list devices`.
- Build for it with `xcodebuild`, using the project's signing team, then install and launch the app with `xcrun devicectl device install app` and `xcrun devicectl device process launch`.
- If the phone isn't connected, is locked, or signing fails, tell Mikhail exactly what to do. Don't report the change as verified until it has run on the phone.
