import AVFoundation
import CoreVideo

protocol CameraCaptureDelegate: AnyObject {
    func cameraCapture(_ capture: CameraCapture, didOutput pixelBuffer: CVPixelBuffer)
}

enum CameraCaptureError: Error {
    case noCameraAvailable
    case cannotConfigureSession
}

/// @unchecked Sendable: its mutable state (the session, the delegate) is only
/// ever touched from well-defined entry points — start()/stop() called once
/// each from a controlled call site, and its own capture callback always
/// firing serially on `outputQueue` — never concurrently with itself.
final class CameraCapture: NSObject, @unchecked Sendable {
    weak var delegate: CameraCaptureDelegate?

    let session = AVCaptureSession()
    private let outputQueue = DispatchQueue(label: "com.isaacolukanni.gesturesynth.camera-output")

    /// Blocks until the session starts running — call from a background queue, never the main thread.
    func start() throws {
        session.beginConfiguration()
        // Higher resolution gives Vision's pose estimator more detail to work
        // with; on Apple Silicon this is still comfortably real-time.
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(for: .video) else {
            session.commitConfiguration()
            throw CameraCaptureError.noCameraAvailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraCaptureError.cannotConfigureSession
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: outputQueue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw CameraCaptureError.cannotConfigureSession
        }
        session.addOutput(output)

        session.commitConfiguration()
        session.startRunning()
    }

    func stop() {
        session.stopRunning()
    }
}

extension CameraCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        delegate?.cameraCapture(self, didOutput: pixelBuffer)
    }
}
