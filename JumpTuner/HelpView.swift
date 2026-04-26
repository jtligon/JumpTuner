// HelpView.swift
//
// In-app reference guide explaining what every parameter does to game feel.
// Presented as a sheet from an info button in the drawer header.

import SwiftUI

// MARK: - Data

private struct HelpSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let items: [HelpItem]
}

private struct HelpItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let tip: String?
}

private let helpSections: [HelpSection] = [
    HelpSection(
        title: "Timing", icon: "timer", color: SectionTheme.timing,
        items: [
            HelpItem(name: "Squat frames",
                     description: "How long the character crouches before jumping. Adds visual anticipation and telegraphs the jump to the player.",
                     tip: "0 frames = instant, snappy jumps. 4–6 frames = deliberate, heavy feel."),
            HelpItem(name: "Ascent frames",
                     description: "Duration of the rising arc. More frames = slower, floatier ascent.",
                     tip: "Classic platformers use 10–14 frames. Longer than descent by design."),
            HelpItem(name: "Apex float",
                     description: "Extra frames spent hovering at the peak before falling. Even 1–2 frames significantly improves player control at the top.",
                     tip: "Combine with Apex gravity reduction for maximum floatiness."),
            HelpItem(name: "Descent frames",
                     description: "Duration of the falling arc. Usually shorter than ascent — gravity should feel like it's pulling harder on the way down.",
                     tip: "Enable Asymmetric gravity for more control over the speed difference."),
            HelpItem(name: "Landing frames",
                     description: "How long the impact squash pose holds before snapping back to idle.",
                     tip: "2–4 frames is barely noticeable but adds satisfying weight. 8+ frames looks exaggerated."),
        ]
    ),
    HelpSection(
        title: "Jump height", icon: "arrow.up", color: SectionTheme.height,
        items: [
            HelpItem(name: "Height",
                     description: "Normalized jump height on a 0–500 scale. Mapped proportionally to screen height so it looks correct on any device.",
                     tip: "100 ≈ one quarter of the screen. 500 = nearly full screen height."),
        ]
    ),
    HelpSection(
        title: "Squash & stretch", icon: "square.resize", color: SectionTheme.squash,
        items: [
            HelpItem(name: "Squat compress",
                     description: "Vertical scale during the anticipation crouch. Values below 1.0 compress the character downward. Horizontal scale is inversely linked to preserve volume.",
                     tip: "0.7 is subtle but readable. Below 0.5 starts to look cartoony."),
            HelpItem(name: "Launch stretch",
                     description: "Vertical scale on the launch frame. Elongates the character upward to sell the speed of takeoff.",
                     tip: "1.4–1.6 is the classic animation sweet spot. Above 2.0 is extremely stylized."),
            HelpItem(name: "Land squash",
                     description: "Vertical compression on ground contact. Combined with the landing frames duration, this sells the physical impact.",
                     tip: "Match this to your squat compress value for visual consistency."),
        ]
    ),
    HelpSection(
        title: "Feel tweaks", icon: "wand.and.stars", color: SectionTheme.feel,
        items: [
            HelpItem(name: "Coyote time",
                     description: "Lets the player jump for a brief window after walking off a ledge. Named after the Wile E. Coyote effect — prevents the frustrating feeling of 'I pressed jump but I was one pixel past the edge.'",
                     tip: "4–6 frames is invisible to players but dramatically reduces frustration."),
            HelpItem(name: "Jump buffering",
                     description: "Remembers a jump input pressed just before landing and fires it automatically on ground contact. Makes rapid repeated jumping feel snappy.",
                     tip: "3–5 frames is the standard. Too high and it fires unexpectedly."),
            HelpItem(name: "Variable jump height",
                     description: "Releasing the jump button early cuts upward velocity, producing a shorter arc. Holding through the apex yields full height. Essential for skill-expressive platformers.",
                     tip: "This is the single biggest feel improvement you can make to a platformer."),
            HelpItem(name: "Asymmetric gravity",
                     description: "Applies a gravity multiplier during descent, making falling faster than rising. Produces a more satisfying, weighty arc without changing the ascent feel.",
                     tip: nil),
            HelpItem(name: "Fall multiplier",
                     description: "How much faster gravity pulls during descent. Uses a power curve: pow(t, 1/fallMult) bows the easing so the character drops quickly then eases into the ground.",
                     tip: "1.5–1.8 is natural. 2.5+ is very snappy/arcade. Requires Asymmetric gravity."),
            HelpItem(name: "Apex gravity reduction",
                     description: "Temporarily weakens gravity at the jump peak, creating a brief 'float' that gives players extra control at the highest point.",
                     tip: "0.3–0.5 is perceptible but not distracting. Combine with 1–2 apex float frames."),
            HelpItem(name: "Apex grav factor",
                     description: "The fraction of normal gravity applied at the apex. 0.1 = almost weightless. 1.0 = no effect (full gravity throughout).",
                     tip: "Requires Apex gravity reduction to be enabled."),
        ]
    ),
]

// MARK: - Views

struct HelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Jump Tuner is a tool for prototyping and sharing platformer jump feel. Adjust the sliders to tune your parameters, preview the result on the robot, then export a preset as a QR code to share with teammates.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("All timing values are in frames at 60 fps.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                ForEach(helpSections) { section in
                    Section {
                        ForEach(section.items) { item in
                            HelpItemRow(item: item, color: section.color)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                                .foregroundColor(section.color)
                            Text(section.title)
                        }
                    }
                }

                Section("Sharing presets") {
                    HelpItemRow(
                        item: HelpItem(
                            name: "QR codes",
                            description: "Each preset can be exported as a QR code image. The payload is a compact JSON string encoding all 13 numeric parameters and 5 feature flags. Scan with any QR reader to get the raw JSON, then paste it into the Import tab to load it.",
                            tip: "Share via AirDrop, Messages, or save to Photos from the share sheet."
                        ),
                        color: SectionTheme.presets
                    )
                }
            }
            .navigationTitle("How it works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct HelpItemRow: View {
    let item: HelpItem
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Text(item.description)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            if let tip = item.tip {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow)
                    Text(tip)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HelpView()
}
