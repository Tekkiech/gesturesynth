import Testing
@testable import GestureSynth

private let stateA = ChordState(chord: "I", isMajorMode: true, qualityIndex: 1, thumbDown: false)
private let stateB = ChordState(chord: "V", isMajorMode: true, qualityIndex: 1, thumbDown: false)

struct ChordStateStabilizerTests {
    @Test func aChordDoesNotStabilizeBeforeTheHoldTime() {
        let stabilizer = ChordStateStabilizer()
        #expect(stabilizer.stabilize(stateA, now: 0) == nil)
        #expect(stabilizer.stabilize(stateA, now: 50) == nil)
    }

    @Test func aChordStabilizesOnceHeldForTheFullHoldTime() {
        let stabilizer = ChordStateStabilizer()
        _ = stabilizer.stabilize(stateA, now: 0)
        _ = stabilizer.stabilize(stateA, now: 50)
        #expect(stabilizer.stabilize(stateA, now: 100) == stateA)
    }

    @Test func switchingChordsMidHoldRestartsTheClock() {
        let stabilizer = ChordStateStabilizer()
        _ = stabilizer.stabilize(stateA, now: 0)
        // Switches before A ever stabilizes -- the hold timer for B starts at 50, not 0.
        _ = stabilizer.stabilize(stateB, now: 50)
        #expect(stabilizer.stabilize(stateB, now: 100) == nil)
        #expect(stabilizer.stabilize(stateB, now: 150) == stateB)
    }

    @Test func aBriefTrackingDropoutIsBridged() {
        let stabilizer = ChordStateStabilizer()
        _ = stabilizer.stabilize(stateA, now: 0)
        #expect(stabilizer.stabilize(stateA, now: 100) == stateA) // now stable

        // A dropout under the 50ms null window keeps the last state playing.
        #expect(stabilizer.stabilize(nil, now: 110) == stateA)
        #expect(stabilizer.stabilize(nil, now: 140) == stateA)
    }

    @Test func aSustainedDropoutEventuallyGoesSilent() {
        let stabilizer = ChordStateStabilizer()
        _ = stabilizer.stabilize(stateA, now: 0)
        _ = stabilizer.stabilize(stateA, now: 100) // stable

        // Past the 50ms null window, the dropout starts counting as a real
        // "no chord" candidate, which itself needs to hold for 100ms.
        #expect(stabilizer.stabilize(nil, now: 160) == stateA) // candidate reset to nil, not yet held
        #expect(stabilizer.stabilize(nil, now: 260) == nil) // held nil for 100ms -> silent
    }

    @Test func reappearingBeforeGoingSilentRestoresTheChordWithoutARetrigger() {
        let stabilizer = ChordStateStabilizer()
        _ = stabilizer.stabilize(stateA, now: 0)
        _ = stabilizer.stabilize(stateA, now: 100) // stable

        _ = stabilizer.stabilize(nil, now: 160) // dropout registers, hold clock starts
        // The hand comes back before the nil candidate would have held for 100ms.
        #expect(stabilizer.stabilize(stateA, now: 200) == stateA)
    }
}
