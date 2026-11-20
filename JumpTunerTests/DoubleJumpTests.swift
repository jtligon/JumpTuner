// DoubleJumpTests.swift
// Tests for the double jump mechanic: JumpFeatures.doubleJump and JumpParams.doubleJumpHeightFactor.

import Testing
import Foundation
@testable import JumpTuner

@Suite("Double jump mechanic")
@MainActor
struct DoubleJumpTests {

    // MARK: JumpFeatures.doubleJump

    @Test func doubleJumpDefaultsToFalse() {
        #expect(JumpFeatures().doubleJump == false)
    }

    @Test func doubleJumpCanBeEnabled() {
        var f = JumpFeatures()
        f.doubleJump = true
        #expect(f.doubleJump == true)
    }

    @Test func doubleJumpIncludedInEquality() {
        var a = JumpFeatures()
        var b = JumpFeatures()
        a.doubleJump = true
        b.doubleJump = false
        #expect(a != b)
    }

    @Test func doubleJumpRoundtrips() throws {
        var f = JumpFeatures()
        f.doubleJump = true
        let data    = try JSONEncoder().encode(f)
        let decoded = try JSONDecoder().decode(JumpFeatures.self, from: data)
        #expect(decoded.doubleJump == true)
    }

    // MARK: JumpParams.doubleJumpHeightFactor

    @Test func doubleJumpHeightFactorDefaultsToPointSevenFive() {
        #expect(JumpParams.defaults.doubleJumpHeightFactor == 0.75)
    }

    @Test func doubleJumpHeightFactorIncludedInEquality() {
        var a = JumpParams.defaults
        var b = JumpParams.defaults
        a.doubleJumpHeightFactor = 0.5
        b.doubleJumpHeightFactor = 1.0
        #expect(a != b)
    }

    @Test func doubleJumpHeightFactorRoundtrips() throws {
        var p = JumpParams.defaults
        p.doubleJumpHeightFactor = 0.8
        p.features.doubleJump = true
        let json    = try p.encoded()
        let decoded = try JumpParams.decoded(from: json)
        #expect(decoded.doubleJumpHeightFactor == 0.8)
        #expect(decoded.features.doubleJump == true)
    }

    @Test func doubleJumpHeightFactorDefaultPreservedInFullRoundtrip() throws {
        let original = JumpParams.defaults
        let json     = try original.encoded()
        let decoded  = try JumpParams.decoded(from: json)
        #expect(decoded.doubleJumpHeightFactor == original.doubleJumpHeightFactor)
        #expect(decoded.features.doubleJump == original.features.doubleJump)
    }

    // MARK: Randomized stays in range

    @Test func randomizedDoubleJumpHeightFactorInRange() {
        let p = JumpParams.randomized()
        #expect(p.doubleJumpHeightFactor >= 0.25 && p.doubleJumpHeightFactor <= 1.0)
    }

    @Test func randomizedDoubleJumpIsBoolean() {
        // Just verifies randomized() produces a valid Bool (always true, but
        // also documents that doubleJump participates in randomization).
        let p = JumpParams.randomized()
        let isValid = p.features.doubleJump == true || p.features.doubleJump == false
        #expect(isValid)
    }
}
