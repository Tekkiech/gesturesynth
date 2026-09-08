import Foundation

/// Vision runs hand-pose detection fresh on every single frame — there's no
/// equivalent to MediaPipe's video-mode tracking state, so raw landmarks jitter
/// noticeably frame to frame. This applies a simple exponential moving average
/// per hand role, which is what's actually behind both the "dots aren't quite
/// steady" and "audio response feels twitchy" complaints: volume (wrist
/// height) and the filter sweep (wrist tilt) are read straight off these same
/// landmarks every frame with no smoothing of their own.
final class LandmarkSmoother {
    /// How much of each new frame to blend in (0-1). Lower = smoother but
    /// laggier; 0.5 cuts jitter noticeably while staying responsive at ~30fps.
    private let smoothingFactor: Double
    private var smoothed: [Handedness: [Landmark]] = [:]

    init(smoothingFactor: Double = 0.5) {
        self.smoothingFactor = smoothingFactor
    }

    func smooth(_ hands: [TrackedHand]) -> [TrackedHand] {
        var seenRoles: Set<Handedness> = []

        let result = hands.map { hand -> TrackedHand in
            seenRoles.insert(hand.handedness)

            guard let previous = smoothed[hand.handedness], previous.count == hand.landmarks.count else {
                smoothed[hand.handedness] = hand.landmarks
                return hand
            }

            let blended = zip(previous, hand.landmarks).map { prev, raw -> Landmark in
                // Trust a well-observed joint's new reading; barely move a
                // low-confidence (likely occluded/guessed) one, so a single
                // bad frame for e.g. a curled-under pinky doesn't inject a
                // jump into an otherwise-stable hand.
                let factor = max(0.05, smoothingFactor * raw.confidence)
                return Landmark(
                    x: prev.x + (raw.x - prev.x) * factor,
                    y: prev.y + (raw.y - prev.y) * factor,
                    confidence: raw.confidence
                )
            }
            smoothed[hand.handedness] = blended
            return TrackedHand(handedness: hand.handedness, landmarks: blended)
        }

        // A hand that's left the frame shouldn't leave stale history behind —
        // its next reappearance should start fresh rather than smoothing in
        // from wherever it used to be.
        for role in smoothed.keys where !seenRoles.contains(role) {
            smoothed.removeValue(forKey: role)
        }

        return result
    }
}
