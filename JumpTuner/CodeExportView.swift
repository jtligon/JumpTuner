// CodeExportView.swift

import SwiftUI

// MARK: - CodeLanguage

enum CodeLanguage: String, CaseIterable {
    case swift    = "Swift"
    case gdscript = "GDScript"
    case csharp   = "C#"
}

// MARK: - CodeExporter

struct CodeExporter {
    let params: JumpParams
    let presetName: String

    func snippet(for language: CodeLanguage) -> String {
        switch language {
        case .swift:    return swift()
        case .gdscript: return gdscript()
        case .csharp:   return csharp()
        }
    }

    // MARK: Swift

    private func swift() -> String {
        let f = params.features
        return """
// Jump preset: "\(presetName)"
let jumpParams = JumpParams(
    squatFrames:    \(num(params.squatFrames)),
    ascentFrames:   \(num(params.ascentFrames)),
    apexFrames:     \(num(params.apexFrames)),
    descentFrames:  \(num(params.descentFrames)),
    landingFrames:  \(num(params.landingFrames)),
    jumpHeight:     \(num(params.jumpHeight)),
    squatScale:     \(num(params.squatScale)),
    launchScale:    \(num(params.launchScale)),
    landScale:      \(num(params.landScale)),
    coyoteFrames:   \(num(params.coyoteFrames)),
    bufferFrames:   \(num(params.bufferFrames)),
    fallMult:       \(num(params.fallMult)),
    apexGravFactor: \(num(params.apexGravFactor)),
    floatFrames:    \(num(params.floatFrames)),
    features: JumpFeatures(
        coyoteTime:   \(f.coyoteTime),
        jumpBuffer:   \(f.jumpBuffer),
        variableJump: \(f.variableJump),
        asymGrav:     \(f.asymGrav),
        apexGrav:     \(f.apexGrav),
        floating:     \(f.floating)
    )
)
"""
    }

    // MARK: GDScript

    private func gdscript() -> String {
        let f = params.features
        return """
# Jump preset: "\(presetName)"
var squat_frames    := \(num(params.squatFrames))
var ascent_frames   := \(num(params.ascentFrames))
var apex_frames     := \(num(params.apexFrames))
var descent_frames  := \(num(params.descentFrames))
var landing_frames  := \(num(params.landingFrames))
var jump_height     := \(num(params.jumpHeight))
var squat_scale     := \(num(params.squatScale))
var launch_scale    := \(num(params.launchScale))
var land_scale      := \(num(params.landScale))
var coyote_frames   := \(num(params.coyoteFrames))
var buffer_frames   := \(num(params.bufferFrames))
var fall_mult       := \(num(params.fallMult))
var apex_grav_factor := \(num(params.apexGravFactor))
var float_frames    := \(num(params.floatFrames))
# Features
var coyote_time   := \(f.coyoteTime)
var jump_buffer   := \(f.jumpBuffer)
var variable_jump := \(f.variableJump)
var asym_grav     := \(f.asymGrav)
var apex_grav     := \(f.apexGrav)
var floating      := \(f.floating)
"""
    }

    // MARK: C#

    private func csharp() -> String {
        let f = params.features
        return """
// Jump preset: "\(presetName)"
var jumpParams = new JumpParams {
    SquatFrames    = \(numf(params.squatFrames)),
    AscentFrames   = \(numf(params.ascentFrames)),
    ApexFrames     = \(numf(params.apexFrames)),
    DescentFrames  = \(numf(params.descentFrames)),
    LandingFrames  = \(numf(params.landingFrames)),
    JumpHeight     = \(numf(params.jumpHeight)),
    SquatScale     = \(numf(params.squatScale)),
    LaunchScale    = \(numf(params.launchScale)),
    LandScale      = \(numf(params.landScale)),
    CoyoteFrames   = \(numf(params.coyoteFrames)),
    BufferFrames   = \(numf(params.bufferFrames)),
    FallMult       = \(numf(params.fallMult)),
    ApexGravFactor = \(numf(params.apexGravFactor)),
    FloatFrames    = \(numf(params.floatFrames)),
    // Features
    CoyoteTime   = \(f.coyoteTime),
    JumpBuffer   = \(f.jumpBuffer),
    VariableJump = \(f.variableJump),
    AsymGrav     = \(f.asymGrav),
    ApexGrav     = \(f.apexGrav),
    Floating     = \(f.floating),
};
"""
    }

    // MARK: Formatting helpers

    private func num(_ v: Double) -> String {
        if v == v.rounded() { return "\(Int(v)).0" }
        var s = String(format: "%.4f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s += "0" }
        return s
    }

    private func numf(_ v: Double) -> String { num(v) + "f" }
}

// MARK: - CodeExportView

struct CodeExportView: View {
    let preset: Preset
    @State private var language: CodeLanguage = .swift
    @State private var showShare = false
    @State private var copied = false
    @Environment(\.dismiss) var dismiss

    private var exporter: CodeExporter {
        CodeExporter(params: preset.params, presetName: preset.name)
    }

    private var snippet: String { exporter.snippet(for: language) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Language", selection: $language) {
                        ForEach(CodeLanguage.allCases, id: \.self) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section("Snippet") {
                    ScrollView([.horizontal, .vertical]) {
                        Text(snippet)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(minHeight: 200)
                }

                Section {
                    Button {
                        UIPasteboard.general.string = snippet
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Label(copied ? "Copied!" : "Copy to clipboard",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .animation(.default, value: copied)

                    Button {
                        showShare = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("Export Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                TextShareSheet(text: snippet)
            }
        }
    }
}

// MARK: - TextShareSheet

struct TextShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview {
    CodeExportView(preset: Preset(name: "Default", params: .defaults))
}
