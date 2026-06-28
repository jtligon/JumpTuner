// JumpPhysicsConfigTests.swift
// Tests for JumpPhysicsConfig: maps JumpParams + screen height to SpriteKit physics values.

import Testing
import CoreGraphics
@testable import JumpTuner

@Suite("JumpPhysicsConfig")
@MainActor
struct JumpPhysicsConfigTests {

    // Params with clean round numbers for easy manual verification.
    // ascentFrames = 12 → ascentTime = 0.2s
    // scaledHeight = 200 pts
    // g = 2*200/0.04 = 10000 pts/s²
    // v0 = 2*200/0.2  = 2000 pts/s
    private var cleanParams: JumpParams {
        var p = JumpParams.defaults
        p.ascentFrames   = 12    // 0.2s
        p.descentFrames  = 10    // 0.1667s
        p.fallMult       = 2.0
        p.apexGravFactor = 0.5
        p.apexFrames     = 4
        p.squatFrames    = 6
        p.landingFrames  = 3
        p.squatScale     = 0.8
        p.launchScale    = 1.5
        p.landScale      = 0.6
        p.features.asymGrav = true
        p.features.apexGrav = true
        return p
    }

    // MARK: Kinematics

    @Test func jumpImpulseMatchesKinematics() {
        let config = JumpPhysicsConfig(params: cleanParams, scaledHeight: 200)
        // v0 = 2 * h / ascentTime = 2 * 200 / 0.2 = 2000
        #expect(abs(config.jumpImpulse - 2000) < 1)
    }

    @Test func ascentGravityMatchesKinematics() {
        let config = JumpPhysicsConfig(params: cleanParams, scaledHeight: 200)
        // g = 2 * h / ascentTime² = 2 * 200 / 0.04 = 10000
        #expect(abs(config.ascentGravity - 10000) < 1)
    }

    @Test func ascentGravityEqualsImpulseDividedByAscentTime() {
        let config = JumpPhysicsConfig(params: cleanParams, scaledHeight: 200)
        let ascentTime = CGFloat(cleanParams.ascentFrames / 60.0)
        #expect(abs(config.ascentGravity - config.jumpImpulse / ascentTime) < 1)
    }

    // MARK: Descent gravity

    @Test func descentGravityHigherThanAscentWhenAsymGravOn() {
        var p = cleanParams
        p.features.asymGrav = true
        p.fallMult = 2.0
        let config = JumpPhysicsConfig(params: p, scaledHeight: 200)
        #expect(config.descentGravity > config.ascentGravity)
    }

    @Test func descentGravityEqualsAscentWhenAsymGravOff() {
        var p = cleanParams
        p.features.asymGrav = false
        let config = JumpPhysicsConfig(params: p, scaledHeight: 200)
        #expect(config.descentGravity == config.ascentGravity)
    }

    @Test func higherFallMultProducesHigherDescentGravity() {
        let scaledHeight: CGFloat = 200
        var slow = cleanParams; slow.fallMult = 1.0
        var fast = cleanParams; fast.fallMult = 3.0
        slow.features.asymGrav = true; fast.features.asymGrav = true
        let slowConfig = JumpPhysicsConfig(params: slow, scaledHeight: scaledHeight)
        let fastConfig = JumpPhysicsConfig(params: fast, scaledHeight: scaledHeight)
        #expect(fastConfig.descentGravity > slowConfig.descentGravity)
    }

    // MARK: Apex gravity

    @Test func apexGravityLessThanAscentWhenApexGravOn() {
        var p = cleanParams
        p.features.apexGrav = true
        p.apexGravFactor = 0.3
        let config = JumpPhysicsConfig(params: p, scaledHeight: 200)
        #expect(config.apexGravity < config.ascentGravity)
    }

    @Test func apexGravityEqualsAscentWhenApexGravOff() {
        var p = cleanParams
        p.features.apexGrav = false
        let config = JumpPhysicsConfig(params: p, scaledHeight: 200)
        #expect(config.apexGravity == config.ascentGravity)
    }

    @Test func apexGravFactorOneProducesFullGravity() {
        var p = cleanParams
        p.features.apexGrav = true
        p.apexGravFactor = 1.0
        let config = JumpPhysicsConfig(params: p, scaledHeight: 200)
        #expect(abs(config.apexGravity - config.ascentGravity) < 1)
    }

    // MARK: Durations

    @Test func squatDurationMatchesFrames() {
        let config = JumpPhysicsConfig(params: cleanParams, scaledHeight: 200)
        #expect(abs(config.squatDuration - 6.0 / 60.0) < 0.001)
    }

    @Test func apexDurationMatchesFrames() {
        let config = JumpPhysicsConfig(params: cleanParams, scaledHeight: 200)
        #expect(abs(config.apexDuration - 4.0 / 60.0) < 0.001)
    }

    @Test func landingDurationMatchesFrames() {
        let config = JumpPhysicsConfig(params: cleanParams, scaledHeight: 200)
        #expect(abs(config.landingDuration - 3.0 / 60.0) < 0.001)
    }

    // MARK: Squash & stretch

    @Test func squatScalesPreserveVolume() {
        let config = JumpPhysicsConfig(params: cleanParams, scaledHeight: 200)
        // scaleX * scaleY should ≈ 1 (volume preservation)
        #expect(abs(config.squatScaleX * config.squatScaleY - 1.0) < 0.01)
    }

    @Test func launchScalesPreserveVolume() {
        let config = JumpPhysicsConfig(params: cleanParams, scaledHeight: 200)
        #expect(abs(config.launchScaleX * config.launchScaleY - 1.0) < 0.01)
    }

    @Test func landScalesPreserveVolume() {
        let config = JumpPhysicsConfig(params: cleanParams, scaledHeight: 200)
        #expect(abs(config.landScaleX * config.landScaleY - 1.0) < 0.01)
    }

    // MARK: Scaling with height

    @Test func tallerJumpProducesHigherImpulse() {
        let low  = JumpPhysicsConfig(params: cleanParams, scaledHeight: 100)
        let high = JumpPhysicsConfig(params: cleanParams, scaledHeight: 400)
        #expect(high.jumpImpulse > low.jumpImpulse)
    }

    @Test func tallerJumpProducesHigherGravity() {
        let low  = JumpPhysicsConfig(params: cleanParams, scaledHeight: 100)
        let high = JumpPhysicsConfig(params: cleanParams, scaledHeight: 400)
        #expect(high.ascentGravity > low.ascentGravity)
    }
}
