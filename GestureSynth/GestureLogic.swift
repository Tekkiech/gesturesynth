import Foundation

/// A single hand landmark, normalized 0-1, origin top-left, y increasing downward —
/// the same convention MediaPipe used in the original web app. `HandTracker` is
/// responsible for converting Vision's bottom-left/y-up points into this convention
/// so none of the comparisons below need to change.
struct Landmark {
    var x: Double
    var y: Double
    /// Vision's per-joint confidence (0-1). Carried through so `LandmarkSmoother`
    /// can trust well-observed joints more than occluded/guessed ones; the
    /// gesture math below only ever reads x/y.
    var confidence: Double = 1
}

enum Handedness {
    case left
    case right
}

enum Finger {
    case index, middle, ring, pinky

    var pipIndex: Int {
        switch self {
        case .index: return 6
        case .middle: return 10
        case .ring: return 14
        case .pinky: return 18
        }
    }

    var tipIndex: Int {
        switch self {
        case .index: return 8
        case .middle: return 12
        case .ring: return 16
        case .pinky: return 20
        }
    }
}

func isFingerExtended(_ landmarks: [Landmark], _ finger: Finger) -> Bool {
    landmarks[finger.tipIndex].y < landmarks[finger.pipIndex].y
}

func isThumbExtended(_ landmarks: [Landmark], _ handedness: Handedness) -> Bool {
    let thumbTip = landmarks[4]
    let thumbIp = landmarks[3]
    switch handedness {
    case .right:
        return thumbTip.x > thumbIp.x
    case .left:
        return thumbTip.x < thumbIp.x
    }
}

enum ChordQuality {
    case major
    case minor
}

func getChordQuality(_ landmarks: [Landmark]) -> ChordQuality {
    let wrist = landmarks[0]
    let middleMcp = landmarks[9]
    return middleMcp.x > wrist.x ? .minor : .major
}

/// Returns a Roman numeral I-VII (upper = major, lower = minor), or nil if the
/// finger combination doesn't map to a chord degree.
func classifyChord(_ landmarks: [Landmark], _ handedness: Handedness) -> String? {
    let thumb = isThumbExtended(landmarks, handedness)
    let index = isFingerExtended(landmarks, .index)
    let middle = isFingerExtended(landmarks, .middle)
    let ring = isFingerExtended(landmarks, .ring)
    let pinky = isFingerExtended(landmarks, .pinky)

    let quality = getChordQuality(landmarks)

    if index && pinky && !middle && !ring && !thumb {
        return quality == .major ? "VI" : "vi"
    }
    if index && pinky && !middle && !ring && thumb {
        return quality == .major ? "VII" : "vii"
    }

    let count = [thumb, index, middle, ring, pinky].filter { $0 }.count
    guard count >= 1 && count <= 5 else { return nil }
    let roman = ["I", "II", "III", "IV", "V"][count - 1]
    return quality == .major ? roman : roman.lowercased()
}

/// Wrist offset past the middle/ring knuckle line, clamped to [-1, 1].
/// A dead-zone keeps small natural hand wobble from registering as tilt.
func getHandHorizontalTilt(_ landmarks: [Landmark]?, _ handedness: Handedness) -> Double {
    guard let landmarks, landmarks.count >= 18 else { return 0 }

    let wrist = landmarks[0]
    let middleMcp = landmarks[9]
    let ringMcp = landmarks[13]

    let minX = min(middleMcp.x, ringMcp.x)
    let maxX = max(middleMcp.x, ringMcp.x)
    let maxTravel = 0.12

    var tiltFactor: Double
    if wrist.x < minX {
        tiltFactor = (wrist.x - minX) / maxTravel
    } else if wrist.x > maxX {
        tiltFactor = (wrist.x - maxX) / maxTravel
    } else {
        tiltFactor = 0
    }

    tiltFactor = max(-1, min(1, tiltFactor))

    if handedness == .right {
        tiltFactor = -tiltFactor
    }

    return tiltFactor
}

func getVolumeFromHeight(_ landmarks: [Landmark]) -> Double {
    let wrist = landmarks[0]
    let top = 0.05
    let bottom = 0.95
    let clamped = max(top, min(bottom, wrist.y))
    let t = (clamped - top) / (bottom - top)
    return 1 - t
}

func getRightHandQualityIndex(_ landmarks: [Landmark]) -> Int {
    let index = isFingerExtended(landmarks, .index)
    let middle = isFingerExtended(landmarks, .middle)
    let ring = isFingerExtended(landmarks, .ring)
    let pinky = isFingerExtended(landmarks, .pinky)
    return [index, middle, ring, pinky].filter { $0 }.count
}
