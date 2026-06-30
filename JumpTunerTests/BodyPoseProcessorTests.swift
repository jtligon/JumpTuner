// BodyPoseProcessorTests.swift
// Tests for BodyPoseProcessor: mask compositing and the full Vision pipeline.
//
// Three layers:
//   1. Robot image generation — verifies the test fixture itself.
//   2. applyMask unit tests   — deterministic CGContext.clip semantics with known CVPixelBuffers.
//   3. Integration test       — process() end-to-end (Vision; assertions are tolerance-aware).

import Testing
import UIKit
import CoreVideo
@testable import JumpTuner

// Bundle(for:) requires a class type; Swift Testing suites are structs.
private final class BundleLocator: NSObject {}

// MARK: - Suite

@Suite("BodyPoseProcessor")
@MainActor
struct BodyPoseProcessorTests {

    // MARK: - Test fixture: robot bitmap

    /// Renders the robot sprite as a UIImage with a white background, mirroring the
    /// exact shapes from RobotNode.swift.
    ///
    /// Coordinate conversion:  y_ui = feetY − y_sk
    /// where feetY = 70 (feet land 10 pt from the bottom of the 80×80 canvas).
    ///
    /// Shape reference (SpriteKit coords, y+ up, origin at feet):
    ///   Legs      rect(-2.5, 0, 5, 10)    at (±6, 0)
    ///   Torso     rect(-10, -8, 20, 16)   at (0, 17)   → abs y 9…25
    ///   Chest     rect(-4, -2.5, 8, 5)    at (0, 17)   → abs y 14.5…19.5
    ///   Arms      rect(-2.5,-11, 5, 11)   at (±14, 21) → abs y 10…21
    ///   Head      rect(-9, -7.5, 18, 15)  at (0, 30)   → abs y 22.5…37.5
    ///   Eyes      circles r=2             at (±4.5, 30)
    ///   Stick     rect(-1, 0, 2, 5)       at (0, 37)   → abs y 37…42
    ///   AntDot    circle r=2              at (0, 43)
    static func makeRobotImage(size: CGSize = CGSize(width: 80, height: 80)) -> UIImage {
        let bodyColor   = UIColor(red: 0.95, green: 0.82, blue: 0.25, alpha: 1)
        let accentColor = UIColor(red: 1.00, green: 0.45, blue: 0.20, alpha: 1)
        let cx: CGFloat  = size.width  / 2   // 40
        let feetY: CGFloat = size.height - 10 // 70

        // Convert SpriteKit y (origin at feet, y+ up) to UIKit y (origin at top, y+ down).
        // The *top* of a shape in SK coords maps to the *top* of the rect in UIKit,
        // so:  uiTop = feetY - skYTop   and height stays the same.
        func uiY(_ skYTop: CGFloat) -> CGFloat { feetY - skYTop }

        return UIGraphicsImageRenderer(size: size).image { _ in
            // White background
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            // Legs  — abs SK y: 0…10
            for xOff: CGFloat in [-6, 6] {
                let r = CGRect(x: cx + xOff - 2.5, y: uiY(10), width: 5, height: 10)
                let p = UIBezierPath(roundedRect: r, cornerRadius: 2.5)
                bodyColor.setFill(); p.fill()
                accentColor.setStroke(); p.lineWidth = 1.5; p.stroke()
            }

            // Torso — abs SK y: 9…25  (center 17, rect −8…+8)
            let torsoPath = UIBezierPath(roundedRect: CGRect(x: cx - 10, y: uiY(25),
                                                              width: 20, height: 16), cornerRadius: 5)
            bodyColor.setFill(); torsoPath.fill()
            accentColor.setStroke(); torsoPath.lineWidth = 2; torsoPath.stroke()

            // Chest detail — abs SK y: 14.5…19.5
            let chestPath = UIBezierPath(roundedRect: CGRect(x: cx - 4, y: uiY(19.5),
                                                              width: 8, height: 5), cornerRadius: 2)
            accentColor.withAlphaComponent(0.6).setFill(); chestPath.fill()

            // Arms — abs SK y: 10…21 (pivot 21, rect −11…0)
            for xOff: CGFloat in [-14, 14] {
                let r = CGRect(x: cx + xOff - 2.5, y: uiY(21), width: 5, height: 11)
                let p = UIBezierPath(roundedRect: r, cornerRadius: 2.5)
                bodyColor.setFill(); p.fill()
                accentColor.setStroke(); p.lineWidth = 1.5; p.stroke()
            }

            // Head — abs SK y: 22.5…37.5 (center 30, rect −7.5…+7.5)
            let headPath = UIBezierPath(roundedRect: CGRect(x: cx - 9, y: uiY(37.5),
                                                             width: 18, height: 15), cornerRadius: 6)
            bodyColor.setFill(); headPath.fill()
            accentColor.setStroke(); headPath.lineWidth = 2; headPath.stroke()

            // Eyes — SK y = 30 → UI y = 40
            for xOff: CGFloat in [-4.5, 4.5] {
                let eye = UIBezierPath(arcCenter: CGPoint(x: cx + xOff, y: feetY - 30),
                                       radius: 2, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                accentColor.setFill(); eye.fill()
            }

            // Antenna stick — abs SK y: 37…42
            let stick = UIBezierPath(roundedRect: CGRect(x: cx - 1, y: uiY(42), width: 2, height: 5),
                                     cornerRadius: 1)
            accentColor.setFill(); stick.fill()

            // Antenna dot — SK y = 43 → UI y = 27
            let dot = UIBezierPath(arcCenter: CGPoint(x: cx, y: feetY - 43),
                                   radius: 2, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            accentColor.setFill(); dot.fill()
        }
    }

    // MARK: - Pixel sampling

    struct RGBA: CustomStringConvertible {
        let r, g, b, a: UInt8
        var description: String { "RGBA(\(r),\(g),\(b),\(a))" }
    }

    /// Samples a single pixel from a UIImage at the given point (UIKit coordinates).
    static func samplePixel(_ image: UIImage, at point: CGPoint) -> RGBA? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        let scale = image.scale
        let px = Int(point.x * scale), py = Int(point.y * scale)
        guard px >= 0 && px < w && py >= 0 && py < h else { return nil }

        var raw = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(
            data: &raw, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // In a raw CGBitmapContext, ctx.draw(cgImage) maps CGImage row 0 to CG y=(h−1)
        // (the top of the CG space). So CGImage pixel (px, py) lands at CG (px, h−1−py).
        // To capture that at device (0,0) we translate by (−px, −(h−1−py)).
        ctx.translateBy(x: -CGFloat(px), y: -CGFloat(h - py - 1))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return RGBA(r: raw[0], g: raw[1], b: raw[2], a: raw[3])
    }

    // MARK: - Pixel buffer factory (for applyMask unit tests)

    /// Creates a kCVPixelFormatType_OneComponent8 CVPixelBuffer filled with a constant value.
    /// 255 = all-white (keep everything); 0 = all-black (clip everything).
    static func makeMaskBuffer(width: Int, height: Int, filling value: UInt8) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                         kCVPixelFormatType_OneComponent8, attrs, &buffer)
        guard status == kCVReturnSuccess, let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let bpr = CVPixelBufferGetBytesPerRow(buffer)
        memset(CVPixelBufferGetBaseAddress(buffer)!, Int32(value), height * bpr)
        return buffer
    }

