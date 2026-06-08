// QRHelpersTests.swift
// Tests for QRHelpers: generateQR and PresetQRView.qrImage

import Testing
import UIKit
@testable import JumpTuner

@Suite("QRHelpers")
@MainActor
struct QRHelpersTests {

    @Test func generateQRReturnsImageForValidString() {
        let image = generateQR(from: "hello world")
        #expect(image != nil)
    }

    @Test func generateQRReturnsImageForEmptyString() {
        let image = generateQR(from: "")
        #expect(image != nil)
    }

    @Test func generateQRReturnsImageForJSONPayload() throws {
        let params = JumpParams.defaults
        let json = try params.encoded()
        let image = generateQR(from: json)
        #expect(image != nil)
    }

    @Test func presetQRViewComputesImage() {
        let preset = Preset(name: "MyPreset", params: .defaults)
        let view = PresetQRView(preset: preset)
        #expect(view.qrImage != nil)
    }
}
