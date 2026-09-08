import Testing
@testable import GestureSynth

struct FingerExtensionTests {
    @Test func curledFingerIsNotExtended() {
        #expect(isFingerExtended(testHand(), .index) == false)
    }

    @Test func raisedFingerIsExtended() {
        let hand = testHand(extending(.index))
        #expect(isFingerExtended(hand, .index) == true)
    }

    @Test func eachFingerReadsIndependently() {
        let hand = testHand(merge(extending(.index), extending(.pinky)))
        #expect(isFingerExtended(hand, .index) == true)
        #expect(isFingerExtended(hand, .middle) == false)
        #expect(isFingerExtended(hand, .ring) == false)
        #expect(isFingerExtended(hand, .pinky) == true)
    }
}

struct ThumbExtensionTests {
    @Test func rightHandThumbOutIsExtended() {
        let hand = testHand([4: Landmark(x: 0.50, y: 0.62)]) // tip.x > IP.x (0.45)
        #expect(isThumbExtended(hand, .right) == true)
    }

    @Test func rightHandThumbTuckedIsNotExtended() {
        #expect(isThumbExtended(testHand(), .right) == false) // baseline is tucked for a right hand
    }

    @Test func leftHandUsesTheOppositeDirection() {
        let tuckedForLeft = testHand([4: Landmark(x: 0.50, y: 0.62)]) // same shape read as a left hand
        #expect(isThumbExtended(tuckedForLeft, .left) == false)

        let extendedForLeft = testHand() // baseline (tip.x < IP.x) reads as extended for a left hand
        #expect(isThumbExtended(extendedForLeft, .left) == true)
    }
}

struct ChordQualityTests {
    @Test func defaultBaselineReadsMajor() {
        #expect(getChordQuality(testHand()) == .major)
    }

    @Test func middleKnucklePastWristReadsMinor() {
        let hand = testHand([0: Landmark(x: 0.45, y: 0.80)]) // wrist.x < middleMcp.x (0.51)
        #expect(getChordQuality(hand) == .minor)
    }
}

struct ClassifyChordTests {
    private func minorHand(_ overrides: [Int: Landmark]) -> [Landmark] {
        testHand(merge(overrides, [0: Landmark(x: 0.45, y: 0.80)]))
    }

    @Test func oneFingerIsDegreeOne() {
        let hand = testHand(extending(.index))
        #expect(classifyChord(hand, .right) == "I")
    }

    @Test func twoFingersIsDegreeTwo() {
        let hand = testHand(merge(extending(.index), extending(.middle)))
        #expect(classifyChord(hand, .right) == "II")
    }

    @Test func fiveFingersIsDegreeFive() {
        let hand = testHand(merge(
            extending(.index), extending(.middle), extending(.ring), extending(.pinky),
            [4: Landmark(x: 0.50, y: 0.62)] // thumb out
        ))
        #expect(classifyChord(hand, .right) == "V")
    }

    @Test func indexAndPinkyWithoutThumbIsDegreeSix() {
        let hand = testHand(merge(extending(.index), extending(.pinky)))
        #expect(classifyChord(hand, .right) == "VI")
    }

    @Test func indexAndPinkyWithThumbIsDegreeSeven() {
        let hand = testHand(merge(
            extending(.index), extending(.pinky),
            [4: Landmark(x: 0.50, y: 0.62)] // thumb out
        ))
        #expect(classifyChord(hand, .right) == "VII")
    }

    @Test func minorQualityLowercasesTheNumeral() {
        let hand = minorHand(extending(.index))
        #expect(classifyChord(hand, .right) == "i")
    }

    @Test func noFingersExtendedHasNoChord() {
        #expect(classifyChord(testHand(), .right) == nil)
    }
}

struct HandTiltTests {
    @Test func wristBetweenKnucklesIsDeadZone() {
        // wrist.x (0.51) sits at the boundary of [ringMcp.x (0.46), middleMcp.x (0.51)].
        #expect(getHandHorizontalTilt(testHand(), .left) == 0)
    }

    @Test func wristPastTheOutsideKnuckleTiltsPositive() {
        // ringMcp.x is 0.46; travel past it by half of maxTravel (0.12).
        let hand = testHand([0: Landmark(x: 0.52, y: 0.80)])
        let tilt = getHandHorizontalTilt(hand, .left)
        #expect(tilt > 0 && tilt < 1)
    }

    @Test func wristPastTheInsideKnuckleTiltsNegative() {
        // middleMcp.x is 0.51; travel past it toward smaller x.
        let hand = testHand([0: Landmark(x: 0.45, y: 0.80)])
        let tilt = getHandHorizontalTilt(hand, .left)
        #expect(tilt < 0 && tilt > -1)
    }

    @Test func tiltClampsAtOne() {
        let hand = testHand([0: Landmark(x: 0.0, y: 0.80)])
        #expect(getHandHorizontalTilt(hand, .left) == -1)
    }

    @Test func rightHandednessFlipsTheSign() {
        let hand = testHand([0: Landmark(x: 0.45, y: 0.80)])
        let leftTilt = getHandHorizontalTilt(hand, .left)
        let rightTilt = getHandHorizontalTilt(hand, .right)
        #expect(rightTilt == -leftTilt)
    }

    @Test func tooFewLandmarksReadsAsNoTilt() {
        #expect(getHandHorizontalTilt(Array(testHand().prefix(10)), .left) == 0)
    }

    @Test func nilLandmarksReadAsNoTilt() {
        #expect(getHandHorizontalTilt(nil, .left) == 0)
    }
}

struct VolumeAndQualityIndexTests {
    @Test func highHandIsFullVolume() {
        let hand = testHand([0: Landmark(x: 0.5, y: 0.05)])
        #expect(getVolumeFromHeight(hand) == 1)
    }

    @Test func lowHandIsSilent() {
        let hand = testHand([0: Landmark(x: 0.5, y: 0.95)])
        #expect(getVolumeFromHeight(hand) == 0)
    }

    @Test func midHeightIsHalfVolume() {
        let hand = testHand([0: Landmark(x: 0.5, y: 0.5)])
        #expect(abs(getVolumeFromHeight(hand) - 0.5) < 0.001)
    }

    @Test func heightClampsBeyondTheWorkingRange() {
        let aboveTop = testHand([0: Landmark(x: 0.5, y: 0.0)])
        let belowBottom = testHand([0: Landmark(x: 0.5, y: 1.0)])
        #expect(getVolumeFromHeight(aboveTop) == 1)
        #expect(getVolumeFromHeight(belowBottom) == 0)
    }

    @Test func qualityIndexCountsExtendedFingers() {
        #expect(getRightHandQualityIndex(testHand()) == 0)
        #expect(getRightHandQualityIndex(testHand(extending(.index))) == 1)
        let hand = testHand(merge(extending(.index), extending(.middle), extending(.ring), extending(.pinky)))
        #expect(getRightHandQualityIndex(hand) == 4)
    }
}
