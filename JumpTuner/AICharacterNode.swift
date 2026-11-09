// AICharacterNode.swift
// SpriteKit character built from AI-generated visual parameters.
// Coordinate origin: feet at y=0, top at y≈43.

import SpriteKit

final class AICharacterNode: SKNode, CharacterNode {

    private let params: AICharacterParams
    private let standRig = SKNode()
    private let runRig: RunRig

    // Animated parts
    private var leftArmPivot:  SKNode!
    private var rightArmPivot: SKNode!
    private var eyeNodes: [SKShapeNode] = []

    init(params: AICharacterParams) {
        self.params = params
        let legLen: CGFloat = params.limbStyle == .stubby ? 5 : 7
        runRig = RunRig(legSegment: legLen, standHipY: 10, leanDegrees: 8)
        super.init()
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Build

    private func build() {
        addChild(standRig)
        addLegs()
        addBody()
        addArms()
        addHead()
        buildRunRig()
    }

    private var legLen: CGFloat { params.limbStyle == .stubby ? 5 : 10 }
    private var legWidth: CGFloat { params.limbStyle == .stubby ? 5 : 4.5 }

    private func addLegs() {
        for x: CGFloat in [-5, 5] {
            let leg = capsule(CGRect(x: -legWidth / 2, y: 0, width: legWidth, height: legLen),
                              fill: params.bodyColor, stroke: params.accentColor)
            leg.position = CGPoint(x: x, y: 0)
            standRig.addChild(leg)
        }
    }

    private func addBody() {
        let torso = roundedRect(CGRect(x: -9, y: -8, width: 18, height: 16),
                                corner: 4, fill: params.bodyColor, stroke: params.accentColor, lineWidth: 2)
        torso.position = CGPoint(x: 0, y: 17)
        standRig.addChild(torso)
    }

    private func addArms() {
        let armLen: CGFloat = params.limbStyle == .stubby ? 7 : 11
        leftArmPivot  = makeArmPivot(length: armLen)
        rightArmPivot = makeArmPivot(length: armLen)
        leftArmPivot.position  = CGPoint(x: -13, y: 21)
        rightArmPivot.position = CGPoint(x:  13, y: 21)
        standRig.addChild(leftArmPivot)
        standRig.addChild(rightArmPivot)
    }

    private func makeArmPivot(length: CGFloat) -> SKNode {
        let pivot = SKNode()
        let arm = capsule(CGRect(x: -2, y: -length, width: 4, height: length),
                          fill: params.bodyColor, stroke: params.accentColor)
        pivot.addChild(arm)
        return pivot
    }

    private func addHead() {
        let head = headNode()
        head.position = CGPoint(x: 0, y: 30)
        standRig.addChild(head)

        // Ears
        if params.hasEars {
            for x: CGFloat in [-10, 10] {
                let ear = roundedRect(CGRect(x: -3, y: -4, width: 6, height: 8),
                                      corner: 3, fill: params.accentColor, stroke: nil)
                ear.position = CGPoint(x: x, y: 36)
                standRig.addChild(ear)
            }
        }

        // Eyes
        let positions = eyePositions(count: min(max(params.eyeCount, 1), 3))
        for pos in positions {
            let eye = dot(radius: 2.5, fill: params.accentColor)
            eye.position = CGPoint(x: pos.x, y: 30 + pos.y)
            standRig.addChild(eye)
            eyeNodes.append(eye)
        }

        // Antenna
        if params.hasAntenna {
            let stick = roundedRect(CGRect(x: -1, y: 0, width: 2, height: 6),
                                    corner: 1, fill: params.accentColor, stroke: nil)
            stick.position = CGPoint(x: 0, y: 37)
            standRig.addChild(stick)

            let ball = dot(radius: 2.5, fill: params.accentColor)
            ball.position = CGPoint(x: 0, y: 44)
            standRig.addChild(ball)
        }
    }

    private func headNode() -> SKShapeNode {
        switch params.headShape {
        case .round:
            return roundedRect(CGRect(x: -9, y: -7, width: 18, height: 14), corner: 7,
                                fill: params.bodyColor, stroke: params.accentColor, lineWidth: 2)
        case .square:
            return roundedRect(CGRect(x: -9, y: -7, width: 18, height: 14), corner: 2,
                                fill: params.bodyColor, stroke: params.accentColor, lineWidth: 2)
        case .diamond:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 7))
            path.addLine(to: CGPoint(x: 10, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -7))
            path.addLine(to: CGPoint(x: -10, y: 0))
            path.closeSubpath()
            let n = SKShapeNode(path: path)
            n.fillColor = params.bodyColor
            n.strokeColor = params.accentColor
            n.lineWidth = 2
            return n
        }
    }

    private func eyePositions(count: Int) -> [CGPoint] {
        switch count {
        case 1: return [CGPoint(x: 0, y: 0)]
        case 3: return [CGPoint(x: -5, y: 0), CGPoint(x: 0, y: 2), CGPoint(x: 5, y: 0)]
        default: return [CGPoint(x: -4, y: 0), CGPoint(x: 4, y: 0)]
        }
    }

    // MARK: - Run rig

    private func buildRunRig() {
        addChild(runRig)
        let legSeg: CGFloat = params.limbStyle == .stubby ? 5 : 7
        runRig.addLegs(far: makeRunLimb(segment: legSeg), near: makeRunLimb(segment: legSeg),
                       farX: 2, nearX: -1)

        let content = runRig.content

        runRig.addFarArm(makeRunArm(), at: CGPoint(x: 3, y: 22))

        let torso = roundedRect(CGRect(x: -8, y: -8, width: 16, height: 16),
                                corner: 4, fill: params.bodyColor, stroke: params.accentColor, lineWidth: 2)
        torso.position = CGPoint(x: 0, y: 17)
        content.addChild(torso)

        let headR = headNode()
        headR.position = CGPoint(x: 1.5, y: 30)
        content.addChild(headR)

        for pos in eyePositions(count: min(max(params.eyeCount, 1), 3)) {
            let eye = dot(radius: 2, fill: params.accentColor)
            eye.position = CGPoint(x: pos.x + 1.5, y: 30 + pos.y)
            content.addChild(eye)
        }

        runRig.addNearArm(makeRunArm(), at: CGPoint(x: 0, y: 21))
    }

    private func makeRunLimb(segment: CGFloat) -> RunLimb {
        let limb = RunLimb(length: segment, width: 4,
                           fill: params.bodyColor, stroke: params.accentColor)
        limb.lower.addChild(roundedRect(
            CGRect(x: -2, y: -segment, width: 7, height: 3),
            corner: 1.5, fill: params.bodyColor, stroke: params.accentColor, lineWidth: 1))
        return limb
    }

    private func makeRunArm() -> RunLimb {
        RunLimb(length: 6, width: 4, fill: params.bodyColor, stroke: params.accentColor)
    }

    // MARK: - CharacterNode

    func setPhase(_ phase: JumpPhase, duration: TimeInterval = 0.08) {
        runRig.setJumpPhase(phase)

        let armAngle: CGFloat
        let eyeScale: CGFloat
        switch phase {
        case .squat:               armAngle = 0;             eyeScale = 0.5
        case .ascending:           armAngle = .pi * 50/180;  eyeScale = 1.0
        case .apex:                armAngle = .pi * 25/180;  eyeScale = 1.5
        case .descending, .landing:armAngle = -.pi * 25/180; eyeScale = 1.0
        case .idle:                armAngle = 0;             eyeScale = 1.0
        }

        leftArmPivot.run(.rotate(toAngle:  armAngle, duration: duration, shortestUnitArc: true))
        rightArmPivot.run(.rotate(toAngle: -armAngle, duration: duration, shortestUnitArc: true))
        eyeNodes.forEach { $0.run(.scale(to: eyeScale, duration: duration)) }
    }

    func setRunning(_ running: Bool) {
        runRig.setRunning(running, hiding: standRig)
    }

    // MARK: - Shape helpers

    private func roundedRect(_ rect: CGRect, corner: CGFloat,
                             fill: UIColor, stroke: UIColor? = nil, lineWidth: CGFloat = 0) -> SKShapeNode {
        let n = SKShapeNode(path: UIBezierPath(roundedRect: rect, cornerRadius: corner).cgPath)
        n.fillColor = fill
        n.strokeColor = stroke ?? .clear
        n.lineWidth = stroke != nil ? lineWidth : 0
        return n
    }

    private func capsule(_ rect: CGRect, fill: UIColor, stroke: UIColor? = nil) -> SKShapeNode {
        roundedRect(rect, corner: rect.width / 2, fill: fill, stroke: stroke, lineWidth: 1.5)
    }

    private func dot(radius: CGFloat, fill: UIColor) -> SKShapeNode {
        let n = SKShapeNode(circleOfRadius: radius)
        n.fillColor = fill
        n.strokeColor = .clear
        return n
    }
}
