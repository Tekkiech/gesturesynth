import AVFoundation
import Foundation

struct PreviewHand: Identifiable {
    let id = UUID()
    let handedness: Handedness
    let landmarks: [Landmark]
}

/// Chord context for the corner visualizer's coloring — bar heights come from
/// a real FFT of the synth's output (see AudioSpectrumAnalyzer), but the color
/// still follows the scale degree, same table the original's `drawEnergy` used.
struct VisualizerState: Equatable {
    var chord: String?
    var isMajorMode: Bool = true
}

/// Orchestrates the whole pipeline, replicating the original main.js `loop()`:
/// camera frame -> hand tracking -> role-based gesture reads -> stabilization ->
/// chord/voicing -> synth. Lives on the main actor since the per-frame work here
/// is cheap arithmetic, not audio rendering itself; the camera/Vision work that
/// actually runs on a background queue is isolated in `CaptureAndTrackingPipeline`
/// below so it never has to touch main-actor-isolated state directly.
@MainActor
final class GestureSynthController: ObservableObject {
    @Published var previewHands: [PreviewHand] = []
    @Published var chordDisplayText: String = "--"
    @Published var qualityDisplayText: String = "--"
    @Published var cameraError: String?
    @Published var visualizerState = VisualizerState()
    @Published var spectrumBands: [Float] = Array(repeating: 0, count: 32)
    @Published var videoDimensions = CGSize(width: 1280, height: 720)

    /// Flip if chord/voicing control ends up on the wrong hand once you're
    /// actually testing this live — Vision can't tell left from right the way
    /// MediaPipe's handedness classifier could (see HandTracker).
    var swapHandRoles: Bool {
        get { pipeline.swapHandRoles }
        set { pipeline.swapHandRoles = newValue }
    }

    var cameraSession: AVCaptureSession { pipeline.cameraSession }

    private let pipeline = CaptureAndTrackingPipeline()
    private let stabilizer = ChordStateStabilizer()
    private let synth = SynthEngine()

    // v1 hardcoded defaults, matching the original web app's default <select> values
    // (key/waveform pickers are an explicit follow-up, not part of this pass).
    private let tonicFreq: Double = 220.00 // A
    private let keyName = "A"

    func start() {
        synth.onSpectrum = { [weak self] bands in
            Task { @MainActor in
                self?.spectrumBands = bands
            }
        }
        synth.start()
        pipeline.onHands = { [weak self] hands, now, videoDimensions in
            Task { @MainActor in
                self?.processFrame(hands: hands, now: now, videoDimensions: videoDimensions)
            }
        }
        pipeline.onError = { [weak self] message in
            Task { @MainActor in
                self?.cameraError = message
            }
        }
        pipeline.start()
    }

    func stop() {
        pipeline.stop()
        synth.stop()
    }

