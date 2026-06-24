// JumpScene.swift
// SpriteKit scene: character physics, ground collision, jump cycle.

import SpriteKit

final class JumpScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Physics categories

    private static let characterMask: UInt32 = 1 << 0
    private static let groundMask:    UInt32 = 1 << 1

    // MARK: - Nodes

    private var character: SKSpriteNode!
    private var groundNode: SKNode!

    // MARK: - State

    var params: JumpParams = .defaults { didSet { configDidChange() } }
    var isLooping: Bool = false

    private var config: JumpPhysicsConfig = JumpPhysicsConfig(params: .defaults, scaledHeight: 300)
    private var phase: JumpPhase = .idle
    private var isOnGround: Bool = true
    private var groundY: CGFloat = 0
    private let characterSize = CGSize(width: 44, height: 44)
    private let groundHeight: CGFloat = 3

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1)
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)

        setupStars()
        setupGround()
        setupCharacter()
        recomputeConfig()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        recomputeConfig()
        repositionNodes()
    }

    // MARK: - Public interface

    func triggerJump() {
        guard phase == .idle else {
            restartJump()
            return
        }
        startJump()
    }

    func stopJumping() {
        phase = .idle
        isLooping = false
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        character?.position = CGPoint(x: characterX, y: groundY + characterSize.height / 2)
        character?.physicsBody?.velocity = .zero
        character?.setScale(1)
    }

    // MARK: - Setup helpers

    private func setupStars() {
        let starCount = 45
        for _ in 0..<starCount {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.5))
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.3...0.8)
            star.position = CGPoint(
                x: CGFloat.random(in: 0...max(size.width, 1)),
                y: CGFloat.random(in: size.height * 0.1...size.height)
            )
            // Slow right-to-left scroll via a repeating action
            let travel = SKAction.moveBy(x: -max(size.width, 375), y: 0, duration: Double.random(in: 12...20))
            let reset  = SKAction.moveBy(x:  max(size.width, 375), y: 0, duration: 0)
            star.run(.repeatForever(.sequence([travel, reset])))
            addChild(star)
        }
    }

    private func setupGround() {
        groundY = 31   // ground line y position
        groundNode = SKNode()
        groundNode.position = CGPoint(x: size.width / 2, y: groundY)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: max(size.width * 2, 750), height: 4))
        body.isDynamic = false
        body.categoryBitMask    = Self.groundMask
        body.contactTestBitMask = Self.characterMask
        body.collisionBitMask   = Self.characterMask
        groundNode.physicsBody = body

        // Visual ground line
        let line = SKShapeNode(rectOf: CGSize(width: max(size.width, 375), height: 3))
        line.fillColor = UIColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1)
        line.strokeColor = .clear
        groundNode.addChild(line)

        addChild(groundNode)
    }

    private func setupCharacter() {
        character = SKSpriteNode(color: UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1), size: characterSize)
        character.position = CGPoint(x: characterX, y: groundY + characterSize.height / 2)

        let body = SKPhysicsBody(rectangleOf: characterSize)
        body.isDynamic            = true
        body.allowsRotation       = false
        body.restitution          = 0
        body.friction             = 0
        body.linearDamping        = 0
        body.angularDamping       = 0
        body.categoryBitMask      = Self.characterMask
        body.contactTestBitMask   = Self.groundMask
        body.collisionBitMask     = Self.groundMask
        character.physicsBody     = body

        addChild(character)
    }

    // MARK: - Config

    private func recomputeConfig() {
        let groundClearance: CGFloat = 60
        let maxPixels = max(size.height - groundClearance, 100)
        let scaledHeight = CGFloat(params.jumpHeight / 500.0) * maxPixels
        config = JumpPhysicsConfig(params: params, scaledHeight: scaledHeight)
    }

    private func configDidChange() {
        recomputeConfig()
        if phase != .idle { restartJump() }
    }

    private func repositionNodes() {
        groundNode?.position = CGPoint(x: size.width / 2, y: groundY)
        if phase == .idle {
            character?.position = CGPoint(x: characterX, y: groundY + characterSize.height / 2)
        } else {
            character?.position.x = characterX
        }
    }

    private var characterX: CGFloat { size.width * 0.3 }

    // MARK: - Jump cycle

    private func startJump() {
        guard let body = character.physicsBody else { return }
        phase = .squat

        let squatAction = SKAction.group([
            SKAction.scaleX(to: config.squatScaleX, duration: config.squatDuration),
            SKAction.scaleY(to: config.squatScaleY, duration: config.squatDuration)
        ])
        let launchAction = SKAction.group([
            SKAction.scaleX(to: config.launchScaleX, duration: 2.0/60.0),
            SKAction.scaleY(to: config.launchScaleY, duration: 2.0/60.0)
        ])

        character.run(.sequence([squatAction, launchAction])) { [weak self] in
            guard let self else { return }
            body.velocity = CGVector(dx: 0, dy: self.config.jumpImpulse)
            self.phase = .ascending
        }
    }

    private func restartJump() {
        character.removeAllActions()
        character.setScale(1)
        character.physicsBody?.velocity = .zero
        character.position = CGPoint(x: characterX, y: groundY + characterSize.height / 2)
        phase = .idle
        isOnGround = true
        startJump()
    }

    // MARK: - Per-frame update (gravity switching)

    override func update(_ currentTime: TimeInterval) {
        guard let body = character.physicsBody, phase != .idle, phase != .squat else { return }

        let vy = body.velocity.dy

        switch phase {
        case .ascending:
            physicsWorld.gravity = CGVector(dx: 0, dy: -config.ascentGravity)
            if vy <= 0 {
                phase = .apex
                if config.apexDuration > 0 {
                    physicsWorld.gravity = CGVector(dx: 0, dy: -config.apexGravity)
                    run(.sequence([.wait(forDuration: config.apexDuration)])) { [weak self] in
                        self?.phase = .descending
                    }
                } else {
                    phase = .descending
                }
            }
        case .apex:
            physicsWorld.gravity = CGVector(dx: 0, dy: -config.apexGravity)
        case .descending:
            physicsWorld.gravity = CGVector(dx: 0, dy: -config.descentGravity)
        default:
            break
        }
    }

    // MARK: - Contact (landing)

    func didBegin(_ contact: SKPhysicsContact) {
        let masks = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        guard masks == (Self.characterMask | Self.groundMask) else { return }
        guard phase == .descending else { return }

        isOnGround = true
        phase = .landing
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        character.physicsBody?.velocity = .zero

        let squash = SKAction.group([
            SKAction.scaleX(to: config.landScaleX, duration: 2.0/60.0),
            SKAction.scaleY(to: config.landScaleY, duration: 2.0/60.0)
        ])
        let recover = SKAction.group([
            SKAction.scaleX(to: 1, duration: config.landingDuration),
            SKAction.scaleY(to: 1, duration: config.landingDuration)
        ])

        character.run(.sequence([squash, recover])) { [weak self] in
            guard let self else { return }
            self.phase = .idle
            if self.isLooping {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self.startJump()
                }
            }
        }
    }
}

// MARK: - Jump phase

private enum JumpPhase: Equatable {
    case idle, squat, ascending, apex, descending, landing
}
