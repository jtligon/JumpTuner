// JumpScene.swift
// Jump cycle driven entirely by SKAction sequences — no physics, no contact detection.

import SpriteKit
import UIKit

final class JumpScene: SKScene {

    // MARK: - Nodes

    private var character: SKNode!
    private var characterNode: (any CharacterNode)!
    private var groundNode: SKNode!

    // MARK: - State

    var params: JumpParams = .defaults {
        didSet {
            if showPlatforms { updatePlatformNodes() }
            if isJumping { restartJump() }
        }
    }
    var isLooping: Bool = false
    var showFloatingText: Bool = true
    var showPlatforms: Bool = false {
        didSet {
            updatePlatformNodes()
            if isJumping { restartJump() }
        }
    }

    private var platformNodes: [SKNode] = []

    private let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)

    private var isJumping = false
    private let groundY: CGFloat = 36
    private let characterSize = CGSize(width: 36, height: 48)

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1)
        physicsWorld.gravity = .zero
        impactFeedback.prepare()
        setupStars()
        setupGround()
        setupCharacter()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        repositionNodes()
    }

    // MARK: - Public interface

    func triggerJump() {
        if isJumping {
            restartJump()
        } else {
            startJump()
        }
    }

    func stopJumping() {
        character.removeAllActions()
        characterNode.removeAllActions()
        isJumping = false
        isLooping = false
        character.position = CGPoint(x: characterX, y: characterRestY)
        character.xScale = 1
        character.yScale = 1
        characterNode.setPhase(.idle)
    }

    func setCharacter(_ skin: CharacterSkin) {
        characterNode?.removeFromParent()
        let newNode = skin.make()
        newNode.position = CGPoint(x: 0, y: 0)
        character.addChild(newNode)
        characterNode = newNode
        characterNode.setPhase(.idle)
        if isJumping { restartJump() }
    }

    // MARK: - Layout helpers

    private var characterX: CGFloat { size.width * 0.3 }
    // character origin at feet level; visual nodes have feet at y=0 in local space
    private var characterRestY: CGFloat { groundY + 2 }

    private func scaledHeight() -> CGFloat {
        let groundClearance: CGFloat = 60
        let maxPixels = max(size.height - characterRestY - groundClearance, 80)
        return CGFloat(params.jumpHeight / 500.0) * maxPixels
    }

    private func repositionNodes() {
        groundNode?.position = CGPoint(x: size.width / 2, y: groundY)
        if !isJumping {
            character?.position = CGPoint(x: characterX, y: characterRestY)
        } else {
            character?.position.x = characterX
        }
        if showPlatforms { updatePlatformNodes() }
    }

    // MARK: - Platforms

    private func updatePlatformNodes() {
        platformNodes.forEach { $0.removeFromParent() }
        platformNodes = []
        guard showPlatforms, size.width > 0 else { return }
        let h = scaledHeight()
        let x = characterX
        addPlatformNode(x: x, y: characterRestY + h * 0.38, width: 96)
        addPlatformNode(x: x, y: characterRestY + h * 0.75, width: 96)
    }

    private func addPlatformNode(x: CGFloat, y: CGFloat, width: CGFloat) {
        let node = SKShapeNode(rectOf: CGSize(width: width, height: 4))
        node.fillColor = UIColor(red: 0.35, green: 0.75, blue: 0.50, alpha: 0.90)
        node.strokeColor = .clear
        node.position = CGPoint(x: x, y: y)
        addChild(node)
        platformNodes.append(node)
    }

    // MARK: - Setup

    private func setupStars() {
        for _ in 0..<45 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.5))
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.3...0.8)
            star.position = CGPoint(
                x: CGFloat.random(in: 0...max(size.width, 1)),
                y: CGFloat.random(in: size.height * 0.1...size.height)
            )
            let travel = SKAction.moveBy(x: -max(size.width, 375), y: 0, duration: Double.random(in: 12...20))
            let reset  = SKAction.moveBy(x:  max(size.width, 375), y: 0, duration: 0)
            star.run(.repeatForever(.sequence([travel, reset])))
            addChild(star)
        }
    }

    private func setupGround() {
        groundNode = SKNode()
        groundNode.position = CGPoint(x: size.width / 2, y: groundY)
        let line = SKShapeNode(rectOf: CGSize(width: max(size.width, 375), height: 3))
        line.fillColor = UIColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1)
        line.strokeColor = .clear
        groundNode.addChild(line)
        addChild(groundNode)
    }

    private func setupCharacter() {
        character = SKNode()
        character.position = CGPoint(x: characterX, y: characterRestY)
        let defaultNode = RobotNode()
        defaultNode.position = CGPoint(x: 0, y: 0)
        character.addChild(defaultNode)
        characterNode = defaultNode
        addChild(character)
    }

    // MARK: - Haptics

    private func fireHaptic() {
        impactFeedback.impactOccurred()
        impactFeedback.prepare()
    }

    // MARK: - Floating param text

    private var floatingTextYBase: CGFloat { groundY + 80 }

    private func spawnFloatingLabel(_ text: String, yOffset: CGFloat = 0) {
        let label = SKLabelNode(text: text)
        label.fontSize = 11
        label.fontColor = SKColor(red: 0.85, green: 1.0, blue: 0.85, alpha: 1)
        label.fontName = "Menlo-Bold"
        label.horizontalAlignmentMode = .right
        label.alpha = 0.9
        label.position = CGPoint(x: size.width - 14, y: floatingTextYBase + yOffset)
        addChild(label)

        let rise   = SKAction.moveBy(x: 0, y: 110, duration: 1.6)
        rise.timingMode = .easeOut
        let fade   = SKAction.fadeOut(withDuration: 1.6)
        label.run(.sequence([.group([rise, fade]), .removeFromParent()]))
    }

    private func spawnPhaseLabels(_ phase: JumpPhase) -> SKAction {
        .run { [weak self] in
            guard let self, showFloatingText else { return }
            let events = phase.paramEvents(for: params)
            for (i, event) in events.enumerated() {
                spawnFloatingLabel(event.formatted, yOffset: CGFloat(i) * 22)
            }
        }
    }

    // MARK: - Jump

    private func startJump() {
        isJumping = true
        let config = JumpPhysicsConfig(params: params, scaledHeight: scaledHeight())
        let restY  = characterRestY
        let peakY  = restY + scaledHeight()
        runJumpSequence(config: config, restY: restY, peakY: peakY)
    }

    private func restartJump() {
        character.removeAllActions()
        characterNode.removeAllActions()
        character.xScale = 1
        character.yScale = 1
        character.position = CGPoint(x: characterX, y: characterRestY)
        startJump()
    }

    private func runJumpSequence(config: JumpPhysicsConfig, restY: CGFloat, peakY: CGFloat) {
        if showPlatforms {
            runPlatformSequence(config: config, restY: restY)
            return
        }

        func setPhase(_ p: JumpPhase) -> SKAction {
            .run { [weak self] in self?.characterNode.setPhase(p) }
        }
        func scaleGroup(x: CGFloat, y: CGFloat, duration: TimeInterval) -> SKAction {
            .group([.scaleX(to: x, duration: duration), .scaleY(to: y, duration: duration)])
        }
        func moveTo(y: CGFloat, duration: TimeInterval, timing: SKActionTimingMode) -> SKAction {
            let a = SKAction.moveTo(y: y, duration: duration)
            a.timingMode = timing
            return a
        }

        let frameDur: TimeInterval = 2.0 / 60.0
        let ascentDuration  = params.ascentFrames / 60.0
        let descentDuration = params.descentFrames / 60.0

        // Compute second-jump derived values up front.
        let djFactor = CGFloat(params.doubleJumpHeightFactor)
        let peak2Y = peakY + scaledHeight() * djFactor

        // Descent starts from peak2Y if double jump is active, so scale duration
        // with sqrt of the total fall-height ratio to preserve perceived speed.
        let effectiveDescentDuration: TimeInterval
        if params.features.doubleJump {
            let ratio = Double((peak2Y - restY) / scaledHeight())
            effectiveDescentDuration = descentDuration * sqrt(ratio)
        } else {
            effectiveDescentDuration = descentDuration
        }

        var steps: [SKAction] = [
            // Squat anticipation
            spawnPhaseLabels(.squat),
            setPhase(.squat),
            scaleGroup(x: config.squatScaleX, y: config.squatScaleY, duration: config.squatDuration),

            // Launch stretch — briefly widen and elongate
            spawnPhaseLabels(.ascending),
            setPhase(.ascending),
            scaleGroup(x: config.launchScaleX, y: config.launchScaleY, duration: frameDur),

            // Rise to peak: position eases out (decelerates), scale relaxes back to neutral
            SKAction.group([
                moveTo(y: peakY, duration: ascentDuration, timing: .easeOut),
                scaleGroup(x: 1, y: 1, duration: ascentDuration * 0.4)
            ]),

            // Apex float
            spawnPhaseLabels(.apex),
            setPhase(.apex),
            .wait(forDuration: config.apexDuration),
        ]

        // Double jump: mid-air compress → launch → rise to second peak → brief apex
        if params.features.doubleJump {
            let asc2Duration = max(2.0 / 60.0, ascentDuration * sqrt(Double(djFactor)))
            let squat2Dur    = max(2.0 / 60.0, config.squatDuration * 0.5)
            steps += [
                setPhase(.squat),
                scaleGroup(x: config.squatScaleX, y: config.squatScaleY, duration: squat2Dur),
                setPhase(.ascending),
                scaleGroup(x: config.launchScaleX, y: config.launchScaleY, duration: frameDur),
                SKAction.group([
                    moveTo(y: peak2Y, duration: asc2Duration, timing: .easeOut),
                    scaleGroup(x: 1, y: 1, duration: asc2Duration * 0.4)
                ]),
                setPhase(.apex),
                .wait(forDuration: config.apexDuration * 0.5),
            ]
        }

        steps += [
            // Descent: position eases in (accelerates)
            spawnPhaseLabels(.descending),
            setPhase(.descending),
            moveTo(y: restY, duration: effectiveDescentDuration, timing: .easeIn),

            // Land squash
            spawnPhaseLabels(.landing),
            setPhase(.landing),
            .run { [weak self] in self?.fireHaptic() },
            scaleGroup(x: config.landScaleX, y: config.landScaleY, duration: frameDur),

            // Recover to neutral
            scaleGroup(x: 1, y: 1, duration: config.landingDuration),
        ]

        // Rubber bounce: each bounce rises to 25% of the previous height.
        // Duration scales with sqrt(height ratio) = 0.5^i to match natural physics.
        // Squash on each landing is proportional to the bounce height ratio.
        if params.features.rubberBounce {
            let fullHeight = scaledHeight()
            let baseDeform = 1.0 - params.landScale  // how much the main landing deforms

            for i in 0..<Int(params.bounceCount) {
                let hr = CGFloat(pow(0.25, Double(i + 1)))  // 0.25, 0.0625, …
                let ds = Double(pow(0.5, Double(i + 1)))    // 0.5, 0.25, …  (sqrt of hr)
                let bounceY       = restY + fullHeight * hr
                let bAscent       = max(2.0 / 60.0, ascentDuration  * ds)
                let bDescent      = max(2.0 / 60.0, descentDuration * ds)
                let bLandingDur   = max(2.0 / 60.0, config.landingDuration * ds)
                let bSquashY      = CGFloat(1.0 - baseDeform * Double(hr))
                let bSquashX      = 1.0 / bSquashY

                steps += [
                    setPhase(.ascending),
                    moveTo(y: bounceY, duration: bAscent,  timing: .easeOut),
                    setPhase(.descending),
                    moveTo(y: restY,   duration: bDescent, timing: .easeIn),
                    setPhase(.landing),
                    .run { [weak self] in self?.fireHaptic() },
                    scaleGroup(x: bSquashX, y: bSquashY, duration: frameDur),
                    scaleGroup(x: 1,        y: 1,        duration: bLandingDur),
                ]
            }
        }

        steps += [
            // Idle and optionally loop
            setPhase(.idle),
            .run { [weak self] in
                guard let self else { return }
                self.isJumping = false
                if self.isLooping {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                        self?.startJump()
                    }
                }
            }
        ]

        character.run(.sequence(steps), withKey: "jump")
    }

    // Platform sequence: Ground → P1 (38% height) → P2 (75% height) → Ground
    // Duration of each leg scales with sqrt(height ratio) to match natural physics.
    private func runPlatformSequence(config: JumpPhysicsConfig, restY: CGFloat) {
        func setPhase(_ p: JumpPhase) -> SKAction {
            .run { [weak self] in self?.characterNode.setPhase(p) }
        }
        func scaleGroup(x: CGFloat, y: CGFloat, duration: TimeInterval) -> SKAction {
            .group([.scaleX(to: x, duration: duration), .scaleY(to: y, duration: duration)])
        }
        func moveTo(y: CGFloat, duration: TimeInterval, timing: SKActionTimingMode) -> SKAction {
            let a = SKAction.moveTo(y: y, duration: duration)
            a.timingMode = timing
            return a
        }

        let frameDur: TimeInterval = 2.0 / 60.0
        let ascentDuration  = params.ascentFrames / 60.0
        let descentDuration = params.descentFrames / 60.0
        let fullH = scaledHeight()

        let p1Y = restY + fullH * 0.38
        let p2Y = restY + fullH * 0.75

        let asc1  = max(frameDur, ascentDuration  * sqrt(0.38))  // ground → P1
        let asc2  = max(frameDur, ascentDuration  * sqrt(0.37))  // P1 → P2 (delta)
        let desc3 = max(frameDur, descentDuration * sqrt(0.75))  // P2 → ground

        var steps: [SKAction] = []

        // Leg 1: Ground → Platform 1
        steps += [
            spawnPhaseLabels(.squat),
            setPhase(.squat),
            scaleGroup(x: config.squatScaleX, y: config.squatScaleY, duration: config.squatDuration),
            spawnPhaseLabels(.ascending),
            setPhase(.ascending),
            scaleGroup(x: config.launchScaleX, y: config.launchScaleY, duration: frameDur),
            SKAction.group([
                moveTo(y: p1Y, duration: asc1, timing: .easeOut),
                scaleGroup(x: 1, y: 1, duration: asc1 * 0.4)
            ]),
            spawnPhaseLabels(.landing),
            setPhase(.landing),
            .run { [weak self] in self?.fireHaptic() },
            scaleGroup(x: config.landScaleX, y: config.landScaleY, duration: frameDur),
            scaleGroup(x: 1, y: 1, duration: config.landingDuration),
        ]

        // Leg 2: Platform 1 → Platform 2
        steps += [
            spawnPhaseLabels(.squat),
            setPhase(.squat),
            scaleGroup(x: config.squatScaleX, y: config.squatScaleY, duration: config.squatDuration),
            spawnPhaseLabels(.ascending),
            setPhase(.ascending),
            scaleGroup(x: config.launchScaleX, y: config.launchScaleY, duration: frameDur),
            SKAction.group([
                moveTo(y: p2Y, duration: asc2, timing: .easeOut),
                scaleGroup(x: 1, y: 1, duration: asc2 * 0.4)
            ]),
            spawnPhaseLabels(.landing),
            setPhase(.landing),
            .run { [weak self] in self?.fireHaptic() },
            scaleGroup(x: config.landScaleX, y: config.landScaleY, duration: frameDur),
            scaleGroup(x: 1, y: 1, duration: config.landingDuration),
        ]

        // Leg 3: Platform 2 → Ground (fall)
        steps += [
            spawnPhaseLabels(.descending),
            setPhase(.descending),
            moveTo(y: restY, duration: desc3, timing: .easeIn),
            spawnPhaseLabels(.landing),
            setPhase(.landing),
            .run { [weak self] in self?.fireHaptic() },
            scaleGroup(x: config.landScaleX, y: config.landScaleY, duration: frameDur),
            scaleGroup(x: 1, y: 1, duration: config.landingDuration),
        ]

        steps += [
            setPhase(.idle),
            .run { [weak self] in
                guard let self else { return }
                self.isJumping = false
                if self.isLooping {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                        self?.startJump()
                    }
                }
            }
        ]

        character.run(.sequence(steps), withKey: "jump")
    }
}
