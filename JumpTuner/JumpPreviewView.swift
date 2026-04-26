// JumpPreviewView.swift
//
// Full-screen animated preview of the jump cycle.
//
// ## Animation architecture
//
// The animation runs on a 60fps `Timer` rather than SwiftUI's animation
// system. This is intentional: we need frame-accurate control over the
// physics curve, and SwiftUI's spring/easing animations are designed for
// UI transitions, not game-loop style per-frame computation.
//
// Each jump is a sequence of named phases. The timer computes which phase
// we're in and how far through it (0.0–1.0), then applies the appropriate
// position and squash/stretch transform.
//
// ## Live param updates
//
// `JumpParams` is captured by value at the start of `runCycle()`. When
// `onChange(of: params)` fires mid-animation (e.g. a slider moved or
// randomize was tapped), `restartAnimation()` kills the current timer and
// starts a fresh cycle with the new values. This ensures the loop always
// reflects the current sliders without any stale-capture bugs.

import SwiftUI

// MARK: - Stars background

/// Decorative starfield rendered behind the robot.
/// Stars are generated once as random (x, y, size) triples and held as
/// a `let` constant so they don't re-randomize on re-render.
struct StarsView: View {
    let stars: [(CGFloat, CGFloat, CGFloat)] = (0..<45).map { _ in
        (CGFloat.random(in: 0...1),
         CGFloat.random(in: 0...0.9),
         CGFloat.random(in: 1...3))
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<stars.count, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.3...0.8)))
                    .frame(width: stars[i].2, height: stars[i].2)
                    .position(
                        x: stars[i].0 * geo.size.width,
                        y: stars[i].1 * geo.size.height
                    )
            }
        }
    }
}

// MARK: - Jump preview

struct JumpPreviewView: View {
    /// Two-way binding to the current params. The view reads params for
    /// animation and writes nothing back — it's purely a consumer.
    @Binding var params: JumpParams

    // MARK: Animation state
    @State private var animating: Bool    = false
    @State private var looping:   Bool    = false
    @State private var charY:     CGFloat = 0      // pixels above ground
    @State private var scaleX:    CGFloat = 1      // horizontal squash/stretch
    @State private var scaleY:    CGFloat = 1      // vertical squash/stretch
    @State private var phase:     String  = "idle" // current phase name → robot pose
    @State private var jumpTimer: Timer?  = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Sky gradient
                LinearGradient(
                    colors: [Color.skyTop, Color.skyBottom],
                    startPoint: .top, endPoint: .bottom
                )
                StarsView()

                // Ground strip — a solid line + translucent fill
                VStack(spacing: 0) {
                    Rectangle().fill(Color.groundColor).frame(height: 3)
                    Rectangle().fill(Color.groundColor.opacity(0.25)).frame(height: 28)
                }

                // Robot character — positioned left of center so there's room
                // for the side drawer without obscuring the jump arc.
                // charY is in pixels above the ground line; negate for SwiftUI's
                // coordinate system where y increases downward.
                RobotView(scaleX: scaleX, scaleY: scaleY, phase: phase)
                    .frame(width: 44, height: 44)
                    .offset(x: -geo.size.width * 0.2, y: -(charY + 22))

