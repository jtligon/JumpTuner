// FloatingParamEvent.swift
// Data model for the floating combat-text labels emitted at each jump phase.

import CoreGraphics
import Foundation

// MARK: - FloatingParamEvent

/// A single parameter:value pair to display as floating combat text.
struct FloatingParamEvent: Equatable {
    let name: String
    let value: String

    var formatted: String { "\(name): \(value)" }
}

// MARK: - JumpPhase extension

extension JumpPhase {
    /// Returns the parameter events to display when this phase begins.
    func paramEvents(for params: JumpParams) -> [FloatingParamEvent] {
        switch self {
        case .idle:
            return []
        case .squat:
            return [.init(name: "squat",   value: "\(Int(params.squatFrames))f")]
        case .ascending:
            return [.init(name: "ascent",  value: "\(Int(params.ascentFrames))f")]
        case .apex:
            var events = [FloatingParamEvent(name: "apex", value: "\(Int(params.apexFrames))f")]
            if params.features.floating {
                events.append(.init(name: "float", value: "\(Int(params.floatFrames))f"))
            }
            return events
        case .descending:
            return [.init(name: "descent", value: "\(Int(params.descentFrames))f")]
        case .landing:
            return [.init(name: "land",    value: "\(Int(params.landingFrames))f")]
        }
    }
}

// MARK: - Layout

/// Placement rules for the floating labels shown during a jump.
enum FloatingTextLayout {
    /// Labels closer together vertically than this would collide.
    static let lineHeight: CGFloat = 16
    static let columnGap: CGFloat = 12
    /// Keeps labels clear of the status bar on very high jumps.
    static let topMargin: CGFloat = 70
    /// How far a label that starts at the top of the jump keeps drifting up.
    static let peakDrift: CGFloat = 60
    /// How close to the screen top a drifting label may get.
    static let driftTopMargin: CGFloat = 40

    /// Where a label finishes: at the top of the jump, or, if it started
    /// there, a little above it.
    static func riseTarget(fromY y: CGFloat, ceiling: CGFloat, screenHeight: CGFloat) -> CGFloat {
        guard y >= ceiling - 1 else { return ceiling }
        return max(y, min(y + peakDrift, screenHeight - driftTopMargin))
    }

    /// Right edge for a new label, shifted left of any label already on its line.
    static func rightEdge(forLabelAt y: CGFloat, screenRight: CGFloat, existing: [CGRect]) -> CGFloat {
        let sameLine = existing.filter { abs($0.midY - y) < lineHeight }
        guard let leftmost = sameLine.map(\.minX).min() else { return screenRight }
        return min(screenRight, leftmost - columnGap)
    }

    /// Height where labels stop: level with the middle of the sprite at its peak.
    static func ceiling(peakY: CGFloat, spriteHeight: CGFloat, screenHeight: CGFloat) -> CGFloat {
        min(peakY + spriteHeight / 2, screenHeight - topMargin)
    }
}
