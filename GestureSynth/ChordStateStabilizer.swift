import Foundation

struct ChordState: Equatable {
    var chord: String
    var isMajorMode: Bool
    var qualityIndex: Int
    var thumbDown: Bool
}

/// Debounces the raw per-frame chord reading so single flickery frames from the
/// hand tracker don't cut or retrigger the sound. Ported from the original's
/// `stabilizeChordState`: a new chord must hold for `chordHoldTimeMs` before it
/// becomes "stable", and a brief tracking dropout (< `vibeNullWindowMs`) is
/// bridged by keeping the last candidate instead of treating it as silence.
final class ChordStateStabilizer {
    private let chordHoldTimeMs: Double = 100
    private let vibeNullWindowMs: Double = 50

    private var stableChordState: ChordState?
    private var candidateChordState: ChordState?
    private var candidateChordSince: Double = 0
    private var lastChordSeenValidTime: Double = 0

    /// `now` should be a monotonically increasing millisecond timestamp.
    func stabilize(_ rawState: ChordState?, now: Double) -> ChordState? {
        if rawState != nil {
            lastChordSeenValidTime = now
        }

        var effectiveState = rawState
        if rawState == nil && now - lastChordSeenValidTime < vibeNullWindowMs {
            effectiveState = candidateChordState
        }

        if effectiveState != candidateChordState {
            candidateChordState = effectiveState
            candidateChordSince = now
        }

        if now - candidateChordSince >= chordHoldTimeMs {
            stableChordState = candidateChordState
        }

        return stableChordState
    }
}
