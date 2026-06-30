// BodyPoseProcessor.swift
// On-device Vision pipeline: segments the foreground subject and, when a
// human body is detected, splits the cutout into head / torso / legs crops.
//
// Uses VNGenerateForegroundInstanceMaskRequest (iOS 17+, any subject) for the
// mask and VNDetectHumanBodyPoseRequest for joint positions. Both requests run
// against the same VNImageRequestHandler in one pass.

import UIKit
import Vision

// MARK: - Result type

struct BodySegments {
    /// Background-removed full image. Always present.
    let cutout: UIImage
    /// Cropped head region. Nil when no person was detected.
    let head:  UIImage?
    /// Cropped torso + arms region. Nil when no person was detected.
    let torso: UIImage?
    /// Cropped legs region. Nil when no person was detected.
    let legs:  UIImage?

    var hasSkeleton: Bool { head != nil && torso != nil && legs != nil }
}

// MARK: - Processor

enum BodyPoseProcessor {

    /// Runs Vision on `source` and returns segmented body parts.
    /// Always succeeds — returns a `BodySegments` with just `cutout` if
    /// segmentation or pose detection fails.
    static func process(_ source: UIImage) async -> BodySegments {
        let image = source.normalized()

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runVision(image: image))
            }
        }
    }

    // MARK: - Core Vision pass

    private static func runVision(image: UIImage) -> BodySegments {
        guard let cgImage = image.cgImage else {
            return BodySegments(cutout: image, head: nil, torso: nil, legs: nil)
        }

        // VNGenerateForegroundInstanceMaskRequest works on any subject (person,
        // animal, object) — unlike the person-only segmentation request.
        let maskRequest = VNGenerateForegroundInstanceMaskRequest()
        let poseRequest = VNDetectHumanBodyPoseRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([maskRequest, poseRequest])

        // Build clean cutout from the foreground mask.
        // generateScaledMaskForImage needs the same handler to access the image.
        let cutout: UIImage
        if let observation = maskRequest.results?.first,
           let maskBuffer  = try? observation.generateScaledMaskForImage(
               forInstances: observation.allInstances, from: handler) {
            cutout = applyMask(maskBuffer, to: image) ?? image
        } else {
            cutout = image
        }

        // Pose: detect body joints for skeletal splitting (people only).
        guard let poseObservation = poseRequest.results?.first,
              let allJoints       = try? poseObservation.recognizedPoints(.all),
              !allJoints.isEmpty else {
            return BodySegments(cutout: cutout, head: nil, torso: nil, legs: nil)
        }

        let joints = toImageCoords(allJoints, imageSize: image.size)
        guard !joints.isEmpty else {
            return BodySegments(cutout: cutout, head: nil, torso: nil, legs: nil)
        }

        let (head, torso, legs) = splitBody(cutout: cutout, joints: joints)
        return BodySegments(cutout: cutout, head: head, torso: torso, legs: legs)
    }

    // MARK: - Mask compositing (pure CoreGraphics — no Metal/CIContext)

    // `internal` (not private) so tests can call it directly with a known pixel buffer.
    static func applyMask(_ pixelBuffer: CVPixelBuffer, to image: UIImage) -> UIImage? {
        // Copy mask bytes before unlocking so the CGDataProvider has a stable buffer.
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let mw  = CVPixelBufferGetWidth(pixelBuffer)
        let mh  = CVPixelBufferGetHeight(pixelBuffer)
        let bpr = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }
        let maskData = Data(bytes: base, count: mh * bpr)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

        // Build a grayscale CGImage from the mask bytes.
        // White (255) = foreground/keep, Black (0) = background/clip.
        guard let provider = CGDataProvider(data: maskData as CFData),
              let maskCG = CGImage(
                  width: mw, height: mh,
                  bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: bpr,
                  space: CGColorSpaceCreateDeviceGray(),
                  bitmapInfo: CGBitmapInfo(),
                  provider: provider,
                  decode: nil, shouldInterpolate: true,
                  intent: .defaultIntent),
              let sourceCG = image.cgImage else { return nil }

        let w = sourceCG.width
        let h = sourceCG.height

        // CGContext.clip(to:mask:) clips based on luminosity:
        //   white (person/subject) → draws through, black (background) → transparent.
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.clip(to: CGRect(x: 0, y: 0, width: w, height: h), mask: maskCG)
        ctx.draw(sourceCG, in: CGRect(x: 0, y: 0, width: w, height: h))

        guard let result = ctx.makeImage() else { return nil }
        return UIImage(cgImage: result, scale: image.scale, orientation: .up)
    }

    // MARK: - Joint coordinate conversion

    /// Converts Vision normalized points (y=0 at bottom) to UIKit image points (y=0 at top),
    /// keeping only joints with confidence > 0.3.
    private static func toImageCoords(
        _ joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        imageSize: CGSize
    ) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        var result: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for (name, point) in joints where point.confidence > 0.3 {
            result[name] = CGPoint(
                x:        point.location.x  * imageSize.width,
                y: (1.0 - point.location.y) * imageSize.height
            )
        }
        return result
    }

    // MARK: - Body-part cropping

    /// Splits `cutout` at the shoulder and hip horizontal lines derived from keypoints.
    private static func splitBody(
        cutout: UIImage,
        joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> (head: UIImage?, torso: UIImage?, legs: UIImage?) {
        let h = cutout.size.height
        let w = cutout.size.width

        // Fall back to `root` joint when individual hip keypoints are absent
        // (e.g. half-body or portrait-cropped photos).
        let shoulderY = midY(joints[.leftShoulder], joints[.rightShoulder])
        let hipY      = midY(joints[.leftHip], joints[.rightHip]) ?? joints[.root]?.y

        guard let shoulderY, let hipY, shoulderY < hipY else { return (nil, nil, nil) }

        // Add overlap at each boundary so seams are hidden by SkeletalCharacterNode.
        let overlap: CGFloat = 6
        let headRect  = CGRect(x: 0, y: 0,                   width: w, height: shoulderY + overlap)
        let torsoRect = CGRect(x: 0, y: shoulderY - overlap, width: w, height: (hipY - shoulderY) + overlap * 2)
        let legsRect  = CGRect(x: 0, y: hipY - overlap,      width: w, height: h - (hipY - overlap))

        return (
            crop(cutout, to: headRect),
            crop(cutout, to: torsoRect),
            crop(cutout, to: legsRect)
        )
    }

    private static func midY(_ a: CGPoint?, _ b: CGPoint?) -> CGFloat? {
        switch (a, b) {
        case let (p?, q?): return (p.y + q.y) / 2
        case let (p?, nil): return p.y
        case let (nil, q?): return q.y
        case (nil, nil):    return nil
        }
    }

    private static func crop(_ image: UIImage, to rect: CGRect) -> UIImage? {
        let s = image.scale
        let scaledRect = CGRect(x: rect.minX * s, y: rect.minY * s,
                                width: rect.width * s, height: rect.height * s)
        guard scaledRect.height > 1,
              let cg = image.cgImage?.cropping(to: scaledRect) else { return nil }
        return UIImage(cgImage: cg, scale: s, orientation: .up)
    }
}

// MARK: - UIImage orientation normalization

private extension UIImage {
    /// Returns a copy redrawn at .up orientation so Vision sees un-rotated pixels.
    /// Uses scale=1.0 so a 4K photo isn't tripled to 12K+ pixels by the device scale factor.
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}
