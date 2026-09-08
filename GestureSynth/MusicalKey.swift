import Foundation

/// One entry per key the original's `keySelect` offered. `keyName` matches a
/// key in `majorScales` (ChordEngine.swift) exactly; `displayName` matches the
/// original's dropdown label, which shows both enharmonic spellings for the
/// black keys (e.g. "A#/Bb") even though only one spelling is used internally.
struct MusicalKey: Identifiable, Hashable {
    var id: String { keyName }
    let displayName: String
    let keyName: String
    let tonicFreq: Double
}

let musicalKeys: [MusicalKey] = [
    MusicalKey(displayName: "A", keyName: "A", tonicFreq: 220.00),
    MusicalKey(displayName: "A#/Bb", keyName: "Bb", tonicFreq: 233.08),
    MusicalKey(displayName: "B", keyName: "B", tonicFreq: 246.94),
    MusicalKey(displayName: "C", keyName: "C", tonicFreq: 261.63),
    MusicalKey(displayName: "C#/Db", keyName: "Db", tonicFreq: 277.18),
    MusicalKey(displayName: "D", keyName: "D", tonicFreq: 293.66),
    MusicalKey(displayName: "D#/Eb", keyName: "Eb", tonicFreq: 311.13),
    MusicalKey(displayName: "E", keyName: "E", tonicFreq: 329.63),
    MusicalKey(displayName: "F", keyName: "F", tonicFreq: 349.23),
    MusicalKey(displayName: "F#/Gb", keyName: "Gb", tonicFreq: 369.99),
    MusicalKey(displayName: "G", keyName: "G", tonicFreq: 392.00),
    MusicalKey(displayName: "G#/Ab", keyName: "Ab", tonicFreq: 415.30),
]

/// Matches the original's `selected` default (keySelect's first option).
let defaultMusicalKey = musicalKeys[0]
