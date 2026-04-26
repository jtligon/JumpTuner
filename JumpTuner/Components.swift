// Components.swift
// Shared UI primitives: sliders, toggles, collapsible section header,
// and the controller-style play button.

import SwiftUI

// MARK: - Labeled slider

struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let decimals: Int
    var color: Color = .accentColor

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 118, alignment: .leading)
            Slider(value: $value, in: range, step: step)
                .tint(color)
            Text(decimals == 0
                 ? "\(Int(value))"
                 : String(format: "%.\(decimals)f", value))
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundColor(color)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }
}

// MARK: - Labeled toggle

struct LabeledToggle: View {
    let label: String
    @Binding var value: Bool
    var color: Color = .accentColor

    var body: some View {
        Toggle(label, isOn: $value)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .tint(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
    }
}

// MARK: - Collapsible section

struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color
    @State private var expanded: Bool
    @ViewBuilder let content: () -> Content

    init(title: String, icon: String, accentColor: Color,
         startExpanded: Bool = false,
         @ViewBuilder content: @escaping () -> Content) {
        self.title       = title
        self.icon        = icon
        self.accentColor = accentColor
        self._expanded   = State(initialValue: startExpanded)
        self.content     = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(width: 22)
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Color(.secondarySystemGroupedBackground))
            }
            .buttonStyle(.plain)

            // Expandable content
            if expanded {
                VStack(spacing: 0) { content() }
                    .background(Color(.systemGroupedBackground))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Controller-style play button

struct ControllerButton: View {
    let isPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
                    )
                    .frame(width: 58, height: 32)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 48, height: 22)
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(
                        isPlaying ? Color(red: 1, green: 0.4, blue: 0.4) : .white
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Slider") {
    VStack {
        LabeledSlider(label: "Ascent frames", value: .constant(11),
                      range: 4...30, step: 1, decimals: 0,
                      color: SectionTheme.timing)
        LabeledSlider(label: "Squat compress", value: .constant(0.7),
                      range: 0.5...1.0, step: 0.05, decimals: 2,
                      color: SectionTheme.squash)
    }
    .padding()
}

#Preview("Toggle") {
    LabeledToggle(label: "Coyote time", value: .constant(true),
                  color: SectionTheme.feel)
        .padding()
}

#Preview("Collapsible section") {
    CollapsibleSection(title: "Timing", icon: "timer",
                       accentColor: SectionTheme.timing,
                       startExpanded: true) {
        LabeledSlider(label: "Squat frames", value: .constant(3),
                      range: 0...10, step: 1, decimals: 0,
                      color: SectionTheme.timing)
        LabeledSlider(label: "Ascent frames", value: .constant(11),
                      range: 4...30, step: 1, decimals: 0,
                      color: SectionTheme.timing)
    }
    .padding()
}

#Preview("Controller button") {
    HStack(spacing: 20) {
        ControllerButton(isPlaying: false, onTap: {})
        ControllerButton(isPlaying: true, onTap: {})
    }
    .padding()
    .background(Color.skyBottom)
}
