import AVFoundation
import os

enum Waveform {
    case sine, triangle, square, sawtooth

    func sample(phase: Double) -> Double {
        switch self {
        case .sine:
            return sin(2 * .pi * phase)
        case .triangle:
            return 2 * abs(2 * (phase - floor(phase + 0.5))) - 1
        case .square:
            return phase < 0.5 ? 1 : -1
        case .sawtooth:
            return 2 * (phase - floor(phase + 0.5))
        }
    }
}

/// Tiny lock-protected box for state shared between the gesture-processing
/// thread (writer) and the real-time audio render thread (reader). A plain var
/// would be a data race under Swift 6's strict concurrency checking even though
/// torn reads can't happen for a word-sized value on this hardware; os_unfair_lock
/// makes it a real, cheap, Sendable-correct fix instead of papering over it.
private final class Box<T>: @unchecked Sendable {
    private var _value: T
    private var lock = os_unfair_lock()

    init(_ value: T) { _value = value }

    var value: T {
        get {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            return _value
        }
        set {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            _value = newValue
        }
    }
}

/// One oscillator voice. Unlike the original's disposable Web Audio
/// `OscillatorNode`s (created/destroyed on every chord change), this stays
/// attached to the engine for the app's lifetime — Core Audio's real-time graph
/// prefers long-lived nodes whose parameters change, not nodes that churn.
/// A chord change just retunes frequency/isActive on the existing voices.
final class Voice {
    let sourceNode: AVAudioSourceNode

    private let frequencyBox = Box<Double>(220)
    private let activeBox = Box<Bool>(false)

    var frequency: Double {
        get { frequencyBox.value }
        set { frequencyBox.value = newValue }
    }
    var isActive: Bool {
        get { activeBox.value }
        set { activeBox.value = newValue }
    }

    init(sampleRate: Double, waveform: Waveform) {
        let frequencyBox = self.frequencyBox
        let activeBox = self.activeBox
        var phase: Double = 0

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let mData = buffers[0].mData else { return noErr }
            let out = mData.assumingMemoryBound(to: Float.self)

            let freq = frequencyBox.value
            let active = activeBox.value

            for frame in 0..<Int(frameCount) {
                if active {
                    // Soft-clip stand-in for the original's WaveShaperNode.
                    out[frame] = Float(tanh(waveform.sample(phase: phase) * 1.5))
                    phase += freq / sampleRate
                    if phase >= 1 { phase -= 1 }
                } else {
                    out[frame] = 0
                }
            }
            return noErr
        }
    }
}

/// AVAudioEngine port of the original's `SynthEngine`: up to 4 voices -> shared
/// soft-clip (folded into each voice's render block) -> resonant lowpass ->
/// master volume -> output. Signal-chain intent matches the original 1:1; the
/// node topology differs because Web Audio's disposable-oscillator model
/// doesn't fit Core Audio's real-time graph.
final class SynthEngine {
    private let engine = AVAudioEngine()
    private let voiceMixer = AVAudioMixerNode()
    private let lowpass = AVAudioUnitEQ(numberOfBands: 1)
    private let spectrumAnalyzer = AudioSpectrumAnalyzer(bandCount: 32)
    private var voices: [Voice] = []
    private var currentKey: String?

    // Matches the original web app's default "Warm Synth" (toneSelect's selected option).
    private let waveform: Waveform = .triangle

    /// Spectrum bands (0-1 magnitude each) for the corner visualizer, tapped
    /// straight off the actual final output — silent when the master volume is.
    var onSpectrum: (@Sendable ([Float]) -> Void)? {
        get { spectrumAnalyzer.onBands }
        set { spectrumAnalyzer.onBands = newValue }
    }

    init() {
        let hwSampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = hwSampleRate > 0 ? hwSampleRate : 44100

        voices = (0..<4).map { _ in Voice(sampleRate: sampleRate, waveform: waveform) }

        let band = lowpass.bands[0]
        band.filterType = .resonantLowPass
        band.frequency = 1200
        band.bandwidth = qToBandwidth(0.7)
        band.bypass = false

        engine.attach(voiceMixer)
        engine.attach(lowpass)
        for voice in voices {
            engine.attach(voice.sourceNode)
            engine.connect(voice.sourceNode, to: voiceMixer, format: nil)
        }
        engine.connect(voiceMixer, to: lowpass, format: nil)
        engine.connect(lowpass, to: engine.mainMixerNode, format: nil)

        engine.mainMixerNode.outputVolume = 0
    }

    func start() {
        engine.prepare()
        spectrumAnalyzer.installTap(on: engine.mainMixerNode)
        do {
            try engine.start()
        } catch {
            print("SynthEngine failed to start: \(error)")
        }
    }

    func stop() {
        setVolume(0)
        spectrumAnalyzer.removeTap(from: engine.mainMixerNode)
        engine.stop()
    }

    func setVolume(_ volume01: Double) {
        engine.mainMixerNode.outputVolume = Float(max(0, min(1, volume01)))
    }

    /// tiltFactor in [-1, 1]: negative = inward "acoustic warmth", positive = outward "EDM squelch".
    func updateFilterSweep(tiltFactor: Double) {
        var targetFrequency = 1200.0
        var targetQ = 0.7

        if tiltFactor < 0 {
            let intensity = abs(tiltFactor)
            targetFrequency = 1200 - (intensity * 950)
            targetQ = 0.7 + (intensity * 1.5)
        } else if tiltFactor > 0 {
            targetFrequency = 1200 + (tiltFactor * 3800)
            targetQ = 0.7 + (tiltFactor * 4.5)
        }

        let band = lowpass.bands[0]
        band.frequency = Float(targetFrequency)
        band.bandwidth = qToBandwidth(targetQ)
    }

    /// Retunes the voice pool to `freqs` (up to 4 tones), skipping the work
    /// entirely if this is the same chord already playing — mirrors the
    /// original's dedupe-by-frequency-key so a held chord doesn't retrigger
    /// every frame.
    func playNotes(_ freqs: [Double]) {
        guard !freqs.isEmpty else { return }
        let key = freqs.map { String(format: "%.1f", $0) }.joined(separator: ",")
        if key == currentKey { return }
        currentKey = key

        for (index, voice) in voices.enumerated() {
            if index < freqs.count {
                voice.frequency = freqs[index]
                voice.isActive = true
            } else {
                voice.isActive = false
            }
        }
    }
}

/// AVAudioUnitEQ's resonant filters take bandwidth in octaves (0.05-5.0), which
/// runs inverse to Web Audio's Q (higher Q = narrower = smaller bandwidth). This
/// is an approximation of the original's BiquadFilterNode resonance — expect to
/// ear-tune it once you can actually hear the filter sweep.
private func qToBandwidth(_ q: Double) -> Float {
    Float(max(0.05, min(5.0, 1.0 / max(q, 0.05))))
}
