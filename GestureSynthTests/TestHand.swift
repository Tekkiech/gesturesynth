@testable import GestureSynth

/// Builds a 21-point landmark array from a neutral baseline: fingers curled
/// (not extended), thumb tucked for a right hand, quality reading as major.
/// Coordinates are schematic, not anatomically real -- only the specific
/// relative comparisons each function under test actually reads need to hold.
/// Pass overrides for the joints a given test cares about.
func testHand(_ overrides: [Int: Landmark] = [:]) -> [Landmark] {
    var lm = [Landmark](repeating: Landmark(x: 0.5, y: 0.5), count: 21)

    // Sitting exactly at middleMcp/ringMcp's shared boundary (0.51): inside
    // the tilt dead zone, and not past it for chord quality either, so both
    // read as their neutral default (no tilt, major).
    lm[0] = Landmark(x: 0.51, y: 0.80) // wrist

    // Thumb tucked: tip.x (0.44) < IP.x (0.45) -> not extended for a right hand.
    lm[1] = Landmark(x: 0.47, y: 0.75) // CMC
    lm[2] = Landmark(x: 0.46, y: 0.70) // MP
    lm[3] = Landmark(x: 0.45, y: 0.65) // IP
    lm[4] = Landmark(x: 0.44, y: 0.62) // tip

    // middleMcp.x (0.51) is not > wrist.x (0.51), so quality reads major by default.
    let fingers: [(mcp: Int, pip: Int, dip: Int, tip: Int, x: Double)] = [
        (5, 6, 7, 8, 0.56),    // index
        (9, 10, 11, 12, 0.51), // middle
        (13, 14, 15, 16, 0.46), // ring
        (17, 18, 19, 20, 0.41), // pinky
    ]
    for f in fingers {
        lm[f.mcp] = Landmark(x: f.x, y: 0.70)
        lm[f.pip] = Landmark(x: f.x, y: 0.60)
        lm[f.dip] = Landmark(x: f.x, y: 0.55)
        lm[f.tip] = Landmark(x: f.x, y: 0.65) // curled: tip.y > pip.y -> not extended
    }

    for (index, landmark) in overrides {
        lm[index] = landmark
    }
    return lm
}

/// An override for `finger`'s tip that reads as extended (tip above its pip),
/// keeping `testHand`'s baseline x for that finger so the rest of the hand
/// still reads naturally.
func extending(_ finger: Finger) -> [Int: Landmark] {
    let x: Double
    switch finger {
    case .index: x = 0.56
    case .middle: x = 0.51
    case .ring: x = 0.46
    case .pinky: x = 0.41
    }
    return [finger.tipIndex: Landmark(x: x, y: 0.45)]
}

/// Combines several override dictionaries (e.g. multiple `extending(_:)`
/// calls plus a manual thumb/wrist override) into one.
func merge(_ overrides: [Int: Landmark]...) -> [Int: Landmark] {
    overrides.reduce(into: [:]) { result, dict in
        result.merge(dict) { _, new in new }
    }
}
