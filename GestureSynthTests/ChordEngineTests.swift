import Testing
@testable import GestureSynth

struct DegreeFrequencyTests {
    @Test func tonicDegreeIsTheTonicItself() {
        #expect(getDegreeFreq(1, tonicFreq: 220) == 220)
    }

    @Test func fifthDegreeIsASeventTemperedFifthAbove() {
        // A3 (220Hz) up a perfect fifth is E4, ~329.63Hz in equal temperament.
        #expect(abs(getDegreeFreq(5, tonicFreq: 220) - 329.63) < 0.05)
    }

    @Test func seventhDegreeIsASemitoneBelowTheOctave() {
        // DEGREE_SEMITONES[7] is -1, a semitone below the tonic, not above the scale.
        #expect(abs(getDegreeFreq(7, tonicFreq: 220) - 207.65) < 0.05)
    }

    @Test func specificKeysDropAnOctaveBeforeApplyingTheDegree() {
        #expect(getDegreeFreq(1, tonicFreq: 369.99) == 369.99 / 2)
        #expect(getDegreeFreq(1, tonicFreq: 392.00) == 392.00 / 2)
        #expect(getDegreeFreq(1, tonicFreq: 415.30) == 415.30 / 2)
    }

    @Test func mostKeysAreNotDropped() {
        #expect(getDegreeFreq(1, tonicFreq: 220) == 220)
    }
}

struct ChordNameTests {
    @Test func majorNameIsTheBareScaleDegree() {
        #expect(getChordName("I", isMajorMode: true, keyName: "A") == "A")
    }

    @Test func minorNameAppendsM() {
        #expect(getChordName("VI", isMajorMode: false, keyName: "A") == "F#m")
    }

    @Test func lowercaseNumeralsStillResolve() {
        #expect(getChordName("vi", isMajorMode: false, keyName: "A") == "F#m")
    }

    @Test func nilAndPlaceholderInputsAreEmpty() {
        #expect(getChordName(nil, isMajorMode: true, keyName: "A") == "")
        #expect(getChordName("--", isMajorMode: true, keyName: "A") == "")
    }

    @Test func unknownNumeralIsEmpty() {
        #expect(getChordName("VIII", isMajorMode: true, keyName: "A") == "")
    }
}

struct ChordTonesTests {
    @Test func majorThirdMatchesEqualTemperament() {
        // A perfect major third above A3 (220Hz) is C#4, ~277.18Hz.
        let tones = getChordTones("I", isMajorMode: true, tonicFreq: 220)
        #expect(tones != nil)
        #expect(abs(tones!.third - 277.18) < 0.05)
    }

    @Test func minorThirdIsASemitoneFlatterThanMajor() {
        // A minor third above A3 is C4, ~261.63Hz.
        let tones = getChordTones("I", isMajorMode: false, tonicFreq: 220)
        #expect(abs(tones!.third - 261.63) < 0.05)
    }

    @Test func octavesAreExactlyDouble() {
        let tones = getChordTones("I", isMajorMode: true, tonicFreq: 220)!
        #expect(tones.octaveRoot == tones.root * 2)
        #expect(tones.octaveThird == tones.third * 2)
    }

    @Test func nilAndUnknownInputsProduceNoTones() {
        #expect(getChordTones(nil, isMajorMode: true, tonicFreq: 220) == nil)
        #expect(getChordTones("--", isMajorMode: true, tonicFreq: 220) == nil)
        #expect(getChordTones("VIII", isMajorMode: true, tonicFreq: 220) == nil)
    }
}

struct SolidNotesTests {
    // Distinct sentinel values, not real frequencies, so a wrong field
    // selection shows up immediately as the wrong number.
    private let tones = ChordTones(
        root: 1, third: 2, fifth: 3, octaveRoot: 4, octaveThird: 5,
        maj7Tone: 6, dom7Tone: 7, dim7Tone: 8, dim5Tone: 9
    )

    @Test func majorVoicings() {
        #expect(getSolidNotes(tones, rightHandCount: 1, isMajorMode: true) == [1, 3, 4, 5]) // root position
        #expect(getSolidNotes(tones, rightHandCount: 2, isMajorMode: true) == [2, 3, 4, 5]) // first inversion
        #expect(getSolidNotes(tones, rightHandCount: 3, isMajorMode: true) == [1, 2, 3, 6]) // major 7th
        #expect(getSolidNotes(tones, rightHandCount: 4, isMajorMode: true) == [1, 2, 3, 7]) // dominant 7th
    }

    @Test func minorVoicings() {
        #expect(getSolidNotes(tones, rightHandCount: 1, isMajorMode: false) == [1, 3, 4, 5])
        #expect(getSolidNotes(tones, rightHandCount: 2, isMajorMode: false) == [2, 3, 4, 5])
        #expect(getSolidNotes(tones, rightHandCount: 3, isMajorMode: false) == [1, 2, 3, 7]) // minor 7th
        #expect(getSolidNotes(tones, rightHandCount: 4, isMajorMode: false) == [1, 2, 9, 8]) // diminished 7th
    }

    @Test func outOfRangeCountsFallBackToRootPosition() {
        #expect(getSolidNotes(tones, rightHandCount: 0, isMajorMode: true) == [1, 3, 4, 5])
        #expect(getSolidNotes(tones, rightHandCount: 5, isMajorMode: true) == [1, 3, 4, 5])
    }

    @Test func noTonesProducesNoNotes() {
        #expect(getSolidNotes(nil, rightHandCount: 1, isMajorMode: true) == [])
    }
}
