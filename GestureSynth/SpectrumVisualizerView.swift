import SwiftUI

/// Roman-numeral scale degree -> color, ported from the original's
/// SCALE_COLORS table in drawEnergy.
private let scaleDegreeColors: [String: Color] = [
    "I": Color(red: 232 / 255, green: 161 / 255, blue: 61 / 255),
    "II": Color(red: 210 / 255, green: 50 / 255, blue: 120 / 255),
    "III": Color(red: 180 / 255, green: 40 / 255, blue: 150 / 255),
    "IV": Color(red: 240 / 255, green: 210 / 255, blue: 40 / 255),
    "V": Color(red: 245 / 255, green: 120 / 255, blue: 30 / 255),
    "VI": Color(red: 230 / 255, green: 40 / 255, blue: 40 / 255),
    "VII": Color(red: 100 / 255, green: 200 / 255, blue: 250 / 255),
]
private let idleColor = Color(red: 150 / 255, green: 150 / 255, blue: 150 / 255)

/// A cava-style bar spectrum of the synth's actual output audio (see
/// AudioSpectrumAnalyzer for the FFT), colored by the current scale degree —
/// real audio reactivity instead of just redrawing a gesture value.
struct SpectrumVisualizerView: View {
    let bands: [Float]
    let chordState: VisualizerState

    private var color: Color {
        guard let chord = chordState.chord else { return idleColor }
        return scaleDegreeColors[chord.uppercased()] ?? idleColor
    }

    private var brightness: Double {
        guard chordState.chord != nil else { return 0.4 }
        return chordState.isMajorMode ? 1.0 : 0.7
    }

    var body: some View {
        Canvas { context, size in
            guard !bands.isEmpty else { return }
            let spacing: CGFloat = 3
            let barWidth = (size.width - spacing * CGFloat(bands.count - 1)) / CGFloat(bands.count)

            for (index, magnitude) in bands.enumerated() {
                let barHeight = max(2, CGFloat(magnitude) * size.height)
                let x = CGFloat(index) * (barWidth + spacing)
                let rect = CGRect(x: x, y: size.height - barHeight, width: barWidth, height: barHeight)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 3),
                    with: .color(color.opacity(brightness))
                )
            }
        }
        .frame(width: 240, height: 90)
        .padding(12)
        .background(.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .allowsHitTesting(false)
    }
}
