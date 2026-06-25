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
        addFeet()
        addBody()
        addArms()
        addHead()
        addEars()
    }

    private func addFeet() {
        // Wide oval feet at ground level
        for (x, flip): (CGFloat, CGFloat) in [(-6, -1), (6, 1)] {
            let foot = ellipse(width: 14, height: 7, fill: Self.bodyColor,
                               stroke: Self.accentColor, lineWidth: 1)
            foot.position = CGPoint(x: x + flip * 1, y: 3.5)
            addChild(foot)
        }
    }

    private func addBody() {
        // Rounded torso
        let torso = roundedRect(CGRect(x: -9, y: -10, width: 18, height: 20),
                                corner: 7, fill: Self.bodyColor,
                                stroke: Self.accentColor, lineWidth: 1)
        torso.position = CGPoint(x: 0, y: 17)
        addChild(torso)

        // Fluffy tail — small circle peeking out the back
        let tail = circle(radius: 5, fill: Self.bodyColor)
        tail.position = CGPoint(x: -12, y: 16)
        addChild(tail)

        // Belly highlight
        let belly = ellipse(width: 10, height: 14, fill: Self.innerEar.withAlphaComponent(0.4))
        belly.position = CGPoint(x: 0, y: 17)
        addChild(belly)
    }

    private func addArms() {
        for x: CGFloat in [-13, 13] {
            let arm = roundedRect(CGRect(x: -3, y: -5, width: 6, height: 10),
                                  corner: 3, fill: Self.bodyColor,
                                  stroke: Self.accentColor, lineWidth: 1)
            arm.position = CGPoint(x: x, y: 15)
            addChild(arm)
        }
    }

    private func addHead() {
        // Round head
        let head = circle(radius: 11, fill: Self.bodyColor)
        head.strokeColor = Self.accentColor
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: 33)
        addChild(head)

        // Eyes
        leftEye  = circle(radius: 2.5, fill: Self.eyeColor)
        rightEye = circle(radius: 2.5, fill: Self.eyeColor)
        leftEye.position  = CGPoint(x: -4, y: 34)
        rightEye.position = CGPoint(x:  4, y: 34)
        addChild(leftEye)
        addChild(rightEye)

        // Eye shine
        for (base, dx): (SKShapeNode, CGFloat) in [(leftEye, -4), (rightEye, 4)] {
            let shine = circle(radius: 0.9, fill: .white)
            shine.position = CGPoint(x: dx + 1, y: 35)
            addChild(shine)
            _ = base // suppress warning
        }

        // Nose
        let nose = circle(radius: 2, fill: Self.accentColor)
        nose.position = CGPoint(x: 0, y: 30)
        addChild(nose)

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
        addChild(mouth)
    }

    private func addEars() {
        // Ear pivots sit at the top of the head; shapes extend upward.
        leftEarPivot  = makeEar(facingLeft: true)
        rightEarPivot = makeEar(facingLeft: false)
        leftEarPivot.position  = CGPoint(x: -4, y: 43)
        rightEarPivot.position = CGPoint(x:  4, y: 43)
        addChild(leftEarPivot)
        addChild(rightEarPivot)
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
