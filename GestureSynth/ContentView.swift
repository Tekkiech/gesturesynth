import SwiftUI

/// The source-space rectangle that's actually visible once `source` is
/// cropped (not stretched) to fill `destination` — i.e. what videoGravity
/// .resizeAspectFill shows. Ported from the original's `computeCoverRect`.
private func coverCropRect(source: CGSize, destination: CGSize) -> CGRect {
    let sourceRatio = source.width / source.height
    let destinationRatio = destination.width / destination.height

    if sourceRatio > destinationRatio {
        let height = source.height
        let width = source.height * destinationRatio
        return CGRect(x: (source.width - width) / 2, y: 0, width: width, height: height)
    } else {
        let width = source.width
        let height = source.width / destinationRatio
        return CGRect(x: 0, y: (source.height - height) / 2, width: width, height: height)
    }
}

/// Standard 21-point hand-landmark skeleton connections (wrist=0 through
/// pinky tip=20), including the palm's cross-knuckle connections. Drawing
/// these alongside the dots makes tracking quality much easier to read at a
/// glance than disconnected points.
private let handConnections: [(Int, Int)] = [
    (0, 1), (1, 2), (2, 3), (3, 4),
    (0, 5), (5, 6), (6, 7), (7, 8),
    (0, 9), (9, 10), (10, 11), (11, 12),
    (0, 13), (13, 14), (14, 15), (15, 16),
    (0, 17), (17, 18), (18, 19), (19, 20),
    (5, 9), (9, 13), (13, 17),
]

/// Key and waveform pickers, matching the original's `keySelect`/`toneSelect`
/// (same top-left placement, same options).
private struct KeyAndToneControls: View {
    @Binding var selectedKey: MusicalKey
    @Binding var selectedWaveform: Waveform

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Key", selection: $selectedKey) {
                ForEach(musicalKeys) { key in
                    Text(key.displayName).tag(key)
                }
            }
            .labelsHidden()
            .frame(width: 140)

            Picker("Tone", selection: $selectedWaveform) {
                ForEach(Waveform.allCases, id: \.self) { waveform in
                    Text(waveform.displayName).tag(waveform)
                }
            }
            .labelsHidden()
            .frame(width: 140)
        }
        .pickerStyle(.menu)
        .padding(12)
        .background(.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.white)
    }
}

struct ContentView: View {
    @StateObject private var controller = GestureSynthController()

    var body: some View {
        ZStack {
            // Preview and dot overlay are mirrored together as one unit, so
            // they can't drift out of alignment with each other the way they
            // would if each computed its own separate flip.
            ZStack {
                CameraPreviewView(session: controller.cameraSession)

                Canvas { context, size in
                    // The preview uses .resizeAspectFill, which crops the
                    // captured buffer to cover the window rather than
                    // letterboxing it. Map each landmark through the same
                    // crop, matching the original's computeCoverRect, or dots
                    // drift off wherever the aspect ratios diverge.
                    let sourceSize = controller.videoDimensions
                    let cropRect = coverCropRect(source: sourceSize, destination: size)

                    func screenPoint(_ point: Landmark) -> CGPoint {
                        let videoX = point.x * sourceSize.width
                        let videoY = point.y * sourceSize.height
                        return CGPoint(
                            x: ((videoX - cropRect.minX) / cropRect.width) * size.width,
                            y: ((videoY - cropRect.minY) / cropRect.height) * size.height
                        )
                    }

                    for hand in controller.previewHands {
                        let color: Color = hand.handedness == .left ? .orange : .cyan
                        guard hand.landmarks.count == 21 else { continue }
                        let points = hand.landmarks.map(screenPoint)

                        var skeleton = Path()
                        for (a, b) in handConnections {
                            skeleton.move(to: points[a])
                            skeleton.addLine(to: points[b])
                        }
                        context.stroke(skeleton, with: .color(color.opacity(0.7)), lineWidth: 2)

                        for point in points {
                            let rect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                            context.fill(Path(ellipseIn: rect), with: .color(color))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
            .scaleEffect(x: -1, y: 1)
            .ignoresSafeArea()

            VStack {
                HStack {
                    KeyAndToneControls(selectedKey: $controller.selectedKey, selectedWaveform: $controller.selectedWaveform)
                        .padding(24)
                    Spacer()
                    SpectrumVisualizerView(bands: controller.spectrumBands, chordState: controller.visualizerState)
                        .padding(24)
                }
                Spacer()
                VStack(spacing: 4) {
                    Text(controller.chordDisplayText)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text(controller.qualityDisplayText)
                        .font(.system(size: 20, weight: .medium))
                    if let cameraError = controller.cameraError {
                        Text(cameraError)
                            .foregroundStyle(.red)
                    }
                }
                .padding(24)
                .background(.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
                .padding(.bottom, 40)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }
}

#Preview {
    ContentView()
}
