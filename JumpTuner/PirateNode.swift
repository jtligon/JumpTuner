// PirateNode.swift
// Procedural pirate character for SpriteKit.
// Coordinate origin: boot soles at y=0, hat tip at y≈56.

import SpriteKit

final class PirateNode: SKNode, CharacterNode {

    private static let skin      = UIColor(red: 0.95, green: 0.75, blue: 0.55, alpha: 1)
    private static let coat      = UIColor(red: 0.22, green: 0.14, blue: 0.36, alpha: 1) // dark plum
    private static let coatTrim  = UIColor(red: 0.70, green: 0.50, blue: 0.20, alpha: 1) // gold
    private static let hat       = UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1) // near-black
    private static let shirt     = UIColor(red: 0.92, green: 0.88, blue: 0.72, alpha: 1) // cream
    private static let boot      = UIColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 1) // dark brown
    private static let belt      = UIColor(red: 0.40, green: 0.25, blue: 0.10, alpha: 1) // brown
    private static let buckle    = UIColor(red: 0.85, green: 0.70, blue: 0.20, alpha: 1) // gold

    private var leftArmPivot:  SKNode!
    private var rightArmPivot: SKNode!
    private var hatNode:       SKNode!
    private var leftEye:       SKShapeNode!
    private var rightEye:      SKShapeNode! // has patch

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
        addBoots()
        addLegs()
        addBelt()
        addBody()
        addArms()
        addHead()
        addHat()
    }

    private func addBoots() {
        // Low, wide boots
        for x: CGFloat in [-6, 6] {
            let boot = roundedRect(CGRect(x: -5, y: 0, width: 10, height: 8),
                                   corner: 2, fill: Self.boot)
            boot.position = CGPoint(x: x, y: 0)
            addChild(boot)
        }
    }

    private func addLegs() {
        // Dark trousers
        let pants = roundedRect(CGRect(x: -9, y: 0, width: 18, height: 11),
                                corner: 2, fill: Self.coat)
        pants.position = CGPoint(x: 0, y: 8)
        addChild(pants)
    }

    private func addBelt() {
        let b = roundedRect(CGRect(x: -10, y: -2, width: 20, height: 4),
                            corner: 1, fill: Self.belt)
        b.position = CGPoint(x: 0, y: 19)
        addChild(b)

        // Buckle
        let buckle = roundedRect(CGRect(x: -3, y: -2, width: 6, height: 4),
                                 corner: 1, fill: Self.buckle)
        buckle.position = CGPoint(x: 0, y: 19)
        addChild(buckle)
    }

    private func addBody() {
        // Coat body
        let body = roundedRect(CGRect(x: -10, y: -9, width: 20, height: 18),
                               corner: 4, fill: Self.coat,
                               stroke: Self.coatTrim, lineWidth: 1.5)
        body.position = CGPoint(x: 0, y: 28)
        addChild(body)

        // Shirt/chest opening
        let chest = roundedRect(CGRect(x: -4, y: -7, width: 8, height: 14),
                                corner: 2, fill: Self.shirt)
        chest.position = CGPoint(x: 0, y: 28)
        addChild(chest)

        // Coat lapels — small triangular flaps using path
        for side: CGFloat in [-1, 1] {
            let lapel = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: side * 4, y: 35))
            path.addLine(to: CGPoint(x: side * 10, y: 37))
            path.addLine(to: CGPoint(x: side * 10, y: 29))
            path.closeSubpath()
            lapel.path = path
            lapel.fillColor = Self.coat
            lapel.strokeColor = Self.coatTrim
            lapel.lineWidth = 1
            addChild(lapel)
        }
    }

    private func addArms() {
        // Arms pivot at shoulder, hanging down. Right arm holds a cutlass.
        leftArmPivot  = makeArm(isRight: false)
        rightArmPivot = makeArm(isRight: true)
        leftArmPivot.position  = CGPoint(x: -11, y: 35)
        rightArmPivot.position = CGPoint(x:  11, y: 35)
        addChild(leftArmPivot)
        addChild(rightArmPivot)
    }

    private func makeArm(isRight: Bool) -> SKNode {
        let pivot = SKNode()

        // Sleeve
        let sleeve = roundedRect(CGRect(x: -3, y: -11, width: 6, height: 11),
                                 corner: 3, fill: Self.coat,
                                 stroke: Self.coatTrim, lineWidth: 1)
        pivot.addChild(sleeve)

        // Cuff
        let cuff = roundedRect(CGRect(x: -3.5, y: -13, width: 7, height: 3.5),
                               corner: 1.5, fill: Self.shirt)
        pivot.addChild(cuff)

        // Right arm: cutlass blade pointing outward
        if isRight {
            let blade = SKShapeNode()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 2, y: -13))
            p.addLine(to: CGPoint(x: 6, y: -26))
            p.addLine(to: CGPoint(x: 8, y: -24))
            p.addLine(to: CGPoint(x: 4, y: -13))
            p.closeSubpath()
            blade.path = p
            blade.fillColor = UIColor(red: 0.75, green: 0.78, blue: 0.82, alpha: 1) // steel
            blade.strokeColor = UIColor(white: 0.9, alpha: 0.6)
            blade.lineWidth = 0.5
            pivot.addChild(blade)

            // Guard
            let guard_ = roundedRect(CGRect(x: 0, y: -15, width: 9, height: 3),
                                     corner: 1.5, fill: Self.buckle)
            pivot.addChild(guard_)
        }

        return pivot
    }

    private func addHead() {
        // Face
        let face = roundedRect(CGRect(x: -9, y: -8, width: 18, height: 16),
                               corner: 6, fill: Self.skin)
        face.position = CGPoint(x: 0, y: 43)
        addChild(face)

        // Beard / stubble — dark rounded rect on chin
        let beard = roundedRect(CGRect(x: -7, y: -10, width: 14, height: 5),
                                corner: 3, fill: UIColor(red: 0.25, green: 0.15, blue: 0.10, alpha: 0.85))
        beard.position = CGPoint(x: 0, y: 43)
        addChild(beard)

        // Left eye (good eye)
        leftEye = SKShapeNode(circleOfRadius: 2.5)
        leftEye.fillColor   = UIColor(red: 0.15, green: 0.20, blue: 0.35, alpha: 1)
        leftEye.strokeColor = .clear
        leftEye.position    = CGPoint(x: -4, y: 44)
        addChild(leftEye)

        // Right eye + patch
        let patch = roundedRect(CGRect(x: -4.5, y: -3, width: 9, height: 6),
                                corner: 2, fill: UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1))
        patch.position = CGPoint(x: 4, y: 44)
        addChild(patch)

        // Patch strap
        let strap = SKShapeNode()
        let strPath = CGMutablePath()
        strPath.move(to: CGPoint(x: -0.5, y: 47))
        strPath.addLine(to: CGPoint(x: 9, y: 47))
        strap.path = strPath
        strap.strokeColor = UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.8)
        strap.lineWidth = 1.5
        addChild(strap)

        // Right eye hidden by patch
        rightEye = SKShapeNode(circleOfRadius: 2)
        rightEye.fillColor = .clear
        rightEye.position  = CGPoint(x: 4, y: 44)
        addChild(rightEye)

        // Nose
        let nose = roundedRect(CGRect(x: -2, y: -1.5, width: 4, height: 3), corner: 1.5,
                               fill: Self.skin.withAlphaComponent(0))
        let noseDot = SKShapeNode(circleOfRadius: 1.5)
        noseDot.fillColor = UIColor(red: 0.80, green: 0.60, blue: 0.45, alpha: 1)
        noseDot.strokeColor = .clear
        noseDot.position = CGPoint(x: 0, y: 40)
        addChild(noseDot)
        _ = nose
    }

    private func addHat() {
        hatNode = SKNode()
        hatNode.position = CGPoint(x: 0, y: 51)

        // Brim
        let brim = roundedRect(CGRect(x: -12, y: -2, width: 24, height: 4),
                               corner: 1, fill: Self.hat)
        hatNode.addChild(brim)

        // Crown
        let crown = roundedRect(CGRect(x: -8, y: 2, width: 16, height: 14),
                                corner: 3, fill: Self.hat)
        hatNode.addChild(crown)

        // Skull — white circle + crossbones dots
        let skull = SKShapeNode(circleOfRadius: 3.5)
        skull.fillColor = .white
        skull.strokeColor = .clear
        skull.position = CGPoint(x: 0, y: 9)
        hatNode.addChild(skull)

        // Eye dots on skull
        for dx: CGFloat in [-1.3, 1.3] {
            let dot = SKShapeNode(circleOfRadius: 0.8)
            dot.fillColor = Self.hat
            dot.strokeColor = .clear
            dot.position = CGPoint(x: dx, y: 9.5)
            hatNode.addChild(dot)
        }

        // Hat band
        let band = roundedRect(CGRect(x: -8, y: 2, width: 16, height: 3),
                               corner: 0, fill: Self.coatTrim)
        hatNode.addChild(band)

        addChild(hatNode)
    }

    // MARK: - Phase animation

    func setPhase(_ phase: JumpPhase, duration: TimeInterval = 0.08) {
        let leftArmAngle:  CGFloat
        let rightArmAngle: CGFloat
        let hatAngle:      CGFloat
        let eyeScale:      CGFloat

        switch phase {
        case .squat:
            leftArmAngle  =  0.3   // arms bend back slightly
            rightArmAngle = -0.1   // sword arm ready
            hatAngle      = -0.1
            eyeScale      =  0.7
        case .ascending:
            leftArmAngle  =  0.8   // arm sweeps up
            rightArmAngle = -0.6   // sword thrusts forward-up
            hatAngle      =  0.15  // hat tips back
            eyeScale      =  1.0
        case .apex:
            leftArmAngle  =  0.5
            rightArmAngle = -0.4
            hatAngle      =  0.05
            eyeScale      =  1.4
        case .descending:
            leftArmAngle  = -0.3
            rightArmAngle =  0.2
            hatAngle      = -0.1
            eyeScale      =  0.8
        case .landing:
            leftArmAngle  = -0.5
            rightArmAngle =  0.3
            hatAngle      =  0.2
            eyeScale      =  0.5
        case .idle:
            leftArmAngle  =  0
            rightArmAngle =  0
            hatAngle      =  0
            eyeScale      =  1.0
        }

        leftArmPivot.run(.rotate(toAngle:  leftArmAngle,  duration: duration, shortestUnitArc: true))
        rightArmPivot.run(.rotate(toAngle: rightArmAngle, duration: duration, shortestUnitArc: true))
        hatNode.run(.rotate(toAngle: hatAngle, duration: duration, shortestUnitArc: true))
        leftEye.run(.scale(to: eyeScale, duration: duration))
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
}
