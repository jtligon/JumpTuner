// Models.swift
//
// Core data structures for JumpTuner. These are the single source of truth
// for all jump parameters — the UI reads from them, the animation engine
// consumes them, and the persistence layer serializes them.

import Foundation

// MARK: - JumpFeatures

/// Boolean toggles for the five "game feel" tricks that make platformer
/// jumping feel responsive beyond raw physics values.
///
/// Each feature is independent and can be combined freely.
struct JumpFeatures: Codable, Equatable {

    /// Allows the player to jump for a few frames after walking off a ledge.
    /// Prevents the frustrating "I pressed jump but I was one pixel past the edge"
    /// failure mode. Named after the Wile E. Coyote effect.
    var coyoteTime: Bool = true

    /// Queues a jump input if the player presses jump just before landing.
    /// The jump fires automatically on the next ground contact, making
    /// rapid repeated jumping feel snappy rather than requiring precise timing.
    var jumpBuffer: Bool = true

    /// Releasing the jump button early cuts upward velocity, producing a
    /// shorter arc. Holding it through the apex yields full height.
    /// Essential for skill-expressive platformers.
    var variableJump: Bool = true

    /// Applies a gravity multiplier on the way down, making descent faster
    /// than ascent. Produces a more satisfying, weighty arc.
    /// Controlled by `JumpParams.fallMult`.
    var asymGrav: Bool = true

    /// Temporarily reduces gravity at the jump apex, producing a brief
    /// "float" that gives players more control at the highest point.
    /// Controlled by `JumpParams.apexGravFactor`.
    var apexGrav: Bool = true
}

// MARK: - JumpParams

/// The complete set of tunable parameters for one jump cycle.
///
/// All timing values are in **frames** at 60 fps. The animation engine
/// converts to seconds internally (`frames / 60.0`).
///
/// Height is a normalized value on a 0–500 scale that the preview engine
/// maps to actual screen pixels proportionally, so the same preset looks
/// correct on any device size.
///
/// ## Sharing presets
/// Call `encoded()` to get a compact JSON string suitable for embedding in
/// a QR code. Reconstruct with `JumpParams.decoded(from:)`.
struct JumpParams: Codable, Equatable {

    // MARK: Timing

    /// Frames the character crouches before launching.
    /// Adds anticipation and telegraphs the jump. Range: 0–10.
    var squatFrames: Double = 3

    /// Frames spent rising to the apex. Longer = floatier.
    /// Range: 4–30.
    var ascentFrames: Double = 11

    /// Frames spent hovering at the peak before gravity takes over.
    /// Even 1–2 frames makes the apex feel more controlled.
    /// Range: 0–8.
    var apexFrames: Double = 2

    /// Frames spent falling back to the ground.
    /// Should typically be shorter than `ascentFrames` when `asymGrav`
    /// is enabled — the multiplier handles the speed difference.
    /// Range: 4–30.
    var descentFrames: Double = 8

    /// Frames of the squash/impact pose on landing.
    /// Range: 1–10.
    var landingFrames: Double = 3

    // MARK: Height

    /// Normalized jump height on a 0–500 scale.
    /// The preview engine maps this to screen pixels:
    /// `pixelHeight = (jumpHeight / 500) * (screenHeight - groundClearance)`
    var jumpHeight: Double = 60

    // MARK: Squash & stretch

    /// Vertical scale during the squat phase. Values below 1.0 compress
    /// the character downward. The horizontal axis is inverse-scaled to
    /// preserve volume. Range: 0.5–1.0.
    var squatScale: Double = 0.70

    /// Vertical stretch on launch. Values above 1.0 elongate the character
    /// upward. Horizontal axis is inverse-scaled. Range: 1.0–2.0.
    var launchScale: Double = 1.40

    /// Vertical compression on landing impact. Range: 0.3–1.0.
    var landScale: Double = 0.55

    // MARK: Feel tweaks

    /// How many frames after leaving a ledge the player can still jump.
    /// Requires `features.coyoteTime` to be enabled. Range: 1–10.
    var coyoteFrames: Double = 5

    /// How many frames before landing a jump input is remembered.
    /// Requires `features.jumpBuffer` to be enabled. Range: 1–10.
    var bufferFrames: Double = 4

    /// Gravity multiplier applied during descent.
    /// `pow(t, 1 / fallMult)` warps the descent easing curve so that
    /// higher values produce faster, more aggressive falls.
    /// Requires `features.asymGrav`. Range: 1.0–3.0.
    var fallMult: Double = 1.6

    /// Fraction of normal gravity applied at the apex float phase.
    /// 0.1 = almost no gravity (very floaty); 1.0 = full gravity (no effect).
    /// Requires `features.apexGrav`. Range: 0.1–1.0.
    var apexGravFactor: Double = 0.40

    /// The five boolean feel toggles.
    var features: JumpFeatures = JumpFeatures()

    // MARK: Presets

    /// A `JumpParams` initialized with all default values.
    /// Used by the reset button.
    static let defaults = JumpParams()

    /// Generates a randomized `JumpParams` within sane ranges.
    /// All values are chosen so the result is a valid (if eccentric) jump.
    static func randomized() -> JumpParams {
        JumpParams(
            squatFrames:    Double(Int.random(in: 0...8)),
            ascentFrames:   Double(Int.random(in: 5...25)),
            apexFrames:     Double(Int.random(in: 0...6)),
            descentFrames:  Double(Int.random(in: 4...20)),
            landingFrames:  Double(Int.random(in: 1...8)),
            jumpHeight:     Double(Int.random(in: 20...400)),
            squatScale:     Double(Int.random(in: 10...20)) / 20.0,
            launchScale:    Double(Int.random(in: 20...38)) / 20.0,
            landScale:      Double(Int.random(in: 6...18)) / 20.0,
            coyoteFrames:   Double(Int.random(in: 1...8)),
            bufferFrames:   Double(Int.random(in: 1...8)),
            fallMult:       Double(Int.random(in: 10...28)) / 10.0,
            apexGravFactor: Double(Int.random(in: 2...18)) / 20.0,
            features: JumpFeatures(
                coyoteTime:   Bool.random(),
                jumpBuffer:   Bool.random(),
                variableJump: Bool.random(),
                asymGrav:     Bool.random(),
                apexGrav:     Bool.random()
            )
        )
    }

    // MARK: QR serialization

    /// Encodes the params to a compact JSON string for QR embedding.
    /// - Throws: `EncodingError` if serialization fails.
    /// - Returns: A UTF-8 JSON string.
    func encoded() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Reconstructs a `JumpParams` from a JSON string produced by `encoded()`.
    /// - Parameter string: The UTF-8 JSON string.
    /// - Throws: `DecodingError` if the string is malformed.
    static func decoded(from string: String) throws -> JumpParams {
        guard let data = string.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Bad UTF-8"))
        }
        return try JSONDecoder().decode(JumpParams.self, from: data)
    }
}

// MARK: - Preset

/// A named snapshot of a `JumpParams` configuration.
/// Stored as an array in the app's Documents directory via `PresetStore`.
struct Preset: Identifiable, Codable {
    /// Stable identity for SwiftUI list diffing and deletion.
    var id: UUID = UUID()
    /// Display name shown in the presets list.
    var name: String
    /// The full jump configuration snapshot.
    var params: JumpParams
}