    private func processFrame(hands: [TrackedHand], now: Double, videoDimensions: CGSize) {
        self.videoDimensions = videoDimensions

        let leftLandmarks = hands.first { $0.handedness == .left }?.landmarks
        let rightLandmarks = hands.first { $0.handedness == .right }?.landmarks

        var rawChord: String?
        var rawMode = true
        var rawQualityIndex = 0
        var rawThumbDown = false

        if let leftLandmarks {
            let leftTilt = getHandHorizontalTilt(leftLandmarks, .left)
            rawChord = classifyChord(leftLandmarks, .left)
            rawMode = leftTilt >= 0
        }

        if let rightLandmarks {
            rawQualityIndex = getRightHandQualityIndex(rightLandmarks)
            rawThumbDown = isThumbExtended(rightLandmarks, .right)
        }

        let rawState: ChordState? = rawChord.map {
            ChordState(chord: $0, isMajorMode: rawMode, qualityIndex: rawQualityIndex, thumbDown: rawThumbDown)
        }
        let stableState = stabilizer.stabilize(rawState, now: now)

        let currentChord = stableState?.chord
        let isMajorMode = stableState?.isMajorMode ?? true
        let qualityIndex = stableState?.qualityIndex ?? 0
        let thumbDown = stableState?.thumbDown ?? false

        let volume = rightLandmarks.map(getVolumeFromHeight) ?? 0
        let tilt = rightLandmarks.map { getHandHorizontalTilt($0, .right) } ?? 0

        if rightLandmarks != nil {
            synth.updateFilterSweep(tiltFactor: tilt)

            if let currentChord, qualityIndex >= 1 {
                let tones = getChordTones(currentChord, isMajorMode: isMajorMode, tonicFreq: tonicFreq)
                var notes = getSolidNotes(tones, rightHandCount: qualityIndex, isMajorMode: isMajorMode)
                if thumbDown {
                    notes = notes.map { $0 / 2 }
                }
                synth.playNotes(notes)
                synth.setVolume(volume)
            } else {
                synth.setVolume(0)
            }
        } else {
            synth.setVolume(0)
        }

        updateDisplay(currentChord: currentChord, isMajorMode: isMajorMode, qualityIndex: qualityIndex, thumbDown: thumbDown)
        visualizerState = VisualizerState(chord: currentChord, isMajorMode: isMajorMode)
        previewHands = hands.map { PreviewHand(handedness: $0.handedness, landmarks: $0.landmarks) }
    }

    private func updateDisplay(currentChord: String?, isMajorMode: Bool, qualityIndex: Int, thumbDown: Bool) {
        if let currentChord {
            let chordName = getChordName(currentChord, isMajorMode: isMajorMode, keyName: keyName)
            chordDisplayText = "\(chordName)(\(currentChord))"
        } else {
            chordDisplayText = "--"
        }

        let majorLabels = [1: "Major", 2: "Major 1st Inv", 3: "Major 7th", 4: "Dominant 7th"]
        let minorLabels = [1: "Minor", 2: "Minor 1st Inv", 3: "Minor 7th", 4: "Diminished 7th"]
        let activeLabel = (isMajorMode ? majorLabels : minorLabels)[qualityIndex]
        qualityDisplayText = activeLabel.map { thumbDown ? "\($0) (-8ve)" : $0 } ?? "--"
    }
}

/// Owns the camera capture session and the Vision hand tracker, entirely off
/// the main actor. Deliberately NOT actor-isolated: its delegate callback fires
/// on the camera's background queue, and giving it its own plain-class identity
/// (rather than being stored directly on `GestureSynthController`) means that
/// callback never has to reach into main-actor-isolated state — it just hands
/// finished, plain-value-type results (`[TrackedHand]`) to the closures below,
/// which the controller hops onto the main actor itself.
private final class CaptureAndTrackingPipeline: CameraCaptureDelegate {
    var onHands: (@Sendable ([TrackedHand], Double, CGSize) -> Void)?
    var onError: (@Sendable (String) -> Void)?

    var swapHandRoles: Bool {
        get { handTracker.swapHandRoles }
        set { handTracker.swapHandRoles = newValue }
    }

    var cameraSession: AVCaptureSession { camera.session }

    private let camera = CameraCapture()
    private let handTracker = HandTracker()
    private let smoother = LandmarkSmoother()

    init() {
        camera.delegate = self
    }

    func start() {
        DispatchQueue.global(qos: .userInitiated).async { [camera, onError] in
            do {
                try camera.start()
            } catch {
                onError?("Camera failed to start: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        camera.stop()
    }

    func cameraCapture(_ capture: CameraCapture, didOutput pixelBuffer: CVPixelBuffer) {
        let rawHands = handTracker.track(pixelBuffer: pixelBuffer)
        let hands = smoother.smooth(rawHands)
        let now = ProcessInfo.processInfo.systemUptime * 1000
        let videoDimensions = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )
        onHands?(hands, now, videoDimensions)
    }
}
