// ParamsEditorView.swift

import SwiftUI

struct ParamsEditorView: View {
    @Binding var params: JumpParams

    var body: some View {
        VStack(spacing: 8) {
            CollapsibleSection(title: "Timing", icon: "timer",
                               accentColor: SectionTheme.timing) {
                LabeledSlider(label: "Squat frames",   value: $params.squatFrames,
                              range: 0...10,  step: 1, decimals: 0, color: SectionTheme.timing)
                LabeledSlider(label: "Ascent frames",  value: $params.ascentFrames,
                              range: 4...30,  step: 1, decimals: 0, color: SectionTheme.timing)
                LabeledSlider(label: "Apex float",     value: $params.apexFrames,
                              range: 0...8,   step: 1, decimals: 0, color: SectionTheme.timing)
                LabeledSlider(label: "Descent frames", value: $params.descentFrames,
                              range: 4...30,  step: 1, decimals: 0, color: SectionTheme.timing)
                LabeledSlider(label: "Landing frames", value: $params.landingFrames,
                              range: 1...10,  step: 1, decimals: 0, color: SectionTheme.timing)
            }

            CollapsibleSection(title: "Jump height", icon: "arrow.up",
                               accentColor: SectionTheme.height) {
                LabeledSlider(label: "Height (pt)", value: $params.jumpHeight,
                              range: 10...500, step: 1, decimals: 0, color: SectionTheme.height)
            }

            CollapsibleSection(title: "Squash & stretch", icon: "square.resize",
                               accentColor: SectionTheme.squash) {
                LabeledSlider(label: "Squat compress", value: $params.squatScale,
                              range: 0.5...1.0,  step: 0.05, decimals: 2, color: SectionTheme.squash)
                LabeledSlider(label: "Launch stretch", value: $params.launchScale,
                              range: 1.0...2.0,  step: 0.05, decimals: 2, color: SectionTheme.squash)
                LabeledSlider(label: "Land squash",    value: $params.landScale,
                              range: 0.3...1.0,  step: 0.05, decimals: 2, color: SectionTheme.squash)
            }

            CollapsibleSection(title: "Feel tweaks", icon: "wand.and.stars",
                               accentColor: SectionTheme.feel) {
                LabeledToggle(label: "Coyote time",          value: $params.features.coyoteTime,
                              color: SectionTheme.feel)
                LabeledSlider(label: "Coyote frames",        value: $params.coyoteFrames,
                              range: 1...10,   step: 1,    decimals: 0, color: SectionTheme.feel)
                LabeledToggle(label: "Jump buffering",       value: $params.features.jumpBuffer,
                              color: SectionTheme.feel)
                LabeledSlider(label: "Buffer frames",        value: $params.bufferFrames,
                              range: 1...10,   step: 1,    decimals: 0, color: SectionTheme.feel)
                LabeledToggle(label: "Variable jump height", value: $params.features.variableJump,
                              color: SectionTheme.feel)
                LabeledToggle(label: "Asymmetric gravity",   value: $params.features.asymGrav,
                              color: SectionTheme.feel)
                LabeledSlider(label: "Fall multiplier",      value: $params.fallMult,
                              range: 1.0...3.0, step: 0.1,  decimals: 2, color: SectionTheme.feel)
                LabeledToggle(label: "Apex grav reduction",  value: $params.features.apexGrav,
                              color: SectionTheme.feel)
                LabeledSlider(label: "Apex grav factor",     value: $params.apexGravFactor,
                              range: 0.1...1.0, step: 0.05, decimals: 2, color: SectionTheme.feel)
            }
        }
    }
}

#Preview {
    ScrollView {
        ParamsEditorView(params: .constant(.defaults))
            .padding(.horizontal, 12)
            .padding(.top, 10)
    }
}
