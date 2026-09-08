import SwiftUI
import AVFoundation

/// Wraps AVCaptureVideoPreviewLayer, unmirrored. Mirroring is applied at the
/// SwiftUI level in ContentView (`.scaleEffect(x: -1, y: 1)` on this view
/// grouped together with its landmark-dot overlay), not here — that way both
/// mirror as a single unit and can't drift out of alignment with each other.
/// The pixel buffer handed to Vision for hand tracking is never mirrored either
/// way, so the gesture math's x-position comparisons don't need adjusting.
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {}
}

final class PreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = previewLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
