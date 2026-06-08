// JumpTunerTests.swift
// Tests for Models.swift: JumpFeatures, JumpParams, Preset

import Testing
import Foundation
@testable import JumpTuner

// MARK: - JumpFeatures

@Suite("JumpFeatures")
@MainActor
struct JumpFeaturesTests {

    @Test func defaultValues() {
        let f = JumpFeatures()
        #expect(f.coyoteTime == true)
        #expect(f.jumpBuffer == true)
        #expect(f.variableJump == true)
        #expect(f.asymGrav == true)
        #expect(f.apexGrav == true)
    }

    @Test func equatableSame() {
        #expect(JumpFeatures() == JumpFeatures())
    }

    @Test func equatableDifferent() {
        var other = JumpFeatures()
        other.coyoteTime = false
        #expect(JumpFeatures() != other)
    }

    @Test func codableRoundtrip() throws {
        let original = JumpFeatures(
            coyoteTime: false, jumpBuffer: true,
            variableJump: false, asymGrav: true, apexGrav: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JumpFeatures.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - JumpParams

@Suite("JumpParams")
@MainActor
struct JumpParamsTests {

    @Test func defaultValues() {
        let p = JumpParams.defaults
        #expect(p.squatFrames    == 3)
        #expect(p.ascentFrames   == 11)
        #expect(p.apexFrames     == 2)
        #expect(p.descentFrames  == 8)
        #expect(p.landingFrames  == 3)
        #expect(p.jumpHeight     == 60)
        #expect(p.squatScale     == 0.70)
        #expect(p.launchScale    == 1.40)
        #expect(p.landScale      == 0.55)
        #expect(p.coyoteFrames   == 5)
        #expect(p.bufferFrames   == 4)
        #expect(p.fallMult       == 1.6)
        #expect(p.apexGravFactor == 0.40)
        #expect(p.features       == JumpFeatures())
    }

    @Test func equatableSame() {
        #expect(JumpParams.defaults == JumpParams.defaults)
    }

    @Test func equatableDifferent() {
        var other = JumpParams.defaults
        other.jumpHeight = 999
        #expect(JumpParams.defaults != other)
    }

    @Test func encodeDecodeRoundtrip() throws {
        let original = JumpParams.defaults
        let json = try original.encoded()
        #expect(!json.isEmpty)
        let decoded = try JumpParams.decoded(from: json)
        #expect(decoded == original)
    }

    @Test func decodeThrowsOnMalformedJSON() {
        #expect(throws: (any Error).self) {
            try JumpParams.decoded(from: "{ not valid json }")
        }
    }

    @Test func randomizedStaysInRange() {
        let p = JumpParams.randomized()
        #expect((0...8).contains(p.squatFrames))
        #expect((5...25).contains(p.ascentFrames))
        #expect((0...6).contains(p.apexFrames))
        #expect((4...20).contains(p.descentFrames))
        #expect((1...8).contains(p.landingFrames))
        #expect((20...400).contains(p.jumpHeight))
        #expect(p.squatScale    >= 0.5  && p.squatScale    <= 1.0)
        #expect(p.launchScale   >= 1.0  && p.launchScale   <= 1.9)
        #expect(p.landScale     >= 0.3  && p.landScale     <= 0.9)
        #expect((1...8).contains(p.coyoteFrames))
        #expect((1...8).contains(p.bufferFrames))
        #expect(p.fallMult       >= 1.0 && p.fallMult       <= 2.8)
        #expect(p.apexGravFactor >= 0.1 && p.apexGravFactor <= 0.9)
    }

    @Test func codableRoundtrip() throws {
        let original = JumpParams.randomized()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JumpParams.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - Preset

@Suite("Preset")
@MainActor
struct PresetTests {

    @Test func creation() {
        let preset = Preset(name: "Test", params: .defaults)
        #expect(preset.name == "Test")
        #expect(preset.params == .defaults)
    }

    @Test func customID() {
        let id = UUID()
        let preset = Preset(id: id, name: "Named", params: .defaults)
        #expect(preset.id == id)
    }

    @Test func autoIDIsUnique() {
        let a = Preset(name: "A", params: .defaults)
        let b = Preset(name: "B", params: .defaults)
        #expect(a.id != b.id)
    }

    @Test func codableRoundtrip() throws {
        let original = Preset(name: "Saved", params: .defaults)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Preset.self, from: data)
        #expect(decoded.id     == original.id)
        #expect(decoded.name   == original.name)
        #expect(decoded.params == original.params)
    }
}