    // MARK: - 1. Robot image tests

    @Test func robotImageSize() {
        let image = Self.makeRobotImage()
        #expect(image.size == CGSize(width: 80, height: 80))
    }

    @Test func robotImageCornerIsWhiteBackground() {
        let image = Self.makeRobotImage()
        // (2, 2) is far outside the robot body (robot x spans ~23…57, y spans ~25…70)
        guard let px = Self.samplePixel(image, at: CGPoint(x: 2, y: 2)) else {
            Issue.record("Could not sample corner pixel")
            return
        }
        #expect(px.r > 240, "Background should be white (red)")
        #expect(px.g > 240, "Background should be white (green)")
        #expect(px.b > 240, "Background should be white (blue)")
        #expect(px.a > 240, "Background should be opaque")
    }

    @Test func robotImageTorsoIsYellow() {
        let image = Self.makeRobotImage()
        // Torso UIKit rect: x 30…50, y 45…61.  Centre: (40, 53).
        // bodyColor = (0.95, 0.82, 0.25) → approx RGBA(242, 209, 64, 255) when fully opaque.
        guard let px = Self.samplePixel(image, at: CGPoint(x: 40, y: 53)) else {
            Issue.record("Could not sample torso pixel")
            return
        }
        #expect(px.r > 200, "Torso should have high red (yellow body): \(px)")
        #expect(px.g > 150, "Torso should have high green (yellow body): \(px)")
        #expect(px.b <  80, "Torso should have low blue  (yellow body): \(px)")
        #expect(px.a > 240, "Torso should be opaque: \(px)")
    }

