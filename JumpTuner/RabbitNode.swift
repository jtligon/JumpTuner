// RabbitNode.swift
// Procedural rabbit character for SpriteKit.
// Coordinate origin: feet at y=0, antenna-equivalent (ear tips) at y≈62.

import SpriteKit

final class RabbitNode: SKNode, CharacterNode {

    private static let bodyColor   = UIColor(red: 0.93, green: 0.90, blue: 0.88, alpha: 1) // cream white
    private static let accentColor = UIColor(red: 1.00, green: 0.60, blue: 0.70, alpha: 1) // soft pink
    private static let innerEar    = UIColor(red: 1.00, green: 0.75, blue: 0.80, alpha: 0.8)
    private static let eyeColor    = UIColor(red: 0.55, green: 0.20, blue: 0.30, alpha: 1) // dark rose

    private var leftEarPivot:  SKNode!
    private var rightEarPivot: SKNode!
    private var leftEye:       SKShapeNode!
    private var rightEye:      SKShapeNode!

    /// Front-facing figure used for standing and jumping.
    private let standRig = SKNode()
    /// Side-on figure shown only while running.
    private let runRig = RunRig(legSegment: 6.5, standHipY: 8, leanDegrees: 12)

    override init() {
        super.init()
        build()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    // MARK: - Build

    private func build() {
        addChild(standRig)
        addFeet()
        addBody()
        addArms()
        addHead()
        addEars()
        buildRunRig()
    }

    private func addFeet() {
        // Wide oval feet at ground level
        for (x, flip): (CGFloat, CGFloat) in [(-6, -1), (6, 1)] {
            let foot = ellipse(width: 14, height: 7, fill: Self.bodyColor,
                               stroke: Self.accentColor, lineWidth: 1)
            foot.position = CGPoint(x: x + flip * 1, y: 3.5)
            standRig.addChild(foot)
        }
    }

    private func addBody() {
        // Rounded torso
        let torso = roundedRect(CGRect(x: -9, y: -10, width: 18, height: 20),
                                corner: 7, fill: Self.bodyColor,
                                stroke: Self.accentColor, lineWidth: 1)
        torso.position = CGPoint(x: 0, y: 17)
        standRig.addChild(torso)

        // Fluffy tail — small circle peeking out the back
        let tail = circle(radius: 5, fill: Self.bodyColor)
        tail.position = CGPoint(x: -12, y: 16)
        standRig.addChild(tail)

        // Belly highlight
        let belly = ellipse(width: 10, height: 14, fill: Self.innerEar.withAlphaComponent(0.4))
        belly.position = CGPoint(x: 0, y: 17)
        standRig.addChild(belly)
    }

    private func addArms() {
        for x: CGFloat in [-13, 13] {
            let arm = roundedRect(CGRect(x: -3, y: -5, width: 6, height: 10),
                                  corner: 3, fill: Self.bodyColor,
                                  stroke: Self.accentColor, lineWidth: 1)
            arm.position = CGPoint(x: x, y: 15)
            standRig.addChild(arm)
        }
    }

    private func addHead() {
        // Round head
        let head = circle(radius: 11, fill: Self.bodyColor)
        head.strokeColor = Self.accentColor
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: 33)
        standRig.addChild(head)

        // Eyes
        leftEye  = circle(radius: 2.5, fill: Self.eyeColor)
        rightEye = circle(radius: 2.5, fill: Self.eyeColor)
        leftEye.position  = CGPoint(x: -4, y: 34)
        rightEye.position = CGPoint(x:  4, y: 34)
        standRig.addChild(leftEye)
        standRig.addChild(rightEye)

        // Eye shine
        for (base, dx): (SKShapeNode, CGFloat) in [(leftEye, -4), (rightEye, 4)] {
            let shine = circle(radius: 0.9, fill: .white)
            shine.position = CGPoint(x: dx + 1, y: 35)
            standRig.addChild(shine)
            _ = base // suppress warning
        }

        // Nose
        let nose = circle(radius: 2, fill: Self.accentColor)
        nose.position = CGPoint(x: 0, y: 30)
        standRig.addChild(nose)

        // Mouth — two tiny lines forming a Y shape
        let mouth = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 29))
        path.addLine(to: CGPoint(x: -2.5, y: 26))
        path.move(to: CGPoint(x: 0, y: 29))
        path.addLine(to: CGPoint(x: 2.5, y: 26))
        mouth.path = path
        mouth.strokeColor = Self.accentColor.withAlphaComponent(0.6)
        mouth.lineWidth = 1
        standRig.addChild(mouth)
    }

    private func addEars() {
        // Ear pivots sit at the top of the head; shapes extend upward.
        leftEarPivot  = makeEar(facingLeft: true)
        rightEarPivot = makeEar(facingLeft: false)
        leftEarPivot.position  = CGPoint(x: -4, y: 43)
        rightEarPivot.position = CGPoint(x:  4, y: 43)
        standRig.addChild(leftEarPivot)
        standRig.addChild(rightEarPivot)
    }

    private func makeEar(facingLeft: Bool) -> SKNode {
        let pivot = SKNode()

        // Outer ear (cream)
        let outer = roundedRect(CGRect(x: -3, y: 0, width: 6, height: 20),
                                corner: 3, fill: Self.bodyColor,
                                stroke: Self.accentColor, lineWidth: 1)
        pivot.addChild(outer)

        // Inner pink stripe
        let inner = roundedRect(CGRect(x: -1.5, y: 2, width: 3, height: 14),
                                corner: 1.5, fill: Self.innerEar)
        pivot.addChild(inner)

        return pivot
    }

    // MARK: - Phase animation

    func setPhase(_ phase: JumpPhase, duration: TimeInterval = 0.08) {
        runRig.setJumpPhase(phase)

        // Ears: positive SK angle = CCW. Left ear positive = leans left (outward).
        // Both ears lean the same direction to simulate wind/gravity effects.
        let leftAngle:  CGFloat
        let rightAngle: CGFloat
        let eyeScaleY:  CGFloat

        switch phase {
        case .squat:
            leftAngle  = -0.25   // tips squeeze inward
            rightAngle =  0.25
            eyeScaleY  =  0.4
        case .ascending:
            leftAngle  =  0.5    // ears stream back (left = outward/back)
            rightAngle =  0.5    // both lean the same way (back)
            eyeScaleY  =  1.0
        case .apex:
            leftAngle  =  0.0
            rightAngle =  0.0
            eyeScaleY  =  1.6   // wide-eyed floating
        case .descending:
            leftAngle  = -0.3   // ears forward / drooping
            rightAngle =  0.3
            eyeScaleY  =  0.8
        case .landing:
            leftAngle  = -0.5
            rightAngle =  0.5
            eyeScaleY  =  0.4
        case .idle:
            leftAngle  =  0
            rightAngle =  0
            eyeScaleY  =  1.0
        }

        leftEarPivot.run(.rotate(toAngle:  leftAngle,  duration: duration, shortestUnitArc: true))
        rightEarPivot.run(.rotate(toAngle: rightAngle, duration: duration, shortestUnitArc: true))

        let eyeAnim = SKAction.scaleY(to: eyeScaleY, duration: duration)
        leftEye.run(eyeAnim)
        rightEye.run(eyeAnim)
    }

    // MARK: - Run cycle

    func setRunning(_ running: Bool) {
        runRig.setRunning(running, hiding: standRig)
    }

    private func buildRunRig() {
        let farFill = UIColor(red: 0.76, green: 0.72, blue: 0.70, alpha: 1)
        addChild(runRig)

        runRig.addLegs(far: makeRunLeg(fill: farFill), near: makeRunLeg(fill: Self.bodyColor),
                       farX: 3, nearX: -1)
        let content = runRig.content

        let tail = circle(radius: 5, fill: Self.bodyColor)
        tail.position = CGPoint(x: -10, y: 13)
        content.addChild(tail)

        runRig.addFarArm(makeRunArm(fill: farFill), at: CGPoint(x: 4, y: 22))

        let torso = roundedRect(CGRect(x: -8, y: -10, width: 16, height: 20),
                                corner: 7, fill: Self.bodyColor,
                                stroke: Self.accentColor, lineWidth: 1)
        torso.position = CGPoint(x: 0, y: 17)
        content.addChild(torso)

        let belly = ellipse(width: 7, height: 14, fill: Self.innerEar.withAlphaComponent(0.4))
        belly.position = CGPoint(x: 4, y: 17)
        content.addChild(belly)

        // Ears go under the head and stream out behind it.
        let farEar  = makeEar(facingLeft: true)
        let nearEar = makeEar(facingLeft: true)
        farEar.position  = CGPoint(x: 3, y: 41)
        nearEar.position = CGPoint(x: 0, y: 41)
        content.addChild(farEar)
        content.addChild(nearEar)

        let head = circle(radius: 10.5, fill: Self.bodyColor)
        head.strokeColor = Self.accentColor
        head.lineWidth = 1
        head.position = CGPoint(x: 3, y: 33)
        content.addChild(head)

        for (x, radius): (CGFloat, CGFloat) in [(4, 2.5), (9.5, 2.2)] {
            let eye = circle(radius: radius, fill: Self.eyeColor)
            eye.position = CGPoint(x: x, y: 35)
            content.addChild(eye)
            let shine = circle(radius: 0.9, fill: .white)
            shine.position = CGPoint(x: x + 1, y: 36)
            content.addChild(shine)
        }

        let nose = circle(radius: 1.8, fill: Self.accentColor)
        nose.position = CGPoint(x: 11.5, y: 30)
        content.addChild(nose)

        runRig.addNearArm(makeRunArm(fill: Self.bodyColor), at: CGPoint(x: 0, y: 22))

        runRig.onFrame = { frame in
            let flop = sin(CGFloat(frame) * .pi / 2) * 0.22
            nearEar.zRotation = 1.15 + flop
            farEar.zRotation  = 1.0 - flop
        }

        // Ears trail the jump: flat on the way up, lifted by the air on the way down.
        runRig.onJumpPhase = { phase in
            let angle: CGFloat
            switch phase {
            case .squat:      angle = 1.3
            case .ascending:  angle = 1.45
            case .apex:       angle = 0.7
            case .descending: angle = 0.1
            case .landing:    angle = 1.5
            case .idle:       angle = 1.1
            }
            let rotate = SKAction.rotate(toAngle: angle, duration: 0.1, shortestUnitArc: true)
            nearEar.run(rotate)
            farEar.run(rotate)
        }
    }

    private func makeRunLeg(fill: UIColor) -> RunLimb {
        let length: CGFloat = 6.5
        let limb = RunLimb(length: length, width: 5, fill: fill, stroke: Self.accentColor)
        limb.lower.addChild(roundedRect(CGRect(x: -3, y: -length, width: 11, height: 4),
                                        corner: 2, fill: fill, stroke: Self.accentColor, lineWidth: 1))
        return limb
    }

    private func makeRunArm(fill: UIColor) -> RunLimb {
        RunLimb(length: 5, width: 5, fill: fill, stroke: Self.accentColor)
    }

    // MARK: - Shape helpers

    private func roundedRect(_ rect: CGRect, corner: CGFloat,
                             fill: UIColor, stroke: UIColor? = nil, lineWidth: CGFloat = 0) -> SKShapeNode {
        let node = SKShapeNode(path: UIBezierPath(roundedRect: rect, cornerRadius: corner).cgPath)
        node.fillColor   = fill
        node.strokeColor = stroke ?? .clear
        node.lineWidth   = stroke != nil ? lineWidth : 0
        return node
    }

    private func circle(radius: CGFloat, fill: UIColor) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor   = fill
        node.strokeColor = .clear
        return node
    }

    private func ellipse(width: CGFloat, height: CGFloat,
                         fill: UIColor, stroke: UIColor? = nil, lineWidth: CGFloat = 0) -> SKShapeNode {
        let node = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        node.fillColor   = fill
        node.strokeColor = stroke ?? .clear
        node.lineWidth   = stroke != nil ? lineWidth : 0
        return node
    }
}
