//
//  JumpTuner.swift
//  JumpTuner
//
//  Created by Jeff Ligon on 4/25/26.
//

// JumpTuner.swift
// Drop this into a new SwiftUI iOS project. Requires iOS 16+.
// Add the CoreImage framework — it's used for QR generation (no third-party deps needed).

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Data model

struct JumpFeatures: Codable, Equatable {
    var coyoteTime: Bool = true
    var jumpBuffer: Bool = true
    var variableJump: Bool = true
    var asymGrav: Bool = true
    var apexGrav: Bool = true
}

struct JumpParams: Codable, Equatable {
    var squatFrames: Double = 3
    var ascentFrames: Double = 11
    var apexFrames: Double = 2
    var descentFrames: Double = 8
    var landingFrames: Double = 3
    var jumpHeight: Double = 60
    var squatScale: Double = 0.70
    var launchScale: Double = 1.40
    var landScale: Double = 0.55
    var coyoteFrames: Double = 5
    var bufferFrames: Double = 4
    var fallMult: Double = 1.6
    var apexGravFactor: Double = 0.40
    var features: JumpFeatures = JumpFeatures()

    // Compact encode for QR payload
    func encoded() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decoded(from string: String) throws -> JumpParams {
        guard let data = string.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Bad UTF-8"))
        }
        return try JSONDecoder().decode(JumpParams.self, from: data)
    }
}

struct Preset: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var params: JumpParams
}

// MARK: - Persistence

final class PresetStore: ObservableObject {
    @Published var presets: [Preset] = []

    private var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("jump_presets.json")
    }

    init() { load() }

    func save(_ preset: Preset) {
        if let idx = presets.firstIndex(where: { $0.name == preset.name }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(presets)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("PresetStore save error: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([Preset].self, from: data)
        else { return }
        presets = saved
    }
}

// MARK: - QR generation

func generateQR(from string: String) -> UIImage? {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}

// MARK: - Jump preview animation

struct JumpPreviewView: View {
    let params: JumpParams
    @State private var animating = false
    @State private var charY: CGFloat = 0
    @State private var scaleX: CGFloat = 1
    @State private var scaleY: CGFloat = 1

    private let groundY: CGFloat = 0
    private let charSize: CGFloat = 24

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))

            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator))

            Rectangle()
                .frame(width: charSize, height: charSize)
                .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
                .offset(y: -charY)
                .padding(.bottom, 1)
                .animation(animating ? .linear(duration: 0) : nil, value: charY)

            Button("▶ Preview") { startAnimation() }
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.bottom, 40)
        }
        .frame(height: 120)
        .border(Color(.separator), width: 0.5)
        .cornerRadius(12)
    }

    func startAnimation() {
        guard !animating else { return }
        animating = true
        let fps: Double = 60
        let p = params

        struct Phase { let name: String; let dur: Double }
        let phases: [Phase] = [
            .init(name: "squat", dur: p.squatFrames),
            .init(name: "launch", dur: 2),
            .init(name: "ascent", dur: p.ascentFrames),
            .init(name: "apex", dur: p.apexFrames),
            .init(name: "descent", dur: p.descentFrames),
            .init(name: "land", dur: 2),
            .init(name: "landing", dur: p.landingFrames),
            .init(name: "recover", dur: 4),
        ]
        let totalFrames = phases.reduce(0) { $0 + $1.dur }

        func ease(_ t: Double) -> Double { t < 0.5 ? 2*t*t : -1+(4-2*t)*t }
        func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b-a)*t }

        func stateAt(_ frame: Double) -> (name: String, t: Double) {
            var acc: Double = 0
            for ph in phases {
                if frame < acc + ph.dur { return (ph.name, (frame - acc) / max(ph.dur, 1)) }
                acc += ph.dur
            }
            return ("done", 1)
        }

        let startTime = Date()
        Timer.scheduledTimer(withTimeInterval: 1.0/fps, repeats: true) { timer in
            let frame = Date().timeIntervalSince(startTime) * fps
            if frame > totalFrames + 10 {
                timer.invalidate()
                withAnimation(.easeOut(duration: 0.1)) { charY = 0; scaleX = 1; scaleY = 1 }
                animating = false
                return
            }

            let (phase, t) = stateAt(frame)
            let et = ease(min(t, 1))
            var y: Double = 0
            var sx: Double = 1, sy: Double = 1

            switch phase {
            case "squat":
                sy = lerp(1, p.squatScale, et); sx = lerp(1, 1/p.squatScale, et)
            case "launch":
                sy = lerp(p.squatScale, p.launchScale, et); sx = lerp(1/p.squatScale, 1/p.launchScale, et)
                y = lerp(0, 5, et)
            case "ascent":
                y = lerp(5, p.jumpHeight, et); sy = lerp(p.launchScale, 1, et); sx = lerp(1/p.launchScale, 1, et)
            case "apex":
                y = p.jumpHeight
            case "descent":
                let de = p.features.asymGrav ? pow(t, 1/p.fallMult) : et
                y = lerp(p.jumpHeight, 5, de)
                let str = 1 + (p.launchScale - 1) * 0.5
                sy = lerp(1, str, t * 0.4); sx = lerp(1, 1/str, t * 0.4)
            case "land":
                y = lerp(5, 0, et); sy = lerp(1, p.landScale, et); sx = lerp(1, 1/p.landScale, et)
            case "landing":
                sy = lerp(p.landScale, 1, et); sx = lerp(1/p.landScale, 1, et)
            default: break
            }

            charY = CGFloat(y)
            scaleX = CGFloat(sx)
            scaleY = CGFloat(sy)
        }
    }
}

