# Mobile (Android/iOS)

## Overview

This game is mobile-ready: it has on-screen touch buttons (left, right, and
jump), the display scales to fit different screen sizes, and it renders with
a mobile-friendly graphics backend. None of that requires anything special
from you to *play* the game in the editor -- it already works today.

Building an actual installable app for a phone (an `.apk` for Android or an
`.ipa`/Xcode project for iOS) is a separate step that happens on your own
computer, using the Godot editor's **Export** feature. This guide walks
through both platforms.

## Testing touch on desktop

You don't need a phone to try the touch controls. The project has
`input_devices/pointing/emulate_touch_from_mouse` enabled in
`project.godot`, which makes Godot treat mouse clicks as touch events.

The three on-screen buttons (left arrow, right arrow, jump) defined in
`scenes/hud.tscn` are visible and clickable with the mouse right now, on
desktop, with no extra setup -- just run the project (F5) and click them.

If you'd rather they only appear on an actual touchscreen (hiding them when
running on desktop), select each `TouchScreenButton` node in `scenes/hud.tscn`
and, in the Inspector, change **Visibility Mode** from its default to
**TouchScreen Only**. Do this for `LeftButton`, `RightButton`, and
`JumpButton`.

## Android walkthrough

1. **Get the export templates.** In the Godot editor: **Editor → Manage
   Export Templates…** → **Download and Install**. This downloads the
   platform runtimes Godot needs to build an APK.
2. **Install the Android toolchain.** You need the Android SDK and a JDK.
   The easiest path is installing [Android Studio](https://developer.android.com/studio),
   which bundles the SDK; alternatively install just the
   [command-line SDK tools](https://developer.android.com/studio#command-tools).
   You also need **JDK 17**.
3. **Point Godot at your SDK.** In the editor: **Editor Settings → Export →
   Android**, and set the Android SDK path to wherever you installed it.
4. **Get a debug keystore.** For local testing/debug builds you need a debug
   signing keystore. Godot 4.3 can auto-generate one the first time you
   export a debug build, or you can create one yourself with a one-liner:
   ```
   keytool -genkey -v -keystore debug.keystore -storepass android \
     -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
     -validity 10000
   ```
5. **Deploy to a phone over USB**, one of two ways:
   - Enable **USB debugging** on the phone (Developer Options), plug it in,
     and use the little remote-debug/"one-click deploy" button in the
     editor's top-right toolbar (next to the Play button) to install and
     run the game directly on the device.
   - Or export a file: **Project → Export…**, select the already-configured
     **Android** preset (package `com.example.platformer`), and click
     **Export Project**. This writes the APK to `builds/platformer.apk`.

Release builds meant for the Play Store need your own release keystore for
signing -- the committed export preset intentionally contains no keys or
passwords, only the plain build configuration.

## iOS walkthrough

Building for iOS requires a **Mac** with **Xcode** installed, plus an Apple
Developer account. A free Apple ID works for testing on your own device; the
paid **Apple Developer Program** ($99/year) is needed for App Store
distribution (and for some device-testing scenarios, like longer-lived
provisioning).

1. **Get the export templates**, same as above: **Editor → Manage Export
   Templates…**.
2. **Export the Xcode project.** **Project → Export…**, select the
   already-configured **iOS** preset (bundle id `com.example.platformer`),
   and export. Unlike Android, this doesn't produce a final app directly --
   it generates an Xcode project.
3. **Open the exported project in Xcode.**
4. **Set your Team.** Under the project's **Signing & Capabilities** tab,
   choose your Apple ID / Developer Team so Xcode can sign the app.
5. **Run on your device** from Xcode, with your iPhone/iPad connected (or
   selected as the run destination if using wireless debugging).

## Where builds go

Both presets export into a `builds/` directory at the repository root
(`builds/platformer.apk` for Android, `builds/platformer.ipa`/Xcode project
for iOS). `builds/` is listed in `.gitignore`, so exported binaries never get
committed -- only the source project and its plain-text export
configuration (`export_presets.cfg`) are tracked.

## Troubleshooting

- **"Template version mismatch" / export fails immediately** -- the
  installed export templates must match your Godot editor's version exactly
  (e.g. 4.3.stable templates for a 4.3.stable editor). Re-run **Editor →
  Manage Export Templates…** if you upgraded the editor.
- **Android: "Android SDK not found" / similar path errors** -- double check
  the SDK path under **Editor Settings → Export → Android**, and confirm a
  JDK 17 is installed and discoverable.
- **iOS: signing errors in Xcode** -- almost always a Team selection issue.
  Open **Signing & Capabilities** in Xcode and make sure a Team is chosen
  and "Automatically manage signing" is enabled.
