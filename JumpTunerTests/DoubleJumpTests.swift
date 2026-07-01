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

    @Test func doubleJumpHeightFactorDefaultsToPointSix() {
        #expect(JumpParams.defaults.doubleJumpHeightFactor == 0.6)
    }

    @Test func doubleJumpHeightFactorIncludedInEquality() {
        var a = JumpParams.defaults
        var b = JumpParams.defaults
        a.doubleJumpHeightFactor = 0.3
        b.doubleJumpHeightFactor = 0.8
        #expect(a != b)
    }

    @Test func doubleJumpHeightFactorRoundtrips() throws {
        var p = JumpParams.defaults
        p.doubleJumpHeightFactor = 0.4
        p.features.doubleJump = true
        let json    = try p.encoded()
        let decoded = try JumpParams.decoded(from: json)
        #expect(decoded.doubleJumpHeightFactor == 0.4)
        #expect(decoded.features.doubleJump == true)
    }

    @Test func doubleJumpDefaultsPreservedInFullRoundtrip() throws {
        let original = JumpParams.defaults
        let json     = try original.encoded()
        let decoded  = try JumpParams.decoded(from: json)
        #expect(decoded.doubleJumpHeightFactor == original.doubleJumpHeightFactor)
        #expect(decoded.features.doubleJump == original.features.doubleJump)
    }

    // MARK: Randomized stays in range

    @Test func randomizedDoubleJumpHeightFactorInRange() {
        let p = JumpParams.randomized()
        #expect(p.doubleJumpHeightFactor >= 0.2 && p.doubleJumpHeightFactor <= 0.9)
    }
}
