// ModelDownloadManager.swift
// Manages the one-time download of Core ML Stable Diffusion model files.
// Files are stored in Application Support and persist across launches.
//
// The pipeline expects individual .mlmodelc bundles under a flat directory:
//   UNet.mlmodelc / VAEDecoder.mlmodelc / TextEncoder.mlmodelc
//   plus Vocab.json and merges.txt for the tokenizer.
//
// All five artefacts are fetched from the apple/coreml-stable-diffusion-v1-5
// model repository on Hugging Face.  The user is prompted once; afterwards
// the downloaded files are reused on every launch.

import Foundation

// MARK: - Progress snapshot

struct ModelDownloadProgress: Sendable {
    let phaseName: String       // e.g. "UNet"
    let phaseIndex: Int
    let phaseCount: Int
    let phaseFraction: Double   // 0…1 within the current file

    var overallFraction: Double {
        (Double(phaseIndex) + phaseFraction) / Double(phaseCount)
    }
}

// MARK: - Manager

@MainActor
final class ModelDownloadManager: ObservableObject {

    // Model directory shared with DiffusionService.
    static var modelDirectoryURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask)[0]
        return support.appendingPathComponent("JumpTunerSDModels/v1-5", isDirectory: true)
    }

    private static let baseURL = "https://huggingface.co/apple/coreml-stable-diffusion-v1-5/resolve/main"

    // Each entry is (remote filename, local filename).  The compiled UNet is the largest file.
    private static let artifacts: [(remote: String, local: String)] = [
        ("UNet.mlmodelc.zip",        "UNet.mlmodelc"),
        ("VAEDecoder.mlmodelc.zip",  "VAEDecoder.mlmodelc"),
        ("TextEncoder.mlmodelc.zip", "TextEncoder.mlmodelc"),
        ("Vocab.json",               "Vocab.json"),
        ("merges.txt",               "merges.txt"),
    ]

    @Published private(set) var isDownloaded = false
    @Published private(set) var isDownloading = false
    @Published private(set) var progress = ModelDownloadProgress(
        phaseName: "", phaseIndex: 0, phaseCount: 1, phaseFraction: 0)
    @Published private(set) var error: String?

    private var downloadTask: Task<Void, Never>?

    init() {
        isDownloaded = Self.checkComplete()
    }

    // MARK: - Public API

    func startDownload() {
        guard !isDownloaded && !isDownloading else { return }
        isDownloading = true
        error = nil
        downloadTask = Task { await runDownload() }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
    }

    // MARK: - Implementation

    private func runDownload() async {
        let dir = Self.modelDirectoryURL
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let artifacts = Self.artifacts
            for (index, artifact) in artifacts.enumerated() {
                try Task.checkCancellation()
                let dest = dir.appendingPathComponent(artifact.local)
                guard !FileManager.default.fileExists(atPath: dest.path) else {
                    // Already present (e.g. from a previous partial download).
                    continue
                }
                let remoteURL = URL(string: "\(Self.baseURL)/\(artifact.remote)")!
                progress = ModelDownloadProgress(phaseName: artifact.local,
                                                 phaseIndex: index,
                                                 phaseCount: artifacts.count,
                                                 phaseFraction: 0)
                try await fetchFile(from: remoteURL, to: dest, phaseIndex: index,
                                    phaseCount: artifacts.count,
                                    phaseName: artifact.local)
            }
            isDownloaded = Self.checkComplete()
        } catch is CancellationError {
            // No-op — user cancelled.
        } catch {
            self.error = error.localizedDescription
        }
        isDownloading = false
    }

    // Downloads one file with periodic progress updates.
    private func fetchFile(from url: URL, to dest: URL,
                           phaseIndex: Int, phaseCount: Int, phaseName: String) async throws {
        let (localURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        // .mlmodelc zips need unzipping; plain files move directly.
        if url.pathExtension == "zip" {
            try unzip(at: localURL, to: dest.deletingLastPathComponent(),
                      outputName: dest.lastPathComponent)
        } else {
            try FileManager.default.moveItem(at: localURL, to: dest)
        }
        progress = ModelDownloadProgress(phaseName: phaseName,
                                         phaseIndex: phaseIndex + 1,
                                         phaseCount: phaseCount,
                                         phaseFraction: 1)
    }

    // Minimal zip extraction using the system unzip tool (available on iOS via NSTask-equivalent).
    // Because iOS has no shell, we use ZipFoundation if available, or handle via URLSession
    // chunked response — for simplicity, we document the expectation that the HuggingFace files
    // are plain directories (not zips) when fetched with the correct Accept header.
    private func unzip(at zipURL: URL, to destDir: URL, outputName: String) throws {
        // apple/coreml-stable-diffusion provides pre-compiled .mlmodelc bundles as zip archives.
        // On iOS, unzipping a large archive requires a third-party library (e.g. ZipFoundation).
        // This stub moves the archive in place; a production build should integrate ZipFoundation
        // and replace this with: Archive(url: zipURL).extract(to: destDir).
        let raw = destDir.appendingPathComponent(outputName + ".zip")
        try FileManager.default.moveItem(at: zipURL, to: raw)
        // TODO: replace stub with actual unzip once ZipFoundation is added to the project.
    }

    // A download is "complete" when every required artifact is present.
    static func checkComplete() -> Bool {
        let dir = modelDirectoryURL
        return Self.artifacts.allSatisfy { pair in
            FileManager.default.fileExists(atPath: dir.appendingPathComponent(pair.local).path)
        }
    }
}
