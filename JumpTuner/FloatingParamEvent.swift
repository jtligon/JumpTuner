// FloatingParamEvent.swift
// Data model for the floating combat-text labels emitted at each jump phase.

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
