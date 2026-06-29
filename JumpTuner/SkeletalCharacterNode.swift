// SkeletalCharacterNode.swift
// Photo-based character with three-part puppet rig (head / torso / legs).
//
// On creation, shows a full-image sprite immediately as a fallback.
// BodyPoseProcessor runs async in the background; when it finishes, the
// node upgrades to a three-part hierarchy with per-phase expressive motion.
// If no person is detected, the node upgrades to the clean segmented cutout
// but keeps the single-sprite tilt behaviour.

import SpriteKit
import UIKit

final class SkeletalCharacterNode: SKNode, CharacterNode {

    private static let displayHeight: CGFloat = 52

    private var fallback:  SKSpriteNode
    private var headNode:  SKSpriteNode?
    private var torsoNode: SKSpriteNode?
    private var legsNode:  SKSpriteNode?
    private var headBaseY: CGFloat = 0
    private var currentPhase: JumpPhase = .idle

    init(image: UIImage) {
        let scale   = Self.displayHeight / max(image.size.height, 1)
        let texture = SKTexture(image: image)
        fallback = SKSpriteNode(texture: texture, color: .clear,
                                size: CGSize(width: image.size.width * scale,
                                             height: Self.displayHeight))
        fallback.anchorPoint = CGPoint(x: 0.5, y: 0)
        super.init()
        addChild(fallback)

        // Pulse while Vision is running so the user knows something is happening.
        fallback.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.4, duration: 0.7),
            .fadeAlpha(to: 1.0, duration: 0.7)
        ])), withKey: "loading")

        Task { [weak self] in
            guard let self else { return }
            let segments = await BodyPoseProcessor.process(image)
            await MainActor.run { [weak self] in
                self?.buildSkeleton(segments)
            }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func setPhase(_ phase: JumpPhase, duration: TimeInterval = 0.08) {
        currentPhase = phase
        if headNode == nil {
            // Fallback: tilt the full-image sprite to hint at motion
            let tilt: CGFloat
            switch phase {
            case .ascending:  tilt = -0.12
            case .descending: tilt =  0.10
            default:          tilt =  0.00
            }
            fallback.run(.rotate(toAngle: tilt, duration: duration, shortestUnitArc: true))
        } else {
            animateParts(phase: phase, duration: duration)
        }
    }

    // MARK: - Skeleton upgrade (called once on Main after Vision completes)

    private func buildSkeleton(_ segments: BodySegments) {
        // Vision is done — stop the loading pulse.
        fallback.removeAction(forKey: "loading")
        fallback.alpha = 1

        guard segments.hasSkeleton,
              let head  = segments.head,
              let torso = segments.torso,
              let legs  = segments.legs else {
            // Upgrade to the clean cutout but keep single-sprite behaviour
            let s = Self.displayHeight / max(segments.cutout.size.height, 1)
            fallback.texture = SKTexture(image: segments.cutout)
            fallback.size = CGSize(width: segments.cutout.size.width * s,
                                   height: Self.displayHeight)
            return
        }

        let scale   = Self.displayHeight / max(segments.cutout.size.height, 1)
        // Each adjacent pair of crops shares `overlap` pixels to hide the seam.
        let overlap = CGFloat(6) * scale

        func makeSprite(_ img: UIImage) -> SKSpriteNode {
            let node = SKSpriteNode(
                texture: SKTexture(image: img), color: .clear,
                size: CGSize(width: img.size.width * scale, height: img.size.height * scale))
            node.anchorPoint = CGPoint(x: 0.5, y: 0)  // pivot at bottom-centre
            return node
        }

        let lNode = makeSprite(legs)
        let tNode = makeSprite(torso)
        let hNode = makeSprite(head)

        lNode.position = CGPoint(x: 0, y: 0)
        tNode.position = CGPoint(x: 0, y: lNode.size.height - overlap)
        hNode.position = CGPoint(x: 0, y: lNode.size.height + tNode.size.height - 2 * overlap)
        headBaseY      = hNode.position.y

        fallback.removeFromParent()
        // Add legs first so head renders above torso, torso above legs.
        addChild(lNode)
        addChild(tNode)
        addChild(hNode)
        legsNode  = lNode
        torsoNode = tNode
        headNode  = hNode

        // Snap to whatever phase is currently active (duration 0 = no tween).
        animateParts(phase: currentPhase, duration: 0)
    }

    // MARK: - Per-phase expressive motion

    private func animateParts(phase: JumpPhase, duration: TimeInterval) {
        guard let h = headNode, let t = torsoNode, let l = legsNode else { return }

        // All angles in radians; positive = clockwise in SpriteKit (y-up).
        // headDY is added to headBaseY; the parent character node already
        // handles squash/stretch so these offsets add expressiveness only.
        let torsoAngle: CGFloat
        let headAngle:  CGFloat
        let headDY:     CGFloat
        let legAngle:   CGFloat

        switch phase {
        case .idle:
            torsoAngle =  0.00; headAngle =  0.00; headDY =  0; legAngle =  0.00
        case .squat:
            torsoAngle =  0.12; headAngle = -0.06; headDY = -2; legAngle =  0.00
        case .ascending:
            torsoAngle = -0.15; headAngle = -0.10; headDY =  3; legAngle = -0.08
        case .apex:
            torsoAngle =  0.00; headAngle =  0.00; headDY =  0; legAngle =  0.00
        case .descending:
            torsoAngle =  0.08; headAngle =  0.05; headDY = -1; legAngle =  0.10
        case .landing:
            torsoAngle =  0.18; headAngle = -0.08; headDY = -3; legAngle =  0.00
        }

        // Use named keys so rapid phase changes cancel the in-flight tween.
        t.run(.rotate(toAngle: torsoAngle, duration: duration, shortestUnitArc: true), withKey: "rot")
        h.run(.rotate(toAngle: headAngle,  duration: duration, shortestUnitArc: true), withKey: "rot")
        h.run(.moveTo(y: headBaseY + headDY,  duration: duration), withKey: "pos")
        l.run(.rotate(toAngle: legAngle,   duration: duration, shortestUnitArc: true), withKey: "rot")
    }
}