// MARK: - Slider helpers

struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let decimals: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            Slider(value: $value, in: range, step: step)
            Text(decimals == 0 ? "\(Int(value))" : String(format: "%.\(decimals)f", value))
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
    }
}

struct LabeledToggle: View {
    let label: String
    @Binding var value: Bool

    var body: some View {
        Toggle(label, isOn: $value)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
    }
}

// MARK: - QR sheet

struct QRShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

struct PresetQRView: View {
    let preset: Preset
    @State private var showShare = false
    @State private var importText = ""
    @State private var importError = false
    @Environment(\.dismiss) var dismiss

    var qrImage: UIImage? {
        guard let encoded = try? preset.params.encoded() else { return nil }
        let payload = "{\"n\":\"\(preset.name)\",\"d\":\(encoded)}"
        return generateQR(from: payload)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Export") {
                    if let img = qrImage {
                        VStack(spacing: 12) {
                            Image(uiImage: img)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(maxWidth: 220)
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(8)
                            Button {
                                showShare = true
                            } label: {
                                Label("Share image", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }

                Section("Import from scan") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste scanned JSON below (or integrate AVFoundation QR scanning for camera input):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $importText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 80)
                        if importError {
                            Text("Invalid preset data — check the pasted JSON.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(preset.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                if let img = qrImage { QRShareSheet(image: img) }
            }
        }
    }
}

// MARK: - Params editor

struct ParamsEditorView: View {
    @Binding var params: JumpParams

    var body: some View {
        Group {
            Section("Timing (frames)") {
                LabeledSlider(label: "Squat frames",   value: $params.squatFrames,   range: 0...10,  step: 1, decimals: 0)
                LabeledSlider(label: "Ascent frames",  value: $params.ascentFrames,  range: 4...30,  step: 1, decimals: 0)
                LabeledSlider(label: "Apex float",     value: $params.apexFrames,    range: 0...8,   step: 1, decimals: 0)
                LabeledSlider(label: "Descent frames", value: $params.descentFrames, range: 4...30,  step: 1, decimals: 0)
                LabeledSlider(label: "Landing frames", value: $params.landingFrames, range: 1...10,  step: 1, decimals: 0)
            }
            Section("Jump height") {
                LabeledSlider(label: "Height (pt)",    value: $params.jumpHeight,    range: 10...90, step: 1, decimals: 0)
            }
            Section("Squash & stretch") {
                LabeledSlider(label: "Squat compress", value: $params.squatScale,    range: 0.5...1.0,  step: 0.05, decimals: 2)
                LabeledSlider(label: "Launch stretch", value: $params.launchScale,   range: 1.0...2.0,  step: 0.05, decimals: 2)
                LabeledSlider(label: "Land squash",    value: $params.landScale,     range: 0.3...1.0,  step: 0.05, decimals: 2)
            }
            Section("Feel tweaks") {
                LabeledToggle(label: "Coyote time",         value: $params.features.coyoteTime)
                LabeledSlider(label: "Coyote frames",       value: $params.coyoteFrames, range: 1...10, step: 1, decimals: 0)
                LabeledToggle(label: "Jump buffering",      value: $params.features.jumpBuffer)
                LabeledSlider(label: "Buffer frames",       value: $params.bufferFrames, range: 1...10, step: 1, decimals: 0)
                LabeledToggle(label: "Variable jump height",value: $params.features.variableJump)
                LabeledToggle(label: "Asymmetric gravity",  value: $params.features.asymGrav)
                LabeledSlider(label: "Fall multiplier",     value: $params.fallMult, range: 1.0...3.0, step: 0.1, decimals: 2)
                LabeledToggle(label: "Apex grav reduction", value: $params.features.apexGrav)
                LabeledSlider(label: "Apex grav factor",    value: $params.apexGravFactor, range: 0.1...1.0, step: 0.05, decimals: 2)
            }
        }
    }
}

// MARK: - Main content view

struct ContentView: View {
    @StateObject private var store = PresetStore()
    @State private var params = JumpParams()
    @State private var presetName = ""
    @State private var selectedQRPreset: Preset?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    JumpPreviewView(params: params)
                        .listRowInsets(.init(top: 8, leading: 8, bottom: 8, trailing: 8))
                }

                ParamsEditorView(params: $params)

                Section("Presets") {
                    HStack {
                        TextField("Preset name…", text: $presetName)
                            .textFieldStyle(.roundedBorder)
                        Button("Save") {
                            guard !presetName.isEmpty else { return }
                            store.save(Preset(name: presetName, params: params))
                            presetName = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(presetName.isEmpty)
                    }

                    if store.presets.isEmpty {
                        Text("No presets saved yet")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    ForEach(store.presets) { preset in
                        HStack {
                            Text(preset.name)
                                .font(.system(size: 14))
                            Spacer()
                            Button("Load") {
                                params = preset.params
                            }
                            .font(.system(size: 12))
                            .buttonStyle(.bordered)
                            Button {
                                selectedQRPreset = preset
                            } label: {
                                Image(systemName: "qrcode")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .onDelete { offsets in store.delete(at: offsets) }
                }
            }
            .navigationTitle("Jump Tuner")
            .toolbar {
                EditButton()
            }
            .sheet(item: $selectedQRPreset) { preset in
                PresetQRView(preset: preset)
            }
        }
    }
}

// MARK: - App entry point

@main
struct JumpTunerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