    // MARK: - 2. applyMask unit tests (deterministic)

    // These tests bypass Vision entirely, exercising only the CGContext.clip compositing
    // path in BodyPoseProcessor.applyMask(_:to:).

    @Test func applyBlackMaskMakesEverythingTransparent() {
        let image = Self.makeRobotImage()
        guard let buffer = Self.makeMaskBuffer(width: 80, height: 80, filling: 0) else {
            Issue.record("Could not create pixel buffer")
            return
        }
        guard let result = BodyPoseProcessor.applyMask(buffer, to: image) else {
            Issue.record("applyMask returned nil")
            return
        }
        // An all-black mask means CGContext.clip clips everything — alpha must be 0 everywhere.
        // Sample the torso centre, which was fully opaque in the original.
        guard let px = Self.samplePixel(result, at: CGPoint(x: 40, y: 53)) else {
            Issue.record("Could not sample pixel")
            return
        }
        #expect(px.a == 0, "All-black mask should produce fully transparent output; got \(px)")
    }

    @Test func applyWhiteMaskPreservesImage() {
        let image = Self.makeRobotImage()
        guard let buffer = Self.makeMaskBuffer(width: 80, height: 80, filling: 255) else {
            Issue.record("Could not create pixel buffer")
            return
        }
        guard let result = BodyPoseProcessor.applyMask(buffer, to: image) else {
            Issue.record("applyMask returned nil")
            return
        }
        // An all-white mask means nothing is clipped — the original pixels pass through.
        // The corner (white background) should still be fully opaque.
        guard let corner = Self.samplePixel(result, at: CGPoint(x: 2, y: 2)) else {
            Issue.record("Could not sample corner pixel")
            return
        }
        #expect(corner.a > 200, "All-white mask should leave original pixels intact; got \(corner)")
        // And the torso should still be yellow.
        guard let torso = Self.samplePixel(result, at: CGPoint(x: 40, y: 53)) else {
            Issue.record("Could not sample torso pixel")
            return
        }
        #expect(torso.r > 200, "Torso should be preserved by white mask; got \(torso)")
        #expect(torso.a > 200, "Torso should remain opaque; got \(torso)")
    }

    // MARK: - 3. Integration test (full Vision pipeline — synthetic image)

