// JumpPreviewView.swift
//
// Full-screen animated preview of the jump cycle, powered by SpriteKit.
//
// JumpScene owns the physics simulation and character. This view wraps it in
// SpriteView and overlays the SwiftUI play/loop controls on top.

import SwiftUI
import SpriteKit

// MARK: - Stars background

/// Decorative starfield and planet layer rendered behind the robot.
///
/// Stars and planets are generated once at max capacity so positions stay
/// stable as more elements are revealed. `SkyProgress` controls how many
/// are currently visible. `TimelineView` drives continuous right-to-left
/// scrolling by offsetting each star's x position from the current timestamp.
struct StarsView: View {
    var progress: SkyProgress = SkyProgress(jumpCount: 0)

    // Pre-generate max capacity; reveal subset based on progress.
    @State private var stars: [(CGFloat, CGFloat, CGFloat, Double)] =
        (0..<SkyProgress.maxStars).map { _ in
            (CGFloat.random(in: 0...1),
             CGFloat.random(in: 0...0.9),
             CGFloat.random(in: 1...3),
             Double.random(in: 0.3...0.8))
        }

    // Planets: fixed positions, distinct colors, larger sizes.
    @State private var planets: [(CGFloat, CGFloat, CGFloat, Color)] =
        (0..<SkyProgress.maxPlanets).map { _ in
            (CGFloat.random(in: 0.05...0.95),
             CGFloat.random(in: 0.05...0.55),
             CGFloat.random(in: 10...22),
             [Color(red: 0.8, green: 0.5, blue: 0.3),
              Color(red: 0.4, green: 0.6, blue: 0.9),
              Color(red: 0.7, green: 0.8, blue: 0.5)].randomElement()!)
        }

    private let scrollSpeed: CGFloat     = 30   // stars scroll speed (pts/sec)
    private let planetScrollSpeed: CGFloat = 8  // planets scroll slower (parallax)

    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { geo in
                let elapsed = CGFloat(context.date.timeIntervalSinceReferenceDate)
                let starOffset   = (elapsed * scrollSpeed).truncatingRemainder(dividingBy: geo.size.width)
                let planetOffset = (elapsed * planetScrollSpeed).truncatingRemainder(dividingBy: geo.size.width)

                // Stars
                ForEach(0..<progress.visibleStars, id: \.self) { i in
                    let x = (stars[i].0 * geo.size.width - starOffset + geo.size.width)
                        .truncatingRemainder(dividingBy: geo.size.width)
                    Circle()
                        .fill(Color.white.opacity(stars[i].3))
                        .frame(width: stars[i].2, height: stars[i].2)
                        .position(x: x, y: stars[i].1 * geo.size.height)
                }

                // Planets — scroll at a slower rate for depth
                ForEach(0..<progress.visiblePlanets, id: \.self) { i in
                    let x = (planets[i].0 * geo.size.width - planetOffset + geo.size.width)
                        .truncatingRemainder(dividingBy: geo.size.width)
                    Circle()
                        .fill(planets[i].3.opacity(0.75))
                        .frame(width: planets[i].2, height: planets[i].2)
                        .position(x: x, y: planets[i].1 * geo.size.height)
                }
            }
        }
    }
}

// MARK: - Jump preview

struct JumpPreviewView: View {
    @Binding var params: JumpParams
    @Binding var jumpTrigger: Int
    @Binding var showParamText: Bool

    @State private var looping: Bool = false
    @State private var animating: Bool = false
    @State private var selectedSkin: CharacterSkin = .robot
    @State private var customSkins: [CharacterSkin] = []
    @State private var showingPhotoPicker = false

    @State private var scene: JumpScene = {
        let s = JumpScene()
        s.scaleMode = .resizeFill
        return s
    }()

    private var allSkins: [CharacterSkin] { CharacterSkin.builtIn + customSkins }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                SpriteView(scene: scene)
                    .ignoresSafeArea()

                // Controls — top bar
                VStack(alignment: .leading, spacing: 8) {
                    // Row 1: playback controls
                    HStack(spacing: 10) {
                        // Loop toggle
                        Button {
                            looping.toggle()
                            scene.isLooping = looping
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(looping
                                          ? Color.groundColor.opacity(0.3)
                                          : Color.white.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(looping
                                                    ? Color.groundColor
                                                    : Color.white.opacity(0.3),
                                                    lineWidth: 1.5)
                                    )
                                    .frame(width: 42, height: 32)
                                Image(systemName: "repeat")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(
                                        looping ? Color.groundColor : .white.opacity(0.7)
                                    )
                            }
                        }
                        .buttonStyle(.plain)

                        // Play / stop
                        ControllerButton(isPlaying: animating) {
                            if animating {
                                animating = false
                                scene.stopJumping()
                            } else {
                                animating = true
                                scene.triggerJump()
                            }
                        }

                        Spacer()
                    }

                    // Row 2: character picker — wraps horizontally
                    ChipFlowView(allSkins: allSkins, selectedSkin: selectedSkin) { skin in
                        selectedSkin = skin
                        scene.setCharacter(skin)
                    } onAdd: {
                        showingPhotoPicker = true
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 16)
                .padding(.top, 56)
                Spacer()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .characterPhotoFlow(isPresented: $showingPhotoPicker) { newSkin in
            customSkins.append(newSkin)
            selectedSkin = newSkin
            scene.setCharacter(newSkin)
        }
        .onChange(of: params) {
            scene.params = params
        }
        .onChange(of: jumpTrigger) {
            animating = true
            scene.triggerJump()
        }
        .onChange(of: showParamText) {
            scene.showFloatingText = showParamText
        }
    }
}

// MARK: - Chip flow layout

private struct ChipFlowView: View {
    let allSkins: [CharacterSkin]
    let selectedSkin: CharacterSkin
    let onSelect: (CharacterSkin) -> Void
    let onAdd: () -> Void

    var body: some View {
        WrapLayout(hSpacing: 6, vSpacing: 6) {
            ForEach(allSkins) { skin in
                SkinChip(skin: skin, isSelected: skin.id == selectedSkin.id) {
                    onSelect(skin)
                }
            }
            Button(action: onAdd) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

/// Wrapping flow layout using the Layout protocol (iOS 16+).
private struct WrapLayout: Layout {
    var hSpacing: CGFloat = 6
    var vSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowH = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowH
            if i < rows.count - 1 { height += vSpacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowH = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            for idx in row {
                let size = subviews[idx].sizeThatFits(.unspecified)
                subviews[idx].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + hSpacing
            }
            y += rowH + vSpacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        let maxW = proposal.width ?? .infinity
        var rows: [[Int]] = [[]]
        var rowWidth: CGFloat = 0
        for (i, subview) in subviews.enumerated() {
            let w = subview.sizeThatFits(.unspecified).width
            if !rows[rows.count - 1].isEmpty, rowWidth + w > maxW {
                rows.append([i])
                rowWidth = w + hSpacing
            } else {
                rows[rows.count - 1].append(i)
                rowWidth += w + hSpacing
            }
        }
        return rows
    }
}

// MARK: - Skin chip

private struct SkinChip: View {
    let skin: CharacterSkin
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(skin.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white.opacity(0.75))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.white.opacity(0.90) : Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.white : Color.white.opacity(0.25),
                                        lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    JumpPreviewView(params: .constant(.defaults), jumpTrigger: .constant(0), showParamText: .constant(true))
        .ignoresSafeArea()
}
