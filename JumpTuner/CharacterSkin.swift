// CharacterSkin.swift
// Protocol + registry for swappable jump characters.

import SpriteKit

/// An SKNode subclass that knows how to animate itself per jump phase.
protocol CharacterNode: SKNode {
    func setPhase(_ phase: JumpPhase, duration: TimeInterval)
}

extension CharacterNode {
    func setPhase(_ phase: JumpPhase) { setPhase(phase, duration: 0.08) }
}

/// Describes one swappable character skin.
struct CharacterSkin: Identifiable {
    let id: String
    let name: String
    let make: () -> any CharacterNode

    static let builtIn: [CharacterSkin] = [.robot, .rabbit, .pirate]

    static let robot  = CharacterSkin(id: "robot",  name: "Robot",  make: RobotNode.init)
    static let rabbit = CharacterSkin(id: "rabbit", name: "Rabbit", make: RabbitNode.init)
    static let pirate = CharacterSkin(id: "pirate", name: "Pirate", make: PirateNode.init)

    /// Playground-generated image → simple single-sprite with tilt.
    static func generated(image: UIImage, name: String) -> CharacterSkin {
        CharacterSkin(id: "gen-\(UUID().uuidString)", name: name) {
            GeneratedCharacterNode(image: image)
        }
    }

    /// Raw photo → segmented skeletal puppet via Vision (BodyPoseProcessor).
    static func fromPhoto(image: UIImage, name: String) -> CharacterSkin {
        CharacterSkin(id: "photo-\(UUID().uuidString)", name: name) {
            SkeletalCharacterNode(image: image)
        }
    }
}
