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

    /// Front-facing figure used for standing and jumping.
    private let standRig = SKNode()
    /// Side-on figure shown only while running.
    private let runRig = RunRig(legSegment: 10.5, standHipY: 19, leanDegrees: 7)

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
        addBoots()
        addLegs()
        addBelt()
        addBody()
        addArms()
        addHead()
        addHat()
        buildRunRig()
    }

    private func addBoots() {
        // Low, wide boots
        for x: CGFloat in [-6, 6] {
            let boot = roundedRect(CGRect(x: -5, y: 0, width: 10, height: 8),
                                   corner: 2, fill: Self.boot)
            boot.position = CGPoint(x: x, y: 0)
            standRig.addChild(boot)
        }
    }

    private func addLegs() {
        // Dark trousers
        let pants = roundedRect(CGRect(x: -9, y: 0, width: 18, height: 11),
                                corner: 2, fill: Self.coat)
        pants.position = CGPoint(x: 0, y: 8)
        standRig.addChild(pants)
    }

    private func addBelt() {
        let b = roundedRect(CGRect(x: -10, y: -2, width: 20, height: 4),
                            corner: 1, fill: Self.belt)
        b.position = CGPoint(x: 0, y: 19)
        standRig.addChild(b)

        // Buckle
        let buckle = roundedRect(CGRect(x: -3, y: -2, width: 6, height: 4),
                                 corner: 1, fill: Self.buckle)
        buckle.position = CGPoint(x: 0, y: 19)
        standRig.addChild(buckle)
    }

    private func addBody() {
        // Coat body
        let body = roundedRect(CGRect(x: -10, y: -9, width: 20, height: 18),
                               corner: 4, fill: Self.coat,
                               stroke: Self.coatTrim, lineWidth: 1.5)
        body.position = CGPoint(x: 0, y: 28)
        standRig.addChild(body)

        // Shirt/chest opening
        let chest = roundedRect(CGRect(x: -4, y: -7, width: 8, height: 14),
                                corner: 2, fill: Self.shirt)
        chest.position = CGPoint(x: 0, y: 28)
        standRig.addChild(chest)

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
            standRig.addChild(lapel)
        }
    }

    private func addArms() {
        // Arms pivot at shoulder, hanging down. Right arm holds a cutlass.
        leftArmPivot  = makeArm(isRight: false)
        rightArmPivot = makeArm(isRight: true)
        leftArmPivot.position  = CGPoint(x: -11, y: 35)
        rightArmPivot.position = CGPoint(x:  11, y: 35)
        standRig.addChild(leftArmPivot)
        standRig.addChild(rightArmPivot)
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
        standRig.addChild(face)

        // Beard / stubble — dark rounded rect on chin
        let beard = roundedRect(CGRect(x: -7, y: -10, width: 14, height: 5),
                                corner: 3, fill: UIColor(red: 0.25, green: 0.15, blue: 0.10, alpha: 0.85))
        beard.position = CGPoint(x: 0, y: 43)
        standRig.addChild(beard)

        // Left eye (good eye)
        leftEye = SKShapeNode(circleOfRadius: 2.5)
        leftEye.fillColor   = UIColor(red: 0.15, green: 0.20, blue: 0.35, alpha: 1)
        leftEye.strokeColor = .clear
        leftEye.position    = CGPoint(x: -4, y: 44)
        standRig.addChild(leftEye)

        // Right eye + patch
        let patch = roundedRect(CGRect(x: -4.5, y: -3, width: 9, height: 6),
                                corner: 2, fill: UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1))
        patch.position = CGPoint(x: 4, y: 44)
        standRig.addChild(patch)

        // Patch strap
        let strap = SKShapeNode()
        let strPath = CGMutablePath()
        strPath.move(to: CGPoint(x: -0.5, y: 47))
        strPath.addLine(to: CGPoint(x: 9, y: 47))
        strap.path = strPath
        strap.strokeColor = UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.8)
        strap.lineWidth = 1.5
        standRig.addChild(strap)

        // Right eye hidden by patch
        rightEye = SKShapeNode(circleOfRadius: 2)
        rightEye.fillColor = .clear
        rightEye.position  = CGPoint(x: 4, y: 44)
        standRig.addChild(rightEye)

        // Nose
        let nose = roundedRect(CGRect(x: -2, y: -1.5, width: 4, height: 3), corner: 1.5,
                               fill: Self.skin.withAlphaComponent(0))
        let noseDot = SKShapeNode(circleOfRadius: 1.5)
        noseDot.fillColor = UIColor(red: 0.80, green: 0.60, blue: 0.45, alpha: 1)
        noseDot.strokeColor = .clear
        noseDot.position = CGPoint(x: 0, y: 40)
        standRig.addChild(noseDot)
        _ = nose
    }

    private func addHat() {
        hatNode = makeHat()
        hatNode.position = CGPoint(x: 0, y: 51)
        standRig.addChild(hatNode)
    }

    private func makeHat() -> SKNode {
        let hat = SKNode()

        // Brim
        let brim = roundedRect(CGRect(x: -12, y: -2, width: 24, height: 4),
                               corner: 1, fill: Self.hat)
        hat.addChild(brim)

        // Crown
        let crown = roundedRect(CGRect(x: -8, y: 2, width: 16, height: 14),
                                corner: 3, fill: Self.hat)
        hat.addChild(crown)

        // Skull — white circle + crossbones dots
        let skull = SKShapeNode(circleOfRadius: 3.5)
        skull.fillColor = .white
        skull.strokeColor = .clear
        skull.position = CGPoint(x: 0, y: 9)
        hat.addChild(skull)

        // Eye dots on skull
        for dx: CGFloat in [-1.3, 1.3] {
            let dot = SKShapeNode(circleOfRadius: 0.8)
            dot.fillColor = Self.hat
            dot.strokeColor = .clear
            dot.position = CGPoint(x: dx, y: 9.5)
            hat.addChild(dot)
        }

        // Hat band
        let band = roundedRect(CGRect(x: -8, y: 2, width: 16, height: 3),
                               corner: 0, fill: Self.coatTrim)
        hat.addChild(band)

        return hat
    }

    // MARK: - Phase animation

    func setPhase(_ phase: JumpPhase, duration: TimeInterval = 0.08) {
        runRig.setJumpPhase(phase)

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

    // MARK: - Run cycle

    func setRunning(_ running: Bool) {
        runRig.setRunning(running, hiding: standRig)
    }

    private func buildRunRig() {
        let farCoat = UIColor(red: 0.16, green: 0.10, blue: 0.27, alpha: 1)
        addChild(runRig)

        runRig.addLegs(far: makeRunLeg(fill: farCoat), near: makeRunLeg(fill: Self.coat),
                       farX: 3, nearX: -2)
        let content = runRig.content

        runRig.addFarArm(makeRunArm(fill: farCoat), at: CGPoint(x: 3, y: 35))

        let belt = roundedRect(CGRect(x: -9, y: -2, width: 18, height: 4),
                               corner: 1, fill: Self.belt)
        belt.position = CGPoint(x: 0, y: 19)
        content.addChild(belt)

        let body = roundedRect(CGRect(x: -8, y: -9, width: 16, height: 18),
                               corner: 4, fill: Self.coat,
                               stroke: Self.coatTrim, lineWidth: 1.5)
        body.position = CGPoint(x: 0, y: 28)
        content.addChild(body)

        let chest = roundedRect(CGRect(x: -3, y: -7, width: 6, height: 14),
                                corner: 2, fill: Self.shirt)
        chest.position = CGPoint(x: 3.5, y: 28)
        content.addChild(chest)

        let buckle = roundedRect(CGRect(x: -2.5, y: -2, width: 5, height: 4),
                                 corner: 1, fill: Self.buckle)
        buckle.position = CGPoint(x: 4, y: 19)
        content.addChild(buckle)

        addRunFace(to: content)

        let hat = makeHat()
        hat.position = CGPoint(x: 2, y: 51)
        content.addChild(hat)

        runRig.addNearArm(makeRunSwordArm(), at: CGPoint(x: 0, y: 35))

        // The hat lifts off the head on each landing and tips with the stride.
        let hatLift: [CGFloat] = [0, 2, 1, 0]
        runRig.onFrame = { frame in
            hat.position.y = 51 + hatLift[frame % hatLift.count]
            hat.zRotation  = 0.12 + sin(CGFloat(frame) * .pi / 4) * 0.08
        }

        // The hat tips back on the rise and floats off the head on the way down.
        runRig.onJumpPhase = { phase in
            let lift: CGFloat
            let tilt: CGFloat
            switch phase {
            case .squat:      (lift, tilt) = (0, 0.05)
            case .ascending:  (lift, tilt) = (0, 0.3)
            case .apex:       (lift, tilt) = (1, 0.15)
            case .descending: (lift, tilt) = (5, -0.1)
            case .landing:    (lift, tilt) = (0, 0.2)
            case .idle:       (lift, tilt) = (0, 0.12)
            }
            hat.run(.group([
                .moveTo(y: 51 + lift, duration: 0.1),
                .rotate(toAngle: tilt, duration: 0.1, shortestUnitArc: true)
            ]))
        }
    }

    private func addRunFace(to content: SKNode) {
        let face = roundedRect(CGRect(x: -8.5, y: -8, width: 17, height: 16),
                               corner: 6, fill: Self.skin)
        face.position = CGPoint(x: 2, y: 43)
        content.addChild(face)

        let beard = roundedRect(CGRect(x: -6, y: -10, width: 13, height: 5),
                                corner: 3, fill: UIColor(red: 0.25, green: 0.15, blue: 0.10, alpha: 0.85))
        beard.position = CGPoint(x: 4, y: 43)
        content.addChild(beard)

        let eye = SKShapeNode(circleOfRadius: 2.5)
        eye.fillColor   = UIColor(red: 0.15, green: 0.20, blue: 0.35, alpha: 1)
        eye.strokeColor = .clear
        eye.position    = CGPoint(x: 1.5, y: 44)
        content.addChild(eye)

        let patch = roundedRect(CGRect(x: -4, y: -3, width: 8, height: 6),
                                corner: 2, fill: UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1))
        patch.position = CGPoint(x: 7, y: 44)
        content.addChild(patch)

        let strap = SKShapeNode()
        let strapPath = CGMutablePath()
        strapPath.move(to: CGPoint(x: -6, y: 47))
        strapPath.addLine(to: CGPoint(x: 7, y: 47))
        strap.path = strapPath
        strap.strokeColor = UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.8)
        strap.lineWidth = 1.5
        content.addChild(strap)

        let nose = SKShapeNode(circleOfRadius: 1.5)
        nose.fillColor   = UIColor(red: 0.80, green: 0.60, blue: 0.45, alpha: 1)
        nose.strokeColor = .clear
        nose.position    = CGPoint(x: 9.5, y: 40)
        content.addChild(nose)
    }

    private func makeRunLeg(fill: UIColor) -> RunLimb {
        let length: CGFloat = 10.5
        let limb = RunLimb(length: length, width: 7, fill: fill,
                           stroke: Self.coatTrim.withAlphaComponent(0.5), lineWidth: 0.75)
        limb.lower.addChild(roundedRect(CGRect(x: -3.5, y: -length, width: 11, height: 6),
                                        corner: 2, fill: Self.boot))
        return limb
    }

    private let runArmLength: CGFloat = 7

    private func makeRunArm(fill: UIColor) -> RunLimb {
        let limb = RunLimb(length: runArmLength, width: 5.5, fill: fill, stroke: Self.coatTrim)
        limb.lower.addChild(roundedRect(CGRect(x: -3, y: -runArmLength - 1, width: 6, height: 3),
                                        corner: 1.5, fill: Self.shirt))
        return limb
    }

    /// The near arm, with the cutlass held in line with the forearm.
    private func makeRunSwordArm() -> RunLimb {
        let limb = makeRunArm(fill: Self.coat)
        let hand = -runArmLength - 1

        let blade = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -1.2, y: hand))
        path.addLine(to: CGPoint(x: -0.5, y: hand - 15))
        path.addLine(to: CGPoint(x: 2, y: hand - 13))
        path.addLine(to: CGPoint(x: 1.5, y: hand))
        path.closeSubpath()
        blade.path = path
        blade.fillColor   = UIColor(red: 0.75, green: 0.78, blue: 0.82, alpha: 1)
        blade.strokeColor = UIColor(white: 0.9, alpha: 0.6)
        blade.lineWidth   = 0.5
        limb.lower.addChild(blade)

        limb.lower.addChild(roundedRect(CGRect(x: -4, y: hand - 2, width: 8, height: 2.5),
                                        corner: 1.25, fill: Self.buckle))
        return limb
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
