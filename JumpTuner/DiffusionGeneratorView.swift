// DiffusionGeneratorView.swift
// Sheet that drives the full Stable Diffusion sprite generation pipeline:
//   1. Photo import → BodyPoseProcessor segmentation
//   2. Optional one-time model download (ModelDownloadManager)
//   3. Per-phase SD generation with progress display (DiffusionService)
//   4. Callback with the finished CharacterSkin to the caller

import SwiftUI
import SpriteKit
import PhotosUI

struct DiffusionGeneratorView: View {
    let onSkin: (CharacterSkin) -> Void

    @StateObject private var downloadManager = ModelDownloadManager()
    @State private var pickerItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var generationState: GenerationState = .idle
    @State private var errorMessage: String?
    @State private var generatedCount = 0

    @Environment(\.dismiss) private var dismiss

    private static let totalPhases = 6

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {

                // ── Step indicators ──────────────────────────────────────────
                HStack(spacing: 0) {
                    StepBadge(number: 1, label: "Photo",   isActive: sourceImage == nil)
                    stepConnector
                    StepBadge(number: 2, label: "Models",  isActive: sourceImage != nil && !downloadManager.isDownloaded)
                    stepConnector
                    StepBadge(number: 3, label: "Generate",isActive: downloadManager.isDownloaded && sourceImage != nil)
                }
                .padding(.top, 8)

                Divider()

                // ── Main content area ────────────────────────────────────────
                Group {
                    switch generationState {
                    case .idle:
                        idleContent
                    case .segmenting:
                        statusRow(icon: "person.and.background.dotted", text: "Segmenting photo…")
                    case .downloading:
                        downloadContent
                    case .generating:
                        generatingContent
                    case .done(let skin):
                        doneContent(skin: skin)
                    }
                }
                .padding(.horizontal, 20)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Spacer()
            }
            .navigationTitle("Diffusion Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sub-views

    private var idleContent: some View {
        VStack(spacing: 16) {
            Text("Take or choose a photo, then generate 6 jump-pose sprites on-device using Stable Diffusion.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !DiffusionService.deviceMeetsRequirements {
                Label("Requires iOS 17 or later", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Label(sourceImage == nil ? "Choose Photo" : "Change Photo",
                      systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(12)
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await loadPhoto(item) }
            }

            if sourceImage != nil {
                proceedButton
            }
        }
    }

    private var downloadContent: some View {
        VStack(spacing: 16) {
            Text("Stable Diffusion models (~630 MB) need to be downloaded once.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ProgressView(value: downloadManager.progress.overallFraction)
                .progressViewStyle(.linear)
                .tint(.accentColor)

            Text(downloadManager.progress.phaseName.isEmpty
                 ? "Preparing…"
                 : "Downloading \(downloadManager.progress.phaseName)…")
                .font(.caption)
                .foregroundStyle(.secondary)

            if downloadManager.isDownloaded {
                proceedButton
            } else if !downloadManager.isDownloading {
                Button("Download Models") {
                    downloadManager.startDownload()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Cancel Download", role: .destructive) {
                    downloadManager.cancelDownload()
                    generationState = .idle
                }
                .font(.footnote)
            }

            if let dlError = downloadManager.error {
                Text(dlError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var generatingContent: some View {
        VStack(spacing: 16) {
            ProgressView(value: Double(generatedCount) / Double(Self.totalPhases))
                .progressViewStyle(.linear)
                .tint(.accentColor)

            Text("Generating pose \(generatedCount + 1) of \(Self.totalPhases)…")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("This may take 5–60 seconds depending on your device.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private func doneContent(skin: CharacterSkin) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("6 poses generated!")
                .font(.headline)

            Button("Use Character") {
                onSkin(skin)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var proceedButton: some View {
        Button("Continue") {
            startPipeline()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!downloadManager.isDownloaded && generationState == .idle)
    }

    private var stepConnector: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private func statusRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Logic

    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data  = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await MainActor.run { sourceImage = image }
    }

    private func startPipeline() {
        guard let image = sourceImage else { return }
        errorMessage = nil

        if !downloadManager.isDownloaded {
            generationState = .downloading
            downloadManager.startDownload()
            // Watch for download completion.
            Task {
                while !downloadManager.isDownloaded && downloadManager.error == nil {
                    try? await Task.sleep(for: .milliseconds(300))
                }
                if downloadManager.isDownloaded {
                    await runGeneration(source: image)
                }
            }
        } else {
            Task { await runGeneration(source: image) }
        }
    }

    @MainActor
    private func runGeneration(source: UIImage) async {
        generationState = .segmenting
        let segments = await BodyPoseProcessor.process(source)
        let refImage = segments.cutout   // segmented cutout as the img2img reference

        generationState = .generating
        generatedCount  = 0

        do {
            let service = DiffusionService()
            let uiImages = try await service.generateSprites(referenceImage: refImage) { progress in
                Task { @MainActor in
                    generatedCount = progress.phaseIndex
                }
            }
            // Convert UIImages → SKTextures.
            var textures: [JumpPhase: SKTexture] = [:]
            for (phase, img) in uiImages {
                textures[phase] = SKTexture(image: img)
            }
            let name = "Diffusion"
            let skin = CharacterSkin.diffusion(phaseTextures: textures,
                                               fallbackImage: refImage,
                                               name: name)
            generationState = .done(skin)
        } catch {
            errorMessage = error.localizedDescription
            generationState = .idle
        }
    }

    // MARK: - State

    private enum GenerationState {
        case idle
        case segmenting
        case downloading
        case generating
        case done(CharacterSkin)
    }
}

// MARK: - Step badge

private struct StepBadge: View {
    let number: Int
    let label: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isActive ? .white : .secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
        .frame(minWidth: 60)
    }
}
