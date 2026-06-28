// GeneratedCharacterNode.swift
// CharacterNode backed by a UIImage from Apple Intelligence / Image Playground.
// Phase animations are handled via the parent physics carrier's squash/stretch
// (inherited from JumpScene). This node adds a subtle tilt per phase.

import SpriteKit
import UIKit

final class GeneratedCharacterNode: SKNode, CharacterNode {

    private let sprite: SKSpriteNode

    // Display size — tall enough to feel like a character, keeping image aspect ratio.
    private static let displayHeight: CGFloat = 52

    init(image: UIImage) {
        let texture = SKTexture(image: image)
        let aspect  = texture.size().width / texture.size().height
        let size    = CGSize(width: Self.displayHeight * aspect,
                            height: Self.displayHeight)
        sprite = SKSpriteNode(texture: texture, size: size)
        super.init()

        // Feet at y=0 — sprite anchor is centre by default, so shift up by half height.
        sprite.position = CGPoint(x: 0, y: size.height / 2)
        addChild(sprite)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - CharacterNode

    func setPhase(_ phase: JumpPhase, duration: TimeInterval = 0.08) {
        // Generated art doesn't have separate limbs to animate, so we do a
        // slight tilt to convey direction without breaking the image.
        let tilt: CGFloat
        switch phase {
        case .squat:              tilt =  0.0
        case .ascending:          tilt = -0.12   // lean forward (CCW in SpriteKit)
        case .apex:               tilt =  0.0
        case .descending:         tilt =  0.10   // lean back slightly
        case .landing, .idle:     tilt =  0.0
        }
        sprite.run(.rotate(toAngle: tilt, duration: duration, shortestUnitArc: true))
    }
}
