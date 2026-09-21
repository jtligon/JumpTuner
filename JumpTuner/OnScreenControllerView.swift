// OnScreenControllerView.swift
// Landscape-mode overlay: virtual thumbstick (left) + jump button (right).

import SwiftUI

// MARK: - Thumbstick

struct ThumbstickView: View {
    /// Normalized horizontal output: -1 (full left) to +1 (full right).
    var onMove: (CGFloat) -> Void

    private let baseRadius: CGFloat = 52
    private let knobRadius: CGFloat = 28

    @State private var knobOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        ZStack {
            // Base ring
            Circle()
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 2)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .frame(width: baseRadius * 2, height: baseRadius * 2)

            // Knob
            Circle()
                .fill(Color.white.opacity(isDragging ? 0.55 : 0.35))
                .frame(width: knobRadius * 2, height: knobRadius * 2)
                .offset(knobOffset)
        }
        .frame(width: baseRadius * 2, height: baseRadius * 2)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    let translation = value.translation
                    let dist = sqrt(translation.width * translation.width + translation.height * translation.height)
                    let clampedDist = min(dist, baseRadius - knobRadius)
                    let angle = atan2(translation.height, translation.width)
                    knobOffset = CGSize(
                        width:  clampedDist * cos(angle),
                        height: clampedDist * sin(angle)
                    )
                    let raw = knobOffset.width / (baseRadius - knobRadius)
                    let normalizedX = max(-1, min(1, raw))
                    onMove(normalizedX)
                }
                .onEnded { _ in
                    isDragging = false
                    knobOffset = .zero
                    onMove(0)
                }
        )
    }
}

// MARK: - Jump button

struct JumpButtonView: View {
    var onPress: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            onPress()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isPressed ? 0.40 : 0.20))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 2))
                    .frame(width: 80, height: 80)
                Text("JUMP")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Full controller overlay

struct OnScreenControllerView: View {
    /// Called when the thumbstick moves; value is -1…+1 normalized.
    var onMove: (CGFloat) -> Void
    /// Called when the jump button is tapped.
    var onJump: () -> Void

    var body: some View {
        HStack {
            ThumbstickView(onMove: onMove)
                .padding(.leading, 40)
                .padding(.bottom, 32)

            Spacer()

            JumpButtonView(onPress: onJump)
                .padding(.trailing, 40)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(true)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OnScreenControllerView(onMove: { _ in }, onJump: { })
    }
}
