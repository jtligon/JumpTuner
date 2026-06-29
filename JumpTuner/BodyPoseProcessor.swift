// BodyPoseProcessor.swift
// On-device Vision pipeline: segments the foreground subject and, when a
// human body is detected, splits the cutout into head / torso / legs crops.
//
// Uses VNGeneratePersonSegmentationRequest (iOS 15+, on-device) for the mask
// and VNDetectHumanBodyPoseRequest for joint positions. Both requests run
// against the same VNImageRequestHandler in one pass.

import UIKit
import Vision
import CoreImage

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
        // Normalize orientation so Vision sees y-up, unrotated pixels.
        let image = source.normalized()
        guard let ciImage = CIImage(image: image) else {
            return BodySegments(cutout: source, head: nil, torso: nil, legs: nil)
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = runVision(image: image, ciImage: ciImage)
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Core Vision pass

    private static func runVision(image: UIImage, ciImage: CIImage) -> BodySegments {
        // Build both requests and run them in a single handler pass.
        let segRequest  = VNGeneratePersonSegmentationRequest()
        segRequest.qualityLevel    = .accurate
        segRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let poseRequest = VNDetectHumanBodyPoseRequest()

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try? handler.perform([segRequest, poseRequest])

        // Segmentation: build clean cutout (fall back to original on failure)
        let cutout: UIImage
        if let pixelBuffer = segRequest.results?.first?.pixelBuffer {
            cutout = applyMask(pixelBuffer, to: ciImage, size: image.size, scale: image.scale)
                ?? image
        } else {
            cutout = image
        }

        // Pose: convert joints to UIKit image coordinates
        guard let observation = poseRequest.results?.first,
              let allJoints   = try? observation.recognizedPoints(.all),
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

    // MARK: - Mask compositing

    private static func applyMask(
        _ pixelBuffer: CVPixelBuffer,
        to ciImage: CIImage,
        size: CGSize,
        scale: CGFloat
    ) -> UIImage? {
        let maskCI = CIImage(cvPixelBuffer: pixelBuffer)
        let scaleX = ciImage.extent.width  / maskCI.extent.width
        let scaleY = ciImage.extent.height / maskCI.extent.height
        let scaledMask = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let masked = ciImage.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputMaskImageKey:       scaledMask,
            kCIInputBackgroundImageKey: CIImage.empty()
        ])

        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = ctx.createCGImage(masked, from: masked.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
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

        guard let shoulderY = midY(joints[.leftShoulder], joints[.rightShoulder]),
              let hipY      = midY(joints[.leftHip],      joints[.rightHip]),
              shoulderY < hipY else { return (nil, nil, nil) }

        // Add overlap at each boundary so seams are hidden by the SkeletalCharacterNode
        let overlap: CGFloat = 6
        let headRect  = CGRect(x: 0, y: 0,                     width: w, height: shoulderY + overlap)
        let torsoRect = CGRect(x: 0, y: shoulderY - overlap,   width: w, height: (hipY - shoulderY) + overlap * 2)
        let legsRect  = CGRect(x: 0, y: hipY - overlap,        width: w, height: h - (hipY - overlap))

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
        case (nil, nil): return nil
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
    /// Returns a copy of the image drawn with .up orientation so Vision
    /// sees unrotated pixel data regardless of capture orientation.
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}
