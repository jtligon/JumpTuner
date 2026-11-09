// OnScreenControlsView.swift
// Translucent joystick and jump button, shown over the preview in landscape.

import SwiftUI

struct OnScreenControlsView: View {
    /// Called with the horizontal input, from -1 (full left) to 1 (full right).
    let onMove: (CGFloat) -> Void
    let onJump: () -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            JoystickView(onMove: onMove)

            Spacer()

            JumpButton(onJump: onJump)
        }
        .onDisappear { onMove(0) }
    }
}

/// The geometry behind the joystick, kept separate so it can be tested.
enum Joystick {
    /// Share of the push radius, around the centre, that counts as no input.
    static let deadZone: CGFloat = 0.15

    /// Where the knob sits for a drag: under the finger, but never outside the base.
    static func knobOffset(for translation: CGSize, radius: CGFloat) -> CGSize {
        let distance = hypot(translation.width, translation.height)
        guard distance > radius else { return translation }
        let scale = radius / distance
        return CGSize(width: translation.width * scale, height: translation.height * scale)
    }

    /// Horizontal input for a knob position, ramping up smoothly from the dead zone.
    static func horizontalInput(forKnobOffset offset: CGSize, radius: CGFloat) -> CGFloat {
        guard radius > 0 else { return 0 }
        let amount = offset.width / radius
        guard abs(amount) > deadZone else { return 0 }
        let scaled = (abs(amount) - deadZone) / (1 - deadZone)
        return min(scaled, 1) * (amount < 0 ? -1 : 1)
    }
}

private struct JoystickView: View {
    let onMove: (CGFloat) -> Void

    private let baseDiameter: CGFloat = 120
    private let knobDiameter: CGFloat = 52
    private var pushRadius: CGFloat { (baseDiameter - knobDiameter) / 2 }

    /// Resets by itself on release, including when the system cancels the touch.
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.2, dampingFraction: 0.7)))
    private var knobOffset = CGSize.zero

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.10))
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))
            Circle()
                .fill(Color.white.opacity(knobOffset == .zero ? 0.28 : 0.42))
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                .frame(width: knobDiameter, height: knobDiameter)
                .offset(knobOffset)
        }
        .frame(width: baseDiameter, height: baseDiameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($knobOffset) { value, state, _ in
                    state = Joystick.knobOffset(for: value.translation, radius: pushRadius)
                }
        )
        .onChange(of: knobOffset) { _, offset in
            onMove(Joystick.horizontalInput(forKnobOffset: offset, radius: pushRadius))
        }
        .accessibilityElement()
        .accessibilityLabel("Movement joystick")
    }
}

/// Fires the moment a finger lands, so a jump never waits for the release.
private struct JumpButton: View {
    let onJump: () -> Void

    private let diameter: CGFloat = 80

    /// Only used to catch touches the system cancels, which skip `onEnded`.
    @GestureState private var isTouching = false
    @State private var isHeld = false

    /// Called straight from the gesture, because a quick tap can begin and end
    /// within one update, too fast for a state change to be observed.
    private func setHeld(_ held: Bool) {
        guard held != isHeld else { return }
        isHeld = held
        if held { onJump() }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(isHeld ? 0.32 : 0.14))
                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
            Image(systemName: "arrow.up")
                .font(.system(size: diameter * 0.32, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isTouching) { _, state, _ in state = true }
                .onChanged { _ in setHeld(true) }
                .onEnded { _ in setHeld(false) }
        )
        .onChange(of: isTouching) { _, touching in
            if !touching { setHeld(false) }
        }
        .accessibilityElement()
        .accessibilityLabel("Jump")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onJump() }
    }
}

#Preview {
    OnScreenControlsView(onMove: { _ in }, onJump: {})
        .padding()
        .background(Color.black)
}
