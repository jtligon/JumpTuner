// RobotNode.swift
// SpriteKit version of RobotView — same colors and proportions, built from SKShapeNodes.
// Coordinate origin: feet at y=0, top of antenna at y≈43.

import SpriteKit

final class RobotNode: SKNode, CharacterNode {

    // MARK: - Colors (mirrors Theme.swift)
    private static let bodyColor   = UIColor(red: 0.95, green: 0.82, blue: 0.25, alpha: 1)
    private static let accentColor = UIColor(red: 1.00, green: 0.45, blue: 0.20, alpha: 1)

    // MARK: - Animated parts
    private var leftArmPivot:  SKNode!
    private var rightArmPivot: SKNode!
    private var leftEye:       SKShapeNode!
    private var rightEye:      SKShapeNode!

    // MARK: - Init

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
        // All positions use SpriteKit coords (y+ up), with feet at y=0.
        // Conversion from SwiftUI RobotView offsets: SK_y = 24 − swiftui_y
        addLegs()
        addBody()
        addArms()
        addHead()
    }

    private func addLegs() {
        for x: CGFloat in [-6, 6] {
            let leg = roundedRect(CGRect(x: -2.5, y: 0, width: 5, height: 10),
                                  corner: 2.5, fill: Self.bodyColor, stroke: Self.accentColor, lineWidth: 1.5)
            leg.position = CGPoint(x: x, y: 0)
            addChild(leg)
        }
    }

    private func addBody() {
        // Torso — 20×16 centered at y=17
        let torso = roundedRect(CGRect(x: -10, y: -8, width: 20, height: 16),
                                corner: 5, fill: Self.bodyColor, stroke: Self.accentColor, lineWidth: 2)
        torso.position = CGPoint(x: 0, y: 17)
        addChild(torso)

        // Chest detail
        let chest = roundedRect(CGRect(x: -4, y: -2.5, width: 8, height: 5),
                                corner: 2, fill: Self.accentColor.withAlphaComponent(0.6))
        chest.position = CGPoint(x: 0, y: 17)
        addChild(chest)
    }

    private func addArms() {
        // Arms pivot at shoulder, shape hangs downward from pivot.
        // Shoulder positions: x=±14, y=21  (SK: 24−3=21)
        leftArmPivot  = makeArmPivot()
        rightArmPivot = makeArmPivot()
        leftArmPivot.position  = CGPoint(x: -14, y: 21)
        rightArmPivot.position = CGPoint(x:  14, y: 21)
        addChild(leftArmPivot)
        addChild(rightArmPivot)
    }

    private func makeArmPivot() -> SKNode {
        let pivot = SKNode()
        // Arm shape: 5×11 capsule hanging from pivot (y goes from 0 down to −11)
        let arm = roundedRect(CGRect(x: -2.5, y: -11, width: 5, height: 11),
                              corner: 2.5, fill: Self.bodyColor, stroke: Self.accentColor, lineWidth: 1.5)
        pivot.addChild(arm)
        return pivot
    }

    private func addHead() {
        // Head — 18×15 centered at y=30  (SK: 24−(−6)=30)
        let head = roundedRect(CGRect(x: -9, y: -7.5, width: 18, height: 15),
                               corner: 6, fill: Self.bodyColor, stroke: Self.accentColor, lineWidth: 2)
        head.position = CGPoint(x: 0, y: 30)
        addChild(head)

        // Eyes
        leftEye  = dot(radius: 2, fill: Self.accentColor)
        rightEye = dot(radius: 2, fill: Self.accentColor)
        leftEye.position  = CGPoint(x: -4.5, y: 30)
        rightEye.position = CGPoint(x:  4.5, y: 30)
        addChild(leftEye)
        addChild(rightEye)

        // Antenna stick + dot
        let stick = roundedRect(CGRect(x: -1, y: 0, width: 2, height: 5),
                                corner: 1, fill: Self.accentColor)
        stick.position = CGPoint(x: 0, y: 37)
        addChild(stick)

        let antennaDot = dot(radius: 2, fill: Self.accentColor)
        antennaDot.position = CGPoint(x: 0, y: 43)
        addChild(antennaDot)
    }

    // MARK: - Phase animation

    func setPhase(_ phase: JumpPhase, duration: TimeInterval = 0.08) {
        // Arm angles: positive = CCW in SpriteKit (y-up). Match RobotView behaviour:
        //   launch/ascent → arms reach up (left arm swings right/up, right arm left/up)
        //   descent/land  → arms trail back
        let armAngle: CGFloat
        let eyeScale: CGFloat

        switch phase {
        case .squat:
            armAngle = 0
            eyeScale = 0.5
        case .ascending:
            armAngle = .pi * 50 / 180
            eyeScale = 1.0
        case .apex:
            armAngle = .pi * 25 / 180
            eyeScale = 1.5
        case .descending, .landing:
            armAngle = -.pi * 25 / 180
            eyeScale = 1.0
        case .idle:
            armAngle = 0
            eyeScale = 1.0
        }

        leftArmPivot.run(.rotate(toAngle:  armAngle, duration: duration, shortestUnitArc: true))
        rightArmPivot.run(.rotate(toAngle: -armAngle, duration: duration, shortestUnitArc: true))

        let eyeAnim = SKAction.scale(to: eyeScale, duration: duration)
        leftEye.run(eyeAnim)
        rightEye.run(eyeAnim)
    }

    // MARK: - Shape helpers

    private func roundedRect(_ rect: CGRect, corner: CGFloat,
                             fill: UIColor, stroke: UIColor? = nil, lineWidth: CGFloat = 0) -> SKShapeNode {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: corner)
        let node = SKShapeNode(path: path.cgPath)
        node.fillColor   = fill
        node.strokeColor = stroke ?? .clear
        node.lineWidth   = stroke != nil ? lineWidth : 0
        return node
    }

    private func dot(radius: CGFloat, fill: UIColor) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor   = fill
        node.strokeColor = .clear
        return node
    }
}
