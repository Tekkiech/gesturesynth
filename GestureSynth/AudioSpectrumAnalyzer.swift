import AVFoundation
import Accelerate

/// Real-time frequency-spectrum analysis of the synth's actual audio output —
/// a cava-style bar visualizer needs real band magnitudes, not a restated
/// gesture value. FFT via Accelerate/vDSP, which is itself SIMD-accelerated on
/// Apple Silicon.
///
/// @unchecked Sendable: `displayedBands` and the FFT scratch buffers are only
/// ever touched from the audio tap's own callback, which AVAudioEngine invokes
/// serially — never concurrently with itself.
final class AudioSpectrumAnalyzer: @unchecked Sendable {
    var onBands: (@Sendable ([Float]) -> Void)?

    private let bandCount: Int
    private let fftSize = 2048
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private let window: [Float]
    private var displayedBands: [Float]

    init(bandCount: Int) {
        self.bandCount = bandCount
        self.displayedBands = Array(repeating: 0, count: bandCount)
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = window
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func installTap(on node: AVAudioNode, busIndex: Int = 0) {
        let format = node.outputFormat(forBus: busIndex)
        node.installTap(onBus: busIndex, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
    }

    func removeTap(from node: AVAudioNode, busIndex: Int = 0) {
        node.removeTap(onBus: busIndex)
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        var samples = [Float](repeating: 0, count: fftSize)
        let copyCount = min(frameCount, fftSize)
        samples.withUnsafeMutableBufferPointer { dst in
            dst.baseAddress!.update(from: channelData[0], count: copyCount)
        }

        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)

        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { windowedPtr in
                    windowedPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(fftSize / 2))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        let targetBands = bandMagnitudes(from: magnitudes, sampleRate: buffer.format.sampleRate)
        let smoothedBands = smooth(targetBands)
        onBands?(smoothedBands)
    }

    /// Log-spaced bands (roughly how cava buckets frequencies, and how pitch
    /// is perceived) from 40Hz up to 8kHz or Nyquist, whichever is lower.
    private func bandMagnitudes(from magnitudes: [Float], sampleRate: Double) -> [Float] {
        let minFreq = 40.0
        let maxFreq = min(sampleRate / 2, 8000)
        let binHz = sampleRate / Double(fftSize)

        var result = [Float](repeating: 0, count: bandCount)
        for band in 0..<bandCount {
            let t0 = Double(band) / Double(bandCount)
            let t1 = Double(band + 1) / Double(bandCount)
            let f0 = minFreq * pow(maxFreq / minFreq, t0)
            let f1 = minFreq * pow(maxFreq / minFreq, t1)
            let bin0 = max(1, Int(f0 / binHz))
            let bin1 = min(magnitudes.count - 1, max(bin0 + 1, Int(f1 / binHz)))

            var peak: Float = 0
            for bin in bin0..<bin1 {
                peak = max(peak, magnitudes[bin])
            }
            // Raw FFT power spans a huge range; compress to dB and normalize
            // to a 0-1 bar height over a ~60dB working range.
            let db = 10 * log10(peak + 1e-9)
            let normalized = (db + 60) / 60
            result[band] = Float(max(0, min(1, normalized)))
        }
        return result
    }

    /// Fast attack, slow decay — the actual "bounce" that makes a bar
    /// visualizer read as alive rather than flickering with the raw FFT.
    private func smooth(_ target: [Float]) -> [Float] {
        for i in 0..<bandCount {
            let rising = target[i] > displayedBands[i]
            let factor: Float = rising ? 0.6 : 0.12
            displayedBands[i] += (target[i] - displayedBands[i]) * factor
        }
        return displayedBands
    }
}