    @Test func processRobotImageProducesValidCutout() async {
        let image = Self.makeRobotImage()
        let segments = await BodyPoseProcessor.process(image)

        // The cutout must always come back at the same size as the input.
        #expect(segments.cutout.size == image.size)

        // The cutout must always have a valid CGImage backing (not a nil-data UIImage).
        #expect(segments.cutout.cgImage != nil)

        // The robot is not a human — skeleton parts should never be generated.
        #expect(!segments.hasSkeleton)
        #expect(segments.head  == nil)
        #expect(segments.torso == nil)
        #expect(segments.legs  == nil)

        // If Vision successfully detected and removed the background, the top-left corner
        // (white in the input) should become transparent in the cutout.
        // If Vision returned the original image as a fallback, the corner stays white/opaque.
        // Either outcome is acceptable; we verify internal consistency only:
        // if the corner is transparent then the robot body centre must still be visible.
        if let corner = Self.samplePixel(segments.cutout, at: CGPoint(x: 2, y: 2)),
           corner.a < 10 {
            // Background was removed — verify the robot body wasn't erroneously erased too.
            guard let body = Self.samplePixel(segments.cutout, at: CGPoint(x: 40, y: 53)) else {
                Issue.record("Could not sample body pixel after background removal")
                return
            }
            #expect(body.a > 0,
                    "Robot body should remain visible after background removal; got \(body)")
        }
    }

    /// Verifies VNGenerateForegroundInstanceMaskRequest with an actual iPhone photo.
    ///
    /// IMG_2221.png: kitten sitting on a blue blanket, raw pixels 4196 × 3910 (landscape),
    /// orientation=.up (PNG EXIF not processed by UIImage). Vision sees the landscape pixels.
    ///
    /// The full segmentation assertions only run on physical devices because
    /// VNGenerateForegroundInstanceMaskRequest requires the Neural Engine (Error 9:
    /// "Could not create inference context" on the iOS Simulator).
    @Test func kittenPhotoGetsBackgroundRemoved() async {
        // Bundle(for:) works here because IMG_2221.png is a resource in the JumpTunerTests
        // target. This is preferred over #file-relative paths because it works on device too.
        let bundle = Bundle(for: BundleLocator.self)
        guard let imageURL = bundle.url(forResource: "IMG_2221", withExtension: "png"),
              let data = try? Data(contentsOf: imageURL),
              let image = UIImage(data: data) else {
            Issue.record("Could not load IMG_2221.png from test bundle")
            return
        }

        let segments = await BodyPoseProcessor.process(image)

        // Always: cutout must be the same display size and must not detect a human skeleton.
        #expect(segments.cutout.size == image.size)
        #expect(!segments.hasSkeleton)

#if !targetEnvironment(simulator)
        // VNGenerateForegroundInstanceMaskRequest uses the Neural Engine — not emulated on
        // the iOS Simulator (Error 9 "Could not create inference context"). These assertions
        // only run on physical devices where segmentation actually fires.
        let w = segments.cutout.size.width
        let h = segments.cutout.size.height
        let m = min(w, h) * 0.03

        // All four corners are clearly background in this photo.
        // applyMask stores its result with y=0 at bottom (raw CGBitmapContext), so
        // samplePixel at (x, y) reads source pixels at (x, h−1−y). Both vertical
        // corner pairs happen to be background in IMG_2221, so the y-flip doesn't matter.
        for (label, pt) in [
            ("top-left",     CGPoint(x: m,     y: m)),
            ("top-right",    CGPoint(x: w - m, y: m)),
            ("bottom-left",  CGPoint(x: m,     y: h - m)),
            ("bottom-right", CGPoint(x: w - m, y: h - m)),
        ] as [(String, CGPoint)] {
            guard let px = Self.samplePixel(segments.cutout, at: pt) else {
                Issue.record("Could not sample \(label) corner at \(pt)")
                return
            }
            #expect(px.a < 30,
                    "Corner '\(label)' should be transparent after background removal; got \(px)")
        }

        // Kitten body center in the landscape raw pixels is around (55 %, 50 %).
        // applyMask y-flip maps result (55 %, 50 %) → source (55 %, 50 %).
        let kittenPt = CGPoint(x: w * 0.55, y: h * 0.50)
        guard let kittenPx = Self.samplePixel(segments.cutout, at: kittenPt) else {
            Issue.record("Could not sample kitten body at \(kittenPt)")
            return
        }
        #expect(kittenPx.a > 200,
                "Kitten body at \(kittenPt) should be opaque after background removal; got \(kittenPx)")
#endif
    }
}
