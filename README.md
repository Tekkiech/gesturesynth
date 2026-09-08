# GestureSynth

A camera-based instrument. Your left hand picks the chord, your right hand controls voicing and volume. This is a native macOS rewrite of [ericwei97-cloud/gesture-synth](https://github.com/ericwei97-cloud/gesture-synth), which ran the same idea in a browser with MediaPipe and Web Audio. This version uses Apple's Vision framework for hand tracking, accelerated by the Neural Engine on Apple Silicon, and AVAudioEngine for the synth itself.

![Control scheme: left hand picks the chord, right hand shapes it](docs/control-scheme.svg)

## Requirements

- macOS 14 (Sonoma) or later
- A Mac with a camera, built-in or external
- Apple Silicon gets hand tracking on the Neural Engine; Intel Macs still work, Vision just falls back to the GPU or CPU

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

## How it works

A `VNDetectHumanHandPoseRequest`, reused through a persistent `VNSequenceRequestHandler`, tracks up to two hands per camera frame and hands back 21 landmarks each. From there the pipeline is mostly ported straight from the original: the same finger-extended checks, the same chord and voicing tables, the same 100ms debounce on chord changes so single flickery frames don't cut the sound.

Vision has no left/right classifier the way MediaPipe does, so hand roles are inferred from position instead: whichever hand is on which side, corrected for the fact that the camera buffer is unmirrored while the on-screen preview is mirrored for display. If you cross your hands, it can get confused, which is the one real gap next to the original.

The synth itself is a small AVAudioEngine graph: up to four oscillator voices, a resonant lowpass filter driven by hand tilt, and a real FFT (via Accelerate/vDSP) feeding the spectrum visualizer in the corner.

## Known limitations

- Hand roles are inferred from screen position, not true handedness. Works fine for normal playing, breaks if you cross your hands.
- Not notarized (see Gatekeeper above).
- Key and waveform are fixed at A and a triangle wave. The original had pickers for both; this rewrite hasn't added the UI for it yet.

## Credits

Design and the original browser implementation: [Eric Wei](https://github.com/ericwei97-cloud), [gesture-synth](https://github.com/ericwei97-cloud/gesture-synth). See [LICENSE](LICENSE) for terms, which carry forward from the original: personal and non-commercial use is fine, commercial use needs permission.
