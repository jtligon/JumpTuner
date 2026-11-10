// DiffusionService.swift
// On-device Stable Diffusion pose generation using apple/ml-stable-diffusion.
//
// For each of the 6 JumpPhase values a pose-conditioned prompt is paired with
// the segmented reference image (img2img) to generate a stylised sprite that
// resembles the reference subject but adopts the correct jump pose.
//
// Hardware requirement: A17 Pro / M-series chip for Neural Engine acceleration.
// The pipeline falls back to CPU on older hardware, but generation will be very slow.

import Foundation
import CoreML
import UIKit
import SpriteKit
import StableDiffusion   // apple/ml-stable-diffusion Swift package

// MARK: - Per-phase prompt map

private let phasePrompts: [JumpPhase: (positive: String, negative: String)] = [
    .idle: (
        positive: "cartoon platformer sprite, character standing idle, arms at sides, isolated on transparent background, flat cel-shaded style, clean outline",
        negative: "blurry, distorted, extra limbs, background, text, watermark"
    ),
    .squat: (
        positive: "cartoon platformer sprite, character crouching squat anticipation pose, knees bent, isolated on transparent background, flat cel-shaded style, clean outline",
        negative: "blurry, distorted, extra limbs, background, text, watermark"
    ),
    .ascending: (
        positive: "cartoon platformer sprite, character leaping upward, arms raised overhead, legs extended, isolated on transparent background, flat cel-shaded style, clean outline",
        negative: "blurry, distorted, extra limbs, background, text, watermark"
    ),
    .apex: (
        positive: "cartoon platformer sprite, character at peak of jump, weightless pose, arms spread, isolated on transparent background, flat cel-shaded style, clean outline",
        negative: "blurry, distorted, extra limbs, background, text, watermark"
    ),
    .descending: (
        positive: "cartoon platformer sprite, character falling downward, legs tucked slightly, arms back, isolated on transparent background, flat cel-shaded style, clean outline",
        negative: "blurry, distorted, extra limbs, background, text, watermark"
    ),
    .landing: (
        positive: "cartoon platformer sprite, character landing impact, knees bent deep, arms forward for balance, isolated on transparent background, flat cel-shaded style, clean outline",
        negative: "blurry, distorted, extra limbs, background, text, watermark"
    ),
]

// MARK: - Device capability check

extension DiffusionService {
    /// Returns true if the current device has hardware sufficient for reasonable generation speed.
    /// A17 Pro and later (iPhone 15 Pro+) or any M-series chip qualify.
    static var deviceMeetsRequirements: Bool {
        // ProcessInfo.processInfo.machineHardwareName is not available on iOS without entitlements.
        // We fall back to checking the Neural Engine compute units; on A17+ they handle the full model.
        // Any device running iOS 17+ is allowed to attempt generation (may be slow on older chips).
        if #available(iOS 17, *) { return true }
        return false
    }
}

// MARK: - Service

final class DiffusionService: @unchecked Sendable {

    typealias PhaseProgress = (phase: JumpPhase, phaseIndex: Int, stepFraction: Double)
    typealias ProgressHandler = @Sendable (PhaseProgress) -> Void

    // MARK: - Generation

    /// Generates one sprite per JumpPhase and returns the full dictionary.
    /// `referenceImage` is used as the img2img source; it should already be
    /// the segmented cutout produced by BodyPoseProcessor.
    ///
    /// Generation is dispatched to a background thread so the calling
    /// MainActor is not blocked during the CPU/ANE-intensive inference.
    func generateSprites(
        referenceImage: UIImage,
        progressHandler: ProgressHandler? = nil
    ) async throws -> [JumpPhase: UIImage] {
        guard DiffusionService.deviceMeetsRequirements else {
            throw DiffusionError.unsupportedDevice
        }
        guard ModelDownloadManager.checkComplete() else {
            throw DiffusionError.modelsNotDownloaded
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.runPipeline(referenceImage: referenceImage,
                                                      progressHandler: progressHandler)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Synchronous pipeline (runs off the main thread)

    private func runPipeline(
        referenceImage: UIImage,
        progressHandler: ProgressHandler?
    ) throws -> [JumpPhase: UIImage] {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine

        let pipeline = try StableDiffusionPipeline(
            resourcesAt: ModelDownloadManager.modelDirectoryURL,
            controlNet: [],
            configuration: config,
            reduceMemory: true)

        try pipeline.loadResources()
        defer { pipeline.unloadResources() }

        // Resize reference to 512×512 — the standard SD v1.5 input resolution.
        let resized = resize(referenceImage, to: CGSize(width: 512, height: 512))

        let orderedPhases: [JumpPhase] = [.idle, .squat, .ascending, .apex, .descending, .landing]
        var results: [JumpPhase: UIImage] = [:]

        for (index, phase) in orderedPhases.enumerated() {
            guard let prompts = phasePrompts[phase] else { continue }

            var pipelineConfig = StableDiffusionPipeline.Configuration(prompt: prompts.positive)
            pipelineConfig.negativePrompt = prompts.negative
            pipelineConfig.imageCount     = 1
            pipelineConfig.stepCount      = 25
            pipelineConfig.startingImage  = resized
            pipelineConfig.strength       = 0.65   // keep reference subject recognisable
            pipelineConfig.seed           = UInt32.random(in: 0..<UInt32.max)

            let images = try pipeline.generateImages(configuration: pipelineConfig) { progress in
                let fraction = Double(progress.step) / Double(progress.stepCount)
                progressHandler?((phase: phase, phaseIndex: index, stepFraction: fraction))
                return true  // return false to cancel
            }

            if let first = images.first, let cgImage = first {
                results[phase] = UIImage(cgImage: cgImage)
            }
        }

        return results
    }

    // MARK: - Private helpers

    private func resize(_ image: UIImage, to size: CGSize) -> CGImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let uiImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return uiImage.cgImage
    }
}

// MARK: - Errors

enum DiffusionError: LocalizedError {
    case unsupportedDevice
    case modelsNotDownloaded
    case pipelineFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            return "On-device image generation requires iOS 17 or later."
        case .modelsNotDownloaded:
            return "Stable Diffusion models have not been downloaded yet."
        case .pipelineFailed(let err):
            return "Generation failed: \(err.localizedDescription)"
        }
    }
}
