import Vision
import CoreVideo
import Foundation

struct TrackedHand {
    var handedness: Handedness
    var landmarks: [Landmark]
}

/// Wraps VNDetectHumanHandPoseRequest. Unlike MediaPipe's HandLandmarker, Vision
/// has no left/right classifier, so roles are assigned by screen-space position
/// instead — but in the ANATOMICAL sense the original app means by "left
/// hand"/"right hand", not raw-buffer-left/right. The camera buffer here is
/// unmirrored (only the preview is mirrored for display), so raising your
/// actual right hand lands at the SMALLER raw x — the opposite of where it
/// visually appears on the mirrored screen. `swapHandRoles` remains as a
/// manual override in case this still doesn't land right for your setup.
///
/// Vision itself already schedules hand-pose inference onto the Neural Engine
/// when available (falling back to GPU, then CPU) — there's no manual toggle
/// for that, it's automatic. What IS in our control is not wasting cycles
/// around that inference: a `VNSequenceRequestHandler`, reused across frames,
/// is Apple's documented approach for a live video feed (as opposed to
/// `VNImageRequestHandler`, meant for one-off still images) since it skips
/// the per-call setup/teardown a fresh image handler repeats every frame.
final class HandTracker {
    var swapHandRoles = false

    private let sequenceHandler = VNSequenceRequestHandler()

    private let request: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()

    /// Joint order matching MediaPipe's 0-20 hand landmark indexing, so the
    /// ported gesture functions can index into the result the same way.
    private static let jointOrder: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip,
    ]

    func track(pixelBuffer: CVPixelBuffer) -> [TrackedHand] {
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            return []
        }

        guard let observations = request.results, !observations.isEmpty else {
            return []
        }

        // Vision will confidently return a "hand" for borderline/occluded
        // cases; a light confidence gate keeps those from injecting jittery
        // noise into the gesture math.
        let confidentObservations = observations.filter { $0.confidence > 0.3 }
        let detected = confidentObservations.compactMap(Self.landmarks(from:))

        let assigned: [TrackedHand]
        if detected.count >= 2 {
            // Two hands: sort by raw wrist x so the two roles are always
            // distinct. Smaller raw x = anatomically-right hand (see above).
            let sorted = detected.sorted { $0[0].x < $1[0].x }
            assigned = sorted.enumerated().map { index, landmarks in
                TrackedHand(handedness: index == 0 ? .right : .left, landmarks: landmarks)
            }
        } else {
            // One hand: same raw-vs-mirrored flip applies to the midpoint test.
            assigned = detected.map { landmarks in
                TrackedHand(handedness: landmarks[0].x < 0.5 ? .right : .left, landmarks: landmarks)
            }
        }

        guard swapHandRoles else { return assigned }
        return assigned.map {
            TrackedHand(handedness: $0.handedness == .left ? .right : .left, landmarks: $0.landmarks)
        }
    }

    private static func landmarks(from observation: VNHumanHandPoseObservation) -> [Landmark]? {
        var result: [Landmark] = []
        result.reserveCapacity(jointOrder.count)
        for joint in jointOrder {
            guard let point = try? observation.recognizedPoint(joint) else { return nil }
            // Vision points are normalized with origin bottom-left, y up.
            // Flip y to match the top-left/y-down convention the gesture math expects.
            result.append(Landmark(
                x: Double(point.location.x),
                y: 1 - Double(point.location.y),
                confidence: Double(point.confidence)
            ))
        }
        return result
    }
}
