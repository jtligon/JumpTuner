// JumpScene.swift
// SpriteKit scene: character physics, ground collision, jump cycle.

import SpriteKit

final class JumpScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Physics categories

    private static let characterMask: UInt32 = 1 << 0
    private static let groundMask:    UInt32 = 1 << 1

    // MARK: - Nodes

    // Invisible physics carrier — the active CharacterNode is its child.
    private var character: SKNode!
    private var characterNode: (any CharacterNode)!
    private var groundNode: SKNode!

    // MARK: - State

    var params: JumpParams = .defaults { didSet { configDidChange() } }
    var isLooping: Bool = false

    private var config: JumpPhysicsConfig = JumpPhysicsConfig(params: .defaults, scaledHeight: 300)
    private var phase: JumpPhase = .idle
    private var isOnGround: Bool = true
    private var groundY: CGFloat = 0
    private let characterSize = CGSize(width: 36, height: 48)

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
        character.removeAllActions()
        phase = .idle
        isLooping = false
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        character.position = CGPoint(x: characterX, y: characterRestY)
        character.physicsBody?.velocity = .zero
        character.xScale = 1
        character.yScale = 1
        characterNode.setPhase(.idle)
    }

    func setCharacter(_ skin: CharacterSkin) {
        characterNode?.removeFromParent()
        let newNode = skin.make()
        newNode.position = CGPoint(x: 0, y: -characterSize.height / 2)
        character.addChild(newNode)
        characterNode = newNode
        characterNode.setPhase(phase)
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
            let travel = SKAction.moveBy(x: -max(size.width, 375), y: 0, duration: Double.random(in: 12...20))
            let reset  = SKAction.moveBy(x:  max(size.width, 375), y: 0, duration: 0)
            star.run(.repeatForever(.sequence([travel, reset])))
            addChild(star)
        }
    }

    private func setupGround() {
        groundY = 36
        groundNode = SKNode()
        groundNode.position = CGPoint(x: size.width / 2, y: groundY)

        // Ground body is 8 pts tall so the character rests clearly on top of it.
        let body = SKPhysicsBody(rectangleOf: CGSize(width: max(size.width * 2, 750), height: 8))
        body.isDynamic = false
        body.categoryBitMask    = Self.groundMask
        body.contactTestBitMask = Self.characterMask
        body.collisionBitMask   = Self.characterMask
        groundNode.physicsBody = body

        let line = SKShapeNode(rectOf: CGSize(width: max(size.width, 375), height: 3))
        line.fillColor = UIColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1)
        line.strokeColor = .clear
        groundNode.addChild(line)

        addChild(groundNode)
    }

    private func setupCharacter() {
        // Physics carrier — invisible, sized to match the robot body (not the full 48pt height
        // including antenna, which shouldn't collide).
        character = SKNode()
        // Start character with its bottom 2 pts above the ground body top so the
        // physics engine doesn't apply a collision-resolution impulse at scene start
        // (which would cause the character to drift upward indefinitely under zero gravity).
        let groundBodyHalfH: CGFloat = 4   // half of the 8-pt ground body
        character.position = CGPoint(x: characterX,
                                     y: groundY + groundBodyHalfH + characterSize.height / 2 + 2)

        let body = SKPhysicsBody(rectangleOf: characterSize)
        body.isDynamic                  = true
        body.allowsRotation             = false
        body.restitution                = 0
        body.friction                   = 0
        body.linearDamping              = 0
        body.angularDamping             = 0
        body.usesPreciseCollisionDetection = true   // prevent tunneling on fast descent
        body.categoryBitMask            = Self.characterMask
        body.contactTestBitMask         = Self.groundMask
        body.collisionBitMask           = Self.groundMask
        character.physicsBody           = body

        // Character visual: feet at y=0 in character-local → offset so feet sit on ground line.
        let defaultNode = RobotNode()
        defaultNode.position = CGPoint(x: 0, y: -characterSize.height / 2)
        character.addChild(defaultNode)
        characterNode = defaultNode

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
            character?.position = CGPoint(x: characterX, y: characterRestY)
        } else {
            character?.position.x = characterX
        }
    }

    private var characterX: CGFloat { size.width * 0.3 }
    private var characterRestY: CGFloat { groundY + 4 + characterSize.height / 2 + 2 }

    // MARK: - Jump cycle

    private func startJump() {
        guard let body = character.physicsBody else { return }
        phase = .squat
        characterNode.setPhase(.squat)

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
            self.characterNode.setPhase(.ascending)
        }
    }

    private func restartJump() {
        character.removeAllActions()
        character.xScale = 1
        character.yScale = 1
        character.physicsBody?.velocity = .zero
        character.position = CGPoint(x: characterX, y: characterRestY)
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
                characterNode.setPhase(.apex)
                if config.apexDuration > 0 {
                    physicsWorld.gravity = CGVector(dx: 0, dy: -config.apexGravity)
                    // Run on character (not scene) so removeAllActions() in restartJump
                    // cancels this too, preventing a stale transition from corrupting phase.
                    let apexWait = SKAction.sequence([
                        .wait(forDuration: config.apexDuration),
                        .run { [weak self] in
                            guard let self, self.phase == .apex else { return }
                            self.phase = .descending
                            self.characterNode.setPhase(.descending)
                        }
                    ])
                    character.run(apexWait, withKey: "apexWait")
                } else {
                    phase = .descending
                    characterNode.setPhase(.descending)
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
        guard phase == .descending || phase == .apex else { return }

        isOnGround = true
        phase = .landing
        characterNode.setPhase(.landing)
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
            self.characterNode.setPhase(.idle)
            if self.isLooping {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self.startJump()
                }
            }
        }
    }
}
