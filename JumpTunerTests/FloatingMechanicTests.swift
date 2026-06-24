// FloatingMechanicTests.swift
// Tests for the floating mechanic: JumpFeatures.floating and JumpParams.floatFrames.

import Testing
@testable import JumpTuner

@Suite("Floating mechanic")
@MainActor
struct FloatingMechanicTests {

    // MARK: JumpFeatures.floating

    @Test func floatingDefaultsToFalse() {
        #expect(JumpFeatures().floating == false)
    }

    @Test func floatingCanBeEnabled() {
        var f = JumpFeatures()
        f.floating = true
        #expect(f.floating == true)
    }

    @Test func floatingIncludedInEquality() {
        var a = JumpFeatures()
        var b = JumpFeatures()
        a.floating = true
        b.floating = false
        #expect(a != b)
    }

    @Test func floatingRoundtrips() throws {
        var f = JumpFeatures()
        f.floating = true
        let data    = try JSONEncoder().encode(f)
        let decoded = try JSONDecoder().decode(JumpFeatures.self, from: data)
        #expect(decoded.floating == true)
    }

    // MARK: JumpParams.floatFrames

    @Test func floatFramesDefaultsToTen() {
        #expect(JumpParams.defaults.floatFrames == 10)
    }

    @Test func floatFramesIncludedInEquality() {
        var a = JumpParams.defaults
        var b = JumpParams.defaults
        a.floatFrames = 5
        b.floatFrames = 30
        #expect(a != b)
    }

    @Test func floatFramesRoundtrips() throws {
        var p = JumpParams.defaults
        p.floatFrames = 25
        p.features.floating = true
        let json    = try p.encoded()
        let decoded = try JumpParams.decoded(from: json)
        #expect(decoded.floatFrames == 25)
        #expect(decoded.features.floating == true)
    }

    @Test func floatFramesDefaultsPreservedInFullRoundtrip() throws {
        let original = JumpParams.defaults
        let json     = try original.encoded()
        let decoded  = try JumpParams.decoded(from: json)
        #expect(decoded.floatFrames == original.floatFrames)
        #expect(decoded.features.floating == original.features.floating)
    }

    // MARK: Randomized stays in range

    @Test func randomizedFloatFramesInRange() {
        let p = JumpParams.randomized()
        #expect(p.floatFrames >= 0 && p.floatFrames <= 30)
    }
}
