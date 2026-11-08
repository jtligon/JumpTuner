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
    @Binding var selectedSkin: CharacterSkin

    @State private var looping: Bool = false
    @State private var animating: Bool = false
    @State private var autoRunning: Bool = false

    @State private var scene: JumpScene = {
        let s = JumpScene()
        s.scaleMode = .resizeFill
        return s
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                SpriteView(scene: scene)
                    .ignoresSafeArea()

                // Controls — vertical rail on the left, clear of the Dynamic
                // Island and the home indicator
                VStack(spacing: 10) {
                    RailToggle(systemImage: "repeat", label: "Loop", isOn: looping) {
                        looping.toggle()
                        scene.isLooping = looping
                    }

                    RailToggle(systemImage: "figure.run", label: "Auto-run", isOn: autoRunning) {
                        autoRunning.toggle()
                        if autoRunning {
                            animating = false
                            scene.startAutoRun()
                        } else {
                            scene.stopAutoRun()
                        }
                    }

                    ControllerButton(isPlaying: animating || autoRunning) {
                        if animating || autoRunning {
                            animating = false
                            autoRunning = false
                            scene.stopAutoRun()
                            scene.stopJumping()
                        } else {
                            animating = true
                            scene.triggerJump()
                        }
                    }
                }
                .padding(.leading, 12)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onChange(of: selectedSkin.id) {
            scene.setCharacter(selectedSkin)
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

// MARK: - Rail buttons

/// On/off control, highlighted in the ground colour while on.
private struct RailToggle: View {
    let systemImage: String
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isOn ? Color.groundColor.opacity(0.3) : Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isOn ? Color.groundColor : Color.white.opacity(0.3), lineWidth: 1.5)
                    )
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isOn ? Color.groundColor : .white.opacity(0.7))
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    JumpPreviewView(params: .constant(.defaults), jumpTrigger: .constant(0), showParamText: .constant(true),
                    selectedSkin: .constant(.robot))
        .ignoresSafeArea()
}
