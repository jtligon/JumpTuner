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

    var params: JumpParams = .defaults { didSet { if isJumping { restartJump() } } }
    var isLooping: Bool = false

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

        var steps: [SKAction] = [
            // Squat anticipation
            setPhase(.squat),
            scaleGroup(x: config.squatScaleX, y: config.squatScaleY, duration: config.squatDuration),

            // Launch stretch — briefly widen and elongate
            setPhase(.ascending),
            scaleGroup(x: config.launchScaleX, y: config.launchScaleY, duration: frameDur),

            // Rise to peak: position eases out (decelerates), scale relaxes back to neutral
            SKAction.group([
                moveTo(y: peakY, duration: ascentDuration, timing: .easeOut),
                scaleGroup(x: 1, y: 1, duration: ascentDuration * 0.4)
            ]),

            // Apex float
            setPhase(.apex),
            .wait(forDuration: config.apexDuration),

            // Descent: position eases in (accelerates)
            setPhase(.descending),
            moveTo(y: restY, duration: descentDuration, timing: .easeIn),

            // Land squash
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
}