                // Play + loop controls — top left, always clear of the drawer
                VStack {
                    HStack(spacing: 10) {
                        // Loop toggle
                        Button { looping.toggle() } label: {
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
                            animating ? stopAnimation() : startAnimation()
                        }

                        Spacer()
                    }
                    .padding(.leading, 16)
                    .padding(.top, 56)   // below status bar
                    Spacer()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // When params change while animating, restart the cycle immediately
            // so the loop always reflects current slider values.
            .onChange(of: params) { _ in
                if animating { restartAnimation() }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Animation control

    func stopAnimation() {
        jumpTimer?.invalidate(); jumpTimer = nil
        animating = false; phase = "idle"
        charY = 0; scaleX = 1; scaleY = 1
    }

    func restartAnimation() {
        jumpTimer?.invalidate(); jumpTimer = nil
        runCycle()
    }

    func startAnimation() {
        guard !animating else { return }
        animating = true
        runCycle()
    }

    // MARK: - Core animation loop

    /// Runs one complete jump cycle using a 60fps Timer.
    ///
    /// Params are captured by value at entry so slider changes mid-cycle
    /// don't corrupt the in-progress jump. `onChange` triggers a fresh
    /// `runCycle()` call when params change.
    private func runCycle() {
        let p = params

        // Scale jumpHeight (0–500) to actual usable screen pixels.
        // This ensures the slider value means the same thing visually
        // on any device size.
        let screenH = Double(UIScreen.main.bounds.height)
        let groundClearance = 60.0   // ground strip height + robot foot offset
        let maxPixels = screenH - groundClearance
        let scaledHeight = (p.jumpHeight / 500.0) * maxPixels

        // Each phase has a name (used to drive robot arm/eye poses) and
        // a duration in frames at 60fps.
        struct PhaseStep { let name: String; let dur: Double }
        let steps: [PhaseStep] = [
            .init(name: "squat",   dur: p.squatFrames),   // anticipation crouch
            .init(name: "launch",  dur: 2),                // leaving the ground
            .init(name: "ascent",  dur: p.ascentFrames),  // rising arc
            .init(name: "apex",    dur: p.apexFrames),    // float at peak
            .init(name: "descent", dur: p.descentFrames), // falling arc
            .init(name: "land",    dur: 2),                // ground contact
            .init(name: "landing", dur: p.landingFrames), // impact squash hold
            .init(name: "recover", dur: 4),                // return to idle
        ]
        let total = steps.reduce(0.0) { $0 + $1.dur }

        // Smoothstep easing — accelerates in, decelerates out.
        // Used for position and scale interpolation within each phase.
        func ease(_ t: Double) -> Double { t < 0.5 ? 2*t*t : -1+(4-2*t)*t }

        // Linear interpolation helper.
        func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b-a)*t }

        // Returns (phaseName, localT) for a given absolute frame number.
        func stateAt(_ f: Double) -> (String, Double) {
            var acc = 0.0
            for s in steps {
                if f < acc + s.dur { return (s.name, (f - acc) / max(s.dur, 1)) }
                acc += s.dur
            }
            return ("done", 1)
        }

        let start = Date()
        let t = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { tmr in
            let frame = Date().timeIntervalSince(start) * 60.0

            // Cycle complete
            if frame > total + 6 {
                tmr.invalidate()
                charY = 0; scaleX = 1; scaleY = 1; phase = "idle"
                if looping {
                    // Brief pause between loops for readability
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        if animating { runCycle() }
                    }
                } else {
                    animating = false
                }
                return
            }

            let (ph, tv) = stateAt(frame)
            phase = ph
            let et = ease(min(tv, 1))
            var y = 0.0, sx = 1.0, sy = 1.0

            switch ph {
            case "squat":
                // Compress vertically, expand horizontally (volume preservation)
                sy = lerp(1, p.squatScale, et)
                sx = lerp(1, 1/p.squatScale, et)

            case "launch":
                // Transition from squat compression to launch stretch
                sy = lerp(p.squatScale, p.launchScale, et)
                sx = lerp(1/p.squatScale, 1/p.launchScale, et)
                y  = lerp(0, 5, et)   // small initial lift

            case "ascent":
                // Rise to apex; stretch relaxes back to neutral as velocity slows
                y  = lerp(5, scaledHeight, et)
                sy = lerp(p.launchScale, 1, et)
                sx = lerp(1/p.launchScale, 1, et)

            case "apex":
                // Hold at peak height, neutral scale
                y = scaledHeight

            case "descent":
                // Asymmetric gravity: pow(t, 1/fallMult) bows the easing curve
                // so higher fallMult = faster initial drop.
                let de = p.features.asymGrav ? pow(tv, 1/p.fallMult) : et
                y  = lerp(scaledHeight, 5, de)
                // Slight downward stretch during fall
                let str = 1 + (p.launchScale - 1) * 0.5
                sy = lerp(1, str, tv * 0.4)
                sx = lerp(1, 1/str,  tv * 0.4)

            case "land":
                // Snap to ground, begin impact squash
                y  = lerp(5, 0, et)
                sy = lerp(1, p.landScale, et)
                sx = lerp(1, 1/p.landScale, et)

            case "landing":
                // Hold squash then spring back to neutral
                sy = lerp(p.landScale, 1, et)
                sx = lerp(1/p.landScale, 1, et)

            default: break
            }

            charY = CGFloat(y); scaleX = CGFloat(sx); scaleY = CGFloat(sy)
        }
        jumpTimer = t
    }
}

#Preview {
    JumpPreviewView(params: .constant(.defaults))
        .ignoresSafeArea()
}
