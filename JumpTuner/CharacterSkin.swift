// CharacterSkin.swift
// Protocol + registry for swappable jump characters.

import SpriteKit

/// An SKNode subclass that knows how to animate itself per jump phase.
protocol CharacterNode: SKNode {
    func setPhase(_ phase: JumpPhase, duration: TimeInterval)
    /// Starts or stops the character's run animation. Must be safe to call every frame.
    func setRunning(_ running: Bool)
}

extension CharacterNode {
    func setPhase(_ phase: JumpPhase) { setPhase(phase, duration: 0.08) }
    /// Characters without a run animation keep their standing pose.
    func setRunning(_ running: Bool) {}
}

/// Describes one swappable character skin.
struct CharacterSkin: Identifiable {
    let id: String
    let name: String
    let make: () -> any CharacterNode

    /// Renders the character's standing pose for use as a picker icon.
    func makeThumbnail() -> UIImage? {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        guard let texture = view.texture(from: make()) else { return nil }
        return UIImage(cgImage: texture.cgImage())
    }

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

    /// On-device Stable Diffusion sprites — one generated texture per JumpPhase.
    /// Falls back to `fallbackImage` tilt behaviour while generation is in progress.
    static func diffusion(phaseTextures: [JumpPhase: SKTexture],
                          fallbackImage: UIImage,
                          name: String) -> CharacterSkin {
        CharacterSkin(id: "diff-\(UUID().uuidString)", name: name) {
            let node = DiffusionCharacterNode(fallbackImage: fallbackImage)
            if !phaseTextures.isEmpty {
                node.applyTextures(phaseTextures)
            }
            return node
        }
    }
}
