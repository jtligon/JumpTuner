// RunCycle.swift
// Shared run animation: a fixed series of poses, stepped through like sprite
// frames, played on a side-on figure that each character builds for itself.

import SpriteKit

enum RunCycle {
    struct LimbPose {
        /// Rotation at the hip or shoulder, in degrees. Positive swings forward.
        let root: CGFloat
        /// Rotation at the knee or elbow, in degrees, relative to the root.
        let joint: CGFloat
    }

    static let frameDuration: TimeInterval = 1.0 / 20.0
    static let frameCount = 8

    /// Frame 0 is this leg landing out in front.
    static let legs: [LimbPose] = [
        LimbPose(root:  30, joint:  -10),  // contact
        LimbPose(root:  15, joint:  -55),  // absorb
        LimbPose(root:  -5, joint:  -30),  // mid-stance
        LimbPose(root: -30, joint:   -5),  // push off
        LimbPose(root: -42, joint:  -55),  // trail
        LimbPose(root: -15, joint: -105),  // heel up
        LimbPose(root:  25, joint:  -95),  // knee drive
        LimbPose(root:  45, joint:  -45),  // reach
    ]

    static let arms: [LimbPose] = [
        LimbPose(root:  60, joint: 50),
        LimbPose(root:  35, joint: 55),
        LimbPose(root:  -5, joint: 60),
        LimbPose(root: -45, joint: 45),
        LimbPose(root: -70, joint: 30),
        LimbPose(root: -45, joint: 40),
        LimbPose(root:  10, joint: 55),
        LimbPose(root:  45, joint: 50),
    ]

    /// A held whole-body pose for one phase of a jump taken mid-run.
    struct JumpPose {
        let nearLeg: LimbPose
        let farLeg: LimbPose
        let nearArm: LimbPose
        let farArm: LimbPose
        /// Grounded poses drop the body so the lowest foot stays on the ground.
        let isGrounded: Bool
    }

    /// The pose for a running jump phase, or `nil` when the stride should resume.
    static func jumpPose(for phase: JumpPhase) -> JumpPose? {
        switch phase {
        case .squat:
            return JumpPose(nearLeg: LimbPose(root: 55, joint: -100), farLeg: LimbPose(root: 15, joint: -95),
                            nearArm: LimbPose(root: -55, joint: 30), farArm: LimbPose(root: -40, joint: 35),
                            isGrounded: true)
        case .ascending:  // leading knee driven up, back leg trailing
            return JumpPose(nearLeg: LimbPose(root: 70, joint: -80), farLeg: LimbPose(root: -45, joint: -15),
                            nearArm: LimbPose(root: -50, joint: 35), farArm: LimbPose(root: 95, joint: 35),
                            isGrounded: false)
        case .apex:       // knees tucked
            return JumpPose(nearLeg: LimbPose(root: 60, joint: -85), farLeg: LimbPose(root: 10, joint: -70),
                            nearArm: LimbPose(root: -20, joint: 60), farArm: LimbPose(root: 70, joint: 50),
                            isGrounded: false)
        case .descending: // legs reaching for the ground, arms up for balance
            return JumpPose(nearLeg: LimbPose(root: 40, joint: -20), farLeg: LimbPose(root: -20, joint: -60),
                            nearArm: LimbPose(root: 120, joint: 20), farArm: LimbPose(root: 90, joint: 20),
                            isGrounded: false)
        case .landing:
            return JumpPose(nearLeg: LimbPose(root: 50, joint: -95), farLeg: LimbPose(root: 10, joint: -80),
                            nearArm: LimbPose(root: 30, joint: 45), farArm: LimbPose(root: 15, joint: 50),
                            isGrounded: true)
        case .idle:
            return nil
        }
    }

    // The poses above are tuned for this leg length; hip height and bounce
    // scale with it so feet stay on the ground for any character size.
    private static let referenceLegSegment: CGFloat = 7
    private static let referenceHipHeight: CGFloat = 12.7
    /// Dips on landing, lifts while both feet are off the ground.
    private static let referenceBob: [CGFloat] = [0, -0.6, 0, 2, 0, -0.6, 0, 2]

    static func hipHeight(legSegment: CGFloat) -> CGFloat {
        referenceHipHeight * legSegment / referenceLegSegment
    }

    static func bob(frame: Int, legSegment: CGFloat) -> CGFloat {
        referenceBob[frame] * legSegment / referenceLegSegment
    }

    /// Height of the sole above the ground for a leg pose, before bounce.
    static func footHeight(_ pose: LimbPose, legSegment: CGFloat) -> CGFloat {
        let root = pose.root * .pi / 180
        let knee = (pose.root + pose.joint) * .pi / 180
        return hipHeight(legSegment: legSegment) - legSegment * cos(root) - legSegment * cos(knee)
    }
}

/// A two-capsule limb hanging from its hip or shoulder. `lower` is a child of `upper`.
struct RunLimb {
    let upper: SKNode
    let lower: SKNode

    init(length: CGFloat, width: CGFloat, fill: UIColor, stroke: UIColor, lineWidth: CGFloat = 1) {
        let rect = CGRect(x: -width / 2, y: -(length + 0.5), width: width, height: length + 0.5)

        func capsule() -> SKShapeNode {
            let node = SKShapeNode(path: UIBezierPath(roundedRect: rect, cornerRadius: width / 2).cgPath)
            node.fillColor = fill
            node.strokeColor = stroke
            node.lineWidth = lineWidth
            return node
        }

        upper = SKNode()
        upper.addChild(capsule())
        lower = SKNode()
        lower.position = CGPoint(x: 0, y: -length)
        lower.addChild(capsule())
        upper.addChild(lower)
    }

