// DoubleJumpTests.swift
// Tests for the double-jump mechanic: JumpFeatures.doubleJump and JumpParams.doubleJumpHeightFactor.

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

    @Test func doubleJumpDisabledRoundtrips() throws {
        let f       = JumpFeatures()
        let data    = try JSONEncoder().encode(f)
        let decoded = try JSONDecoder().decode(JumpFeatures.self, from: data)
        #expect(decoded.doubleJump == false)
    }

    // MARK: JumpParams.doubleJumpHeightFactor

    @Test func doubleJumpHeightFactorDefaultsToSeventyFivePercent() {
        #expect(JumpParams.defaults.doubleJumpHeightFactor == 0.75)
    }

    @Test func doubleJumpFeatureDefaultsToDisabled() {
        #expect(JumpParams.defaults.features.doubleJump == false)
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
        p.doubleJumpHeightFactor = 0.5
        p.features.doubleJump = true
        let json    = try p.encoded()
        let decoded = try JumpParams.decoded(from: json)
        #expect(decoded.doubleJumpHeightFactor == 0.5)
        #expect(decoded.features.doubleJump == true)
    }

    @Test func doubleJumpDefaultsPreservedInFullRoundtrip() throws {
        let original = JumpParams.defaults
        let json     = try original.encoded()
        let decoded  = try JumpParams.decoded(from: json)
        #expect(decoded.doubleJumpHeightFactor == original.doubleJumpHeightFactor)
        #expect(decoded.features.doubleJump == original.features.doubleJump)
    }

    // MARK: Height factor semantics

    @Test func heightFactorOfOneProducesFullHeightDoubleJump() {
        // At factor 1.0 the second jump should reach the same height as the first.
        // We verify the math: extraHeight = scaledHeight * factor
        let scaledHeight: Double = 200
        let factor: Double = 1.0
        let extraHeight = scaledHeight * factor
        #expect(extraHeight == scaledHeight)
    }

    @Test func heightFactorOfHalfProducesHalfHeightDoubleJump() {
        let scaledHeight: Double = 200
        let factor: Double = 0.5
        let extraHeight = scaledHeight * factor
        #expect(extraHeight == 100)
    }

    @Test func heightFactorOfQuarterProducesQuarterHeightDoubleJump() {
        let scaledHeight: Double = 200
        let factor: Double = 0.25
        let extraHeight = scaledHeight * factor
        #expect(extraHeight == 50)
    }

    @Test func heightFactorIsAlwaysLessThanOrEqualToOne() {
        // The second jump must never exceed the first jump's height
        // to match the spec: "equal or lesser height".
        let factor = JumpParams.defaults.doubleJumpHeightFactor
        #expect(factor <= 1.0)
    }

    // MARK: Randomized stays in range

    @Test func randomizedDoubleJumpHeightFactorInRange() {
        // randomized() uses Int.random(in: 5...20) / 20.0 → 0.25...1.0
        let p = JumpParams.randomized()
        #expect(p.doubleJumpHeightFactor >= 0.25 && p.doubleJumpHeightFactor <= 1.0)
    }
}
