// FloatingParamTextTests.swift
// Tests for FloatingParamEvent and JumpPhase.paramEvents(for:)

import Testing
import CoreGraphics
import Foundation
@testable import JumpTuner

@Suite("FloatingParamEvent")
@MainActor
struct FloatingParamEventTests {

    @Test func equalityOnMatchingValues() {
        let a = FloatingParamEvent(name: "ascent", value: "11f")
        let b = FloatingParamEvent(name: "ascent", value: "11f")
        #expect(a == b)
    }

    @Test func inequalityOnDifferentName() {
        let a = FloatingParamEvent(name: "ascent", value: "11f")
        let b = FloatingParamEvent(name: "descent", value: "11f")
        #expect(a != b)
    }

    @Test func inequalityOnDifferentValue() {
        let a = FloatingParamEvent(name: "ascent", value: "11f")
        let b = FloatingParamEvent(name: "ascent", value: "8f")
        #expect(a != b)
    }

    @Test func formattedCombinesNameAndValue() {
        let event = FloatingParamEvent(name: "squat", value: "3f")
        #expect(event.formatted == "squat: 3f")
    }
}

@Suite("JumpPhase.paramEvents")
@MainActor
struct JumpPhaseParamEventsTests {

    private let p = JumpParams.defaults

    @Test func idleReturnsEmpty() {
        #expect(JumpPhase.idle.paramEvents(for: p).isEmpty)
    }

    @Test func squatReturnsSquatFrames() {
        let events = JumpPhase.squat.paramEvents(for: p)
        #expect(events.count == 1)
        #expect(events[0].name == "squat")
        #expect(events[0].value == "\(Int(p.squatFrames))f")
    }

    @Test func ascendingReturnsAscentFrames() {
        let events = JumpPhase.ascending.paramEvents(for: p)
        #expect(events.count == 1)
        #expect(events[0].name == "ascent")
        #expect(events[0].value == "\(Int(p.ascentFrames))f")
    }

    @Test func apexWithoutFloatingReturnsOnlyApexFrames() {
        var params = JumpParams.defaults
        params.features.floating = false
        let events = JumpPhase.apex.paramEvents(for: params)
        #expect(events.count == 1)
        #expect(events[0].name == "apex")
    }

    @Test func apexWithFloatingReturnsBothApexAndFloat() {
        var params = JumpParams.defaults
        params.features.floating = true
        params.floatFrames = 15
        let events = JumpPhase.apex.paramEvents(for: params)
        #expect(events.count == 2)
        #expect(events[0].name == "apex")
        #expect(events[1].name == "float")
        #expect(events[1].value == "15f")
    }

    @Test func descendingReturnsDescentFrames() {
        let events = JumpPhase.descending.paramEvents(for: p)
        #expect(events.count == 1)
        #expect(events[0].name == "descent")
        #expect(events[0].value == "\(Int(p.descentFrames))f")
    }

    @Test func landingReturnsLandingFrames() {
        let events = JumpPhase.landing.paramEvents(for: p)
        #expect(events.count == 1)
        #expect(events[0].name == "land")
        #expect(events[0].value == "\(Int(p.landingFrames))f")
    }

    @Test func valuesReflectCustomParams() {
        var params = JumpParams.defaults
        params.squatFrames = 7
        params.ascentFrames = 20
        params.apexFrames = 4
        params.descentFrames = 12
        params.landingFrames = 5
        #expect(JumpPhase.squat.paramEvents(for: params)[0].value == "7f")
        #expect(JumpPhase.ascending.paramEvents(for: params)[0].value == "20f")
        #expect(JumpPhase.apex.paramEvents(for: params)[0].value == "4f")
        #expect(JumpPhase.descending.paramEvents(for: params)[0].value == "12f")
        #expect(JumpPhase.landing.paramEvents(for: params)[0].value == "5f")
    }
}

@Suite("FloatingTextLayout")
@MainActor
struct FloatingTextLayoutTests {

    @Test func emptyLineUsesTheScreenEdge() {
        #expect(FloatingTextLayout.rightEdge(forLabelAt: 60, screenRight: 388, existing: []) == 388)
    }

    @Test func labelOnTheSameLineMovesToTheLeft() {
        let existing = [CGRect(x: 320, y: 54, width: 68, height: 12)]
        let edge = FloatingTextLayout.rightEdge(forLabelAt: 60, screenRight: 388, existing: existing)
        #expect(edge == 320 - FloatingTextLayout.columnGap)
    }

    @Test func thirdLabelClearsEveryLabelOnTheLine() {
        let existing = [CGRect(x: 320, y: 54, width: 68, height: 12),
                        CGRect(x: 240, y: 54, width: 68, height: 12)]
        let edge = FloatingTextLayout.rightEdge(forLabelAt: 60, screenRight: 388, existing: existing)
        #expect(edge == 240 - FloatingTextLayout.columnGap)
    }

    @Test func labelsOnOtherLinesAreIgnored() {
        let existing = [CGRect(x: 320, y: 200, width: 68, height: 12)]
        #expect(FloatingTextLayout.rightEdge(forLabelAt: 60, screenRight: 388, existing: existing) == 388)
    }

    @Test func ceilingIsLevelWithTheSpriteAtItsPeak() {
        #expect(FloatingTextLayout.ceiling(peakY: 300, spriteHeight: 48, screenHeight: 874) == 324)
    }

    @Test func labelsFromBelowStopAtTheTopOfTheJump() {
        #expect(FloatingTextLayout.riseTarget(fromY: 62, ceiling: 324, screenHeight: 874) == 324)
    }

    @Test func labelsStartingAtThePeakKeepDrifting() {
        #expect(FloatingTextLayout.riseTarget(fromY: 324, ceiling: 324, screenHeight: 874)
                == 324 + FloatingTextLayout.peakDrift)
    }

    @Test func driftStaysOnScreen() {
        #expect(FloatingTextLayout.riseTarget(fromY: 804, ceiling: 804, screenHeight: 874)
                == 874 - FloatingTextLayout.driftTopMargin)
    }

    @Test func ceilingStaysOnScreen() {
        #expect(FloatingTextLayout.ceiling(peakY: 900, spriteHeight: 48, screenHeight: 874)
                == 874 - FloatingTextLayout.topMargin)
    }
}