    /// Snaps to a pose, cancelling any blend in progress.
    func apply(_ pose: RunCycle.LimbPose) {
        upper.removeAction(forKey: Self.blendKey)
        lower.removeAction(forKey: Self.blendKey)
        upper.zRotation = pose.root * .pi / 180
        lower.zRotation = pose.joint * .pi / 180
    }

    /// Blends to a pose over a few frames.
    func blend(to pose: RunCycle.LimbPose, duration: TimeInterval) {
        upper.run(.rotate(toAngle: pose.root * .pi / 180, duration: duration, shortestUnitArc: true),
                  withKey: Self.blendKey)
        lower.run(.rotate(toAngle: pose.joint * .pi / 180, duration: duration, shortestUnitArc: true),
                  withKey: Self.blendKey)
    }

    private static let blendKey = "poseBlend"
}

/// The side-on figure a character shows while running.
///
/// Draw order is fixed: far leg, near leg, then `content` (far arm first,
/// near arm last). Add torso and head to `content` between the two arm calls,
/// using the same coordinates as the character's standing figure.
final class RunRig: SKNode {

    let content = SKNode()
    /// Called with each new frame, for extras such as ears or a hat.
    var onFrame: ((Int) -> Void)?
    /// Called when a running jump changes phase, for extras such as ears or a hat.
    var onJumpPhase: ((JumpPhase) -> Void)?

    private(set) var isRunning = false
    private var isInJumpPose = false

    private let legSegment: CGFloat
    private let legLayer = SKNode()
    private var nearLeg: RunLimb!
    private var farLeg: RunLimb!
    private var nearArm: RunLimb!
    private var farArm: RunLimb!
    private var cycleFrame = 0

    /// - Parameters:
    ///   - legSegment: Length of the thigh, and of the shin.
    ///   - standHipY: Height of the hips in the standing figure's coordinates.
    ///   - leanDegrees: How far the upper body tips into the run.
    init(legSegment: CGFloat, standHipY: CGFloat, leanDegrees: CGFloat) {
        self.legSegment = legSegment
        super.init()
        isHidden = true
        addChild(legLayer)

        let upperBody = SKNode()
        upperBody.position = CGPoint(x: 0, y: RunCycle.hipHeight(legSegment: legSegment))
        upperBody.zRotation = -leanDegrees * .pi / 180
        addChild(upperBody)
        content.position = CGPoint(x: 0, y: -standHipY)
        upperBody.addChild(content)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func addLegs(far: RunLimb, near: RunLimb, farX: CGFloat, nearX: CGFloat) {
        let hipY = RunCycle.hipHeight(legSegment: legSegment)
        far.upper.position = CGPoint(x: farX, y: hipY)
        near.upper.position = CGPoint(x: nearX, y: hipY)
        legLayer.addChild(far.upper)
        legLayer.addChild(near.upper)
        farLeg = far
        nearLeg = near
    }

    func addFarArm(_ arm: RunLimb, at shoulder: CGPoint) {
        arm.upper.position = shoulder
        content.addChild(arm.upper)
        farArm = arm
    }

    func addNearArm(_ arm: RunLimb, at shoulder: CGPoint) {
        arm.upper.position = shoulder
        content.addChild(arm.upper)
        nearArm = arm
    }

    /// Shows this figure and plays the cycle, or returns to `standing`.
    /// Safe to call every frame.
    func setRunning(_ running: Bool, hiding standing: SKNode) {
        guard running != isRunning else { return }
        isRunning = running
        standing.isHidden = running
        isHidden = !running
        isInJumpPose = false
        removeAction(forKey: "runCycle")
        guard running else { return }
        startCycle()
    }

    /// Holds the leaping pose for a jump taken mid-run. `.idle` means the jump
    /// has finished, so the stride picks back up. No effect when not running.
    func setJumpPhase(_ phase: JumpPhase) {
        guard isRunning else { return }
        guard let pose = RunCycle.jumpPose(for: phase) else {
            guard isInJumpPose else { return }
            isInJumpPose = false
            startCycle()
            return
        }

        isInJumpPose = true
        removeAction(forKey: "runCycle")
        let blend: TimeInterval = 0.07
        nearLeg.blend(to: pose.nearLeg, duration: blend)
        farLeg.blend(to: pose.farLeg, duration: blend)
        nearArm.blend(to: pose.nearArm, duration: blend)
        farArm.blend(to: pose.farArm, duration: blend)
        position.y = pose.isGrounded
            ? -min(RunCycle.footHeight(pose.nearLeg, legSegment: legSegment),
                   RunCycle.footHeight(pose.farLeg, legSegment: legSegment))
            : 0
        onJumpPhase?(phase)
    }

    private func startCycle() {
        cycleFrame = 0
        show(frame: cycleFrame)
        let step = SKAction.sequence([
            .wait(forDuration: RunCycle.frameDuration),
            .run { [weak self] in
                guard let self else { return }
                self.cycleFrame = (self.cycleFrame + 1) % RunCycle.frameCount
                self.show(frame: self.cycleFrame)
            }
        ])
        run(.repeatForever(step), withKey: "runCycle")
    }

    /// Limbs on opposite sides are half a cycle apart, and each arm swings
    /// opposite the leg on its own side.
    private func show(frame: Int) {
        let opposite = (frame + RunCycle.frameCount / 2) % RunCycle.frameCount
        position.y = RunCycle.bob(frame: frame, legSegment: legSegment)
        nearLeg.apply(RunCycle.legs[frame])
        farLeg.apply(RunCycle.legs[opposite])
        nearArm.apply(RunCycle.arms[opposite])
        farArm.apply(RunCycle.arms[frame])
        onFrame?(frame)
    }
}
