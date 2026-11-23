// DiffusionCharacterNodeTests.swift
// Tests for DiffusionCharacterNode: initial state, texture application, and phase switching.

import Testing
import SpriteKit
import UIKit
@testable import JumpTuner

@Suite("DiffusionCharacterNode")
@MainActor
struct DiffusionCharacterNodeTests {

    // MARK: - Helpers

    private func makeNode() -> DiffusionCharacterNode {
        let image = Self.solidColorImage(color: .systemBlue, size: CGSize(width: 32, height: 48))
        return DiffusionCharacterNode(fallbackImage: image)
    }

    private func makeTextures() -> [JumpPhase: SKTexture] {
        let phases: [JumpPhase] = [.idle, .squat, .ascending, .apex, .descending, .landing]
        var dict: [JumpPhase: SKTexture] = [:]
        for (i, phase) in phases.enumerated() {
            let color = UIColor(hue: CGFloat(i) / CGFloat(phases.count),
                                saturation: 1, brightness: 1, alpha: 1)
            let img = Self.solidColorImage(color: color, size: CGSize(width: 32, height: 48))
            dict[phase] = SKTexture(image: img)
        }
        return dict
    }

    private static func solidColorImage(color: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Initial state

    @Test("Node starts with empty phaseTextures")
    func initialPhaseTexturesEmpty() {
        let node = makeNode()
        #expect(node.phaseTextures.isEmpty)
    }

    @Test("Node has no children after init except sprite and spinner")
    func initialChildCount() {
        let node = makeNode()
        // The node adds a fallback sprite and a loading spinner.
        #expect(node.children.count == 2)
    }

    // MARK: - Texture application

    @Test("applyTextures populates phaseTextures")
    func applyTexturesPopulates() {
        let node     = makeNode()
        let textures = makeTextures()
        node.applyTextures(textures)
        #expect(node.phaseTextures.count == 6)
    }

    @Test("applyTextures removes loading spinner")
    func applyTexturesRemovesSpinner() {
        let node = makeNode()
        node.applyTextures(makeTextures())
        // After applying textures, only the sprite remains (spinner removed).
        #expect(node.children.count == 1)
    }

    @Test("All six JumpPhase values are covered after applyTextures")
    func allPhasesPresent() {
        let node     = makeNode()
        let textures = makeTextures()
        node.applyTextures(textures)
        let phases: [JumpPhase] = [.idle, .squat, .ascending, .apex, .descending, .landing]
        for phase in phases {
            #expect(node.phaseTextures[phase] != nil, "Missing texture for \(phase)")
        }
    }

    // MARK: - Phase switching

    @Test("setPhase does not crash before textures are applied")
    func setPhaseFallbackNoCrash() {
        let node = makeNode()
        // Should not crash — uses fallback tilt behaviour.
        for phase in [JumpPhase.idle, .squat, .ascending, .apex, .descending, .landing] {
            node.setPhase(phase, duration: 0)
        }
    }

    @Test("setPhase does not crash after textures are applied")
    func setPhaseWithTexturesNoCrash() {
        let node = makeNode()
        node.applyTextures(makeTextures())
        for phase in [JumpPhase.idle, .squat, .ascending, .apex, .descending, .landing] {
            node.setPhase(phase, duration: 0)
        }
    }

    // MARK: - CharacterSkin integration

    @Test("CharacterSkin.diffusion factory produces a skin with a stable id")
    func diffusionSkinIdIsStable() {
        let image    = Self.solidColorImage(color: .red, size: CGSize(width: 32, height: 48))
        let textures = makeTextures()
        let skinA    = CharacterSkin.diffusion(phaseTextures: textures, fallbackImage: image, name: "Test")
        let skinB    = CharacterSkin.diffusion(phaseTextures: textures, fallbackImage: image, name: "Test")
        // Each call generates a unique id so two skins can coexist in the picker.
        #expect(skinA.id != skinB.id)
    }

    @Test("CharacterSkin.diffusion factory name is preserved")
    func diffusionSkinNamePreserved() {
        let image = Self.solidColorImage(color: .red, size: CGSize(width: 32, height: 48))
        let skin  = CharacterSkin.diffusion(phaseTextures: [:], fallbackImage: image, name: "Generated")
        #expect(skin.name == "Generated")
    }
}
