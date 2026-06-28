// JumpPhysicsConfig.swift
// Derives SpriteKit physics values from JumpParams + a scaled pixel height.

import CoreGraphics

/// Maps `JumpParams` to concrete SpriteKit physics values for a given screen height.
///
/// All gravity values are positive magnitudes; the scene applies them downward.
/// Keeping this as a pure value type makes it easy to unit-test the math
/// without spinning up a SpriteKit view.
struct JumpPhysicsConfig {

    // MARK: Gravity (pts/s², positive = downward)

    /// Gravity applied while the character is rising.
    /// Derived from desired peak height and ascent time via kinematics:
    /// `g = 2h / t²`
    let ascentGravity: CGFloat

    /// Gravity applied while the character is falling.
    /// Equal to `ascentGravity * fallMult` when `asymGrav` is enabled,
    /// otherwise equal to `ascentGravity`.
    let descentGravity: CGFloat

    /// Reduced gravity applied at the jump apex for a brief float effect.
    /// Equal to `ascentGravity * apexGravFactor` when `apexGrav` is enabled,
    /// otherwise equal to `ascentGravity`.
    let apexGravity: CGFloat

    // MARK: Jump impulse

    /// Initial upward velocity (pts/s) to apply on jump.
    /// Derived from `g = v0 / t` → `v0 = 2h / ascentTime`.
    let jumpImpulse: CGFloat

    // MARK: Phase durations (seconds)

    let squatDuration: Double
    let apexDuration: Double
    let landingDuration: Double

    // MARK: Squash & stretch scales

    let squatScaleY: CGFloat
    let squatScaleX: CGFloat
    let launchScaleY: CGFloat
    let launchScaleX: CGFloat
    let landScaleY: CGFloat
    let landScaleX: CGFloat

    // MARK: Init

    init(params: JumpParams, scaledHeight: CGFloat) {
        let h = Double(scaledHeight)
        let ascentTime = params.ascentFrames / 60.0

        // Kinematics: character decelerates uniformly to v=0 at apex.
        // h = 0.5 * g * t²  →  g = 2h/t²
        // v0 = g * t         →  v0 = 2h/t
        let g = 2.0 * h / (ascentTime * ascentTime)
        let v0 = 2.0 * h / ascentTime

        ascentGravity = CGFloat(g)
        jumpImpulse   = CGFloat(v0)

        descentGravity = params.features.asymGrav
            ? CGFloat(g * params.fallMult)
            : CGFloat(g)

        apexGravity = params.features.apexGrav
            ? CGFloat(g * params.apexGravFactor)
            : CGFloat(g)

        squatDuration   = params.squatFrames   / 60.0
        let floatFrames  = params.features.floating ? params.floatFrames : 0
        apexDuration    = (params.apexFrames + floatFrames) / 60.0
        landingDuration = params.landingFrames / 60.0

        squatScaleY  = CGFloat(params.squatScale)
        squatScaleX  = CGFloat(1.0 / params.squatScale)
        launchScaleY = CGFloat(params.launchScale)
        launchScaleX = CGFloat(1.0 / params.launchScale)
        landScaleY   = CGFloat(params.landScale)
        landScaleX   = CGFloat(1.0 / params.landScale)
    }
}
