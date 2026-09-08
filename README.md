# GestureSynth

A camera-based instrument. Your left hand picks the chord, your right hand controls voicing and volume. This is a native macOS rewrite of [ericwei97-cloud/gesture-synth](https://github.com/ericwei97-cloud/gesture-synth), which ran the same idea in a browser with MediaPipe and Web Audio. This version uses Apple's Vision framework for hand tracking, accelerated by the Neural Engine on Apple Silicon, and AVAudioEngine for the synth itself.

## Install

1. Download `GestureSynth.dmg` from the [latest release](https://github.com/Tekkiech/gesturesynth/releases/latest).
2. Open the DMG and drag GestureSynth into Applications.
3. Launch it from Applications, not from the mounted DMG.

### Getting past Gatekeeper

The build isn't notarized. That needs a paid Apple Developer account, which this project doesn't have. So macOS blocks it on first launch with a warning that it's from an unidentified developer. Two ways around it:

- Right-click (or Control-click) GestureSynth.app in Applications and choose Open. You'll get a dialog with an actual Open button, unlike the one from double-clicking.
- Or open System Settings, go to Privacy & Security, scroll down to the Security section, and click Open Anyway next to the GestureSynth warning.

Either way, you only have to do it once. After the first successful launch it opens normally, no warnings.

The app will also ask for camera access on first run. That's required. It's the only thing GestureSynth captures, and the video never leaves your machine.

## Build from source

Requirements:

- Xcode 16 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```bash
git clone https://github.com/Tekkiech/gesturesynth.git
cd gesturesynth
xcodegen generate
open GestureSynth.xcodeproj
```

Build and run from Xcode with Cmd-R, or from the command line:

```bash
xcodebuild -project GestureSynth.xcodeproj -scheme GestureSynth -configuration Debug build
```

The `.xcodeproj` is generated from `project.yml` and checked in, so you only need to re-run `xcodegen generate` after pulling changes to `project.yml` or after adding new source files yourself.

## Controls

- **Left hand.** Finger count picks the scale degree: 1 to 5 fingers for I through V, index plus pinky for VI, add the thumb for VII. Tilt the hand left or right to switch between major and minor.
- **Right hand.** Height sets the volume. Finger count picks the voicing, root position through first inversion, a 7th, or a dominant/diminished 7th. Thumb out drops it an octave. Tilt sweeps the filter.
