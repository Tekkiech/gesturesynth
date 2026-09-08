import Foundation

let degreeSemitones: [Int: Int] = [1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: -1]

let majorScales: [String: [String]] = [
    "A": ["A", "B", "C#", "D", "E", "F#", "G#"],
    "Bb": ["Bb", "C", "D", "Eb", "F", "G", "A"],
    "B": ["B", "C#", "D#", "E", "F#", "G#", "A#"],
    "C": ["C", "D", "E", "F", "G", "A", "B"],
    "Db": ["Db", "Eb", "F", "Gb", "Ab", "Bb", "C"],
    "D": ["D", "E", "F#", "G", "A", "B", "C#"],
    "Eb": ["Eb", "F", "G", "Ab", "Bb", "C", "D"],
    "E": ["E", "F#", "G#", "A", "B", "C#", "D#"],
    "F": ["F", "G", "A", "Bb", "C", "D", "E"],
    "Gb": ["Gb", "Ab", "Bb", "Cb", "Db", "Eb", "F"],
    "G": ["G", "A", "B", "C", "D", "E", "F#"],
    "Ab": ["Ab", "Bb", "C", "Db", "Eb", "F", "G"],
]

let numeralToDegree: [String: Int] = [
    "I": 1, "II": 2, "III": 3, "IV": 4, "V": 5, "VI": 6, "VII": 7,
]

struct ChordTones {
    var root: Double
    var third: Double
    var fifth: Double
    var octaveRoot: Double
    var octaveThird: Double
    var maj7Tone: Double
    var dom7Tone: Double
    var dim7Tone: Double
    var dim5Tone: Double
}

/// Frequency for a major-scale degree relative to `tonicFreq`. A few keys are
/// dropped an octave to keep the whole range comfortable, matching the original.
func getDegreeFreq(_ degree: Int, tonicFreq: Double) -> Double {
    let semitones = degreeSemitones[degree] ?? 0
    var tonic = tonicFreq
    if tonic == 369.99 || tonic == 392.00 || tonic == 415.30 {
        tonic /= 2
    }
    return tonic * pow(2, Double(semitones) / 12)
}

func getChordName(_ roman: String?, isMajorMode: Bool, keyName: String) -> String {
    guard let roman, roman != "--" else { return "" }
    guard let degree = numeralToDegree[roman.uppercased()] else { return "" }
    guard let scale = majorScales[keyName] else { return "" }
    let root = scale[degree - 1]
    return isMajorMode ? root : root + "m"
}

func getChordTones(_ numeralStr: String?, isMajorMode: Bool, tonicFreq: Double) -> ChordTones? {
    guard let numeralStr, numeralStr != "--" else { return nil }
    guard let degree = numeralToDegree[numeralStr.uppercased()] else { return nil }

    let root = getDegreeFreq(degree, tonicFreq: tonicFreq)

    let thirdSemitones = isMajorMode ? 4 : 3
    let fifthSemitones = 7
    let maj7Semitones = 11
    let dom7Semitones = 10
    let dim7Semitones = 9

    let third = root * pow(2, Double(thirdSemitones) / 12)
    let fifth = root * pow(2, Double(fifthSemitones) / 12)
    let octaveRoot = root * 2
    let octaveThird = third * 2
    let maj7Tone = root * pow(2, Double(maj7Semitones) / 12)
    let dom7Tone = root * pow(2, Double(dom7Semitones) / 12)
    let dim7Tone = root * pow(2, Double(dim7Semitones) / 12)
    let dim5Tone = root * pow(2, 6.0 / 12)

    return ChordTones(
        root: root, third: third, fifth: fifth,
        octaveRoot: octaveRoot, octaveThird: octaveThird,
        maj7Tone: maj7Tone, dom7Tone: dom7Tone, dim7Tone: dim7Tone, dim5Tone: dim5Tone
    )
}

/// Maps the right-hand finger count (1-4) to a 4-note voicing, routed through
/// separate major/minor tables exactly like the original `getSolidNotes`.
func getSolidNotes(_ tones: ChordTones?, rightHandCount: Int, isMajorMode: Bool) -> [Double] {
    guard let tones else { return [] }

    if isMajorMode {
        switch rightHandCount {
        case 1: return [tones.root, tones.fifth, tones.octaveRoot, tones.octaveThird]
        case 2: return [tones.third, tones.fifth, tones.octaveRoot, tones.octaveThird]
        case 3: return [tones.root, tones.third, tones.fifth, tones.maj7Tone]
        case 4: return [tones.root, tones.third, tones.fifth, tones.dom7Tone]
        default: return [tones.root, tones.fifth, tones.octaveRoot, tones.octaveThird]
        }
    } else {
        switch rightHandCount {
        case 1: return [tones.root, tones.fifth, tones.octaveRoot, tones.octaveThird]
        case 2: return [tones.third, tones.fifth, tones.octaveRoot, tones.octaveThird]
        case 3: return [tones.root, tones.third, tones.fifth, tones.dom7Tone]
        case 4: return [tones.root, tones.third, tones.dim5Tone, tones.dim7Tone]
        default: return [tones.root, tones.fifth, tones.octaveRoot, tones.octaveThird]
        }
    }
}
