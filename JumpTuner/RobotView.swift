// RobotView.swift

import SwiftUI

struct RobotView: View {
    let scaleX: CGFloat
    let scaleY: CGFloat
    let phase:  String

    private var armAngle: Double {
        switch phase {
        case "launch", "ascent": return -50
        case "apex":             return -25
        case "descent", "land":  return  25
        default:                 return   0
        }
    }

    private var eyeScale: CGFloat {
        switch phase {
        case "apex":  return 1.5
        case "squat": return 0.5
        default:      return 1.0
        }
    }

    var body: some View {
        ZStack {
            // Body
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.robotBody)
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.robotAccent, lineWidth: 2))
                .frame(width: 20, height: 16)
                .offset(y: 7)

            // Chest detail
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.robotAccent.opacity(0.6))
                .frame(width: 8, height: 5)
                .offset(y: 7)

            // Head
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.robotBody)
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.robotAccent, lineWidth: 2))
                .frame(width: 18, height: 15)
                .offset(y: -6)

            // Eyes
            HStack(spacing: 5) {
                Circle().fill(Color.robotAccent).frame(width: 4, height: 4)
                Circle().fill(Color.robotAccent).frame(width: 4, height: 4)
            }
            .scaleEffect(eyeScale)
            .offset(y: -6)

            // Antenna
            VStack(spacing: 0) {
                Circle().fill(Color.robotAccent).frame(width: 4, height: 4)
                Rectangle().fill(Color.robotAccent).frame(width: 2, height: 5)
            }
            .offset(y: -17)

            // Left arm
            Capsule()
                .fill(Color.robotBody)
                .overlay(Capsule().stroke(Color.robotAccent, lineWidth: 1.5))
                .frame(width: 5, height: 11)
                .rotationEffect(.degrees(armAngle), anchor: .top)
                .offset(x: -14, y: 3)

            // Right arm
            Capsule()
                .fill(Color.robotBody)
                .overlay(Capsule().stroke(Color.robotAccent, lineWidth: 1.5))
                .frame(width: 5, height: 11)
                .rotationEffect(.degrees(-armAngle), anchor: .top)
                .offset(x: 14, y: 3)

            // Left leg
            Capsule()
                .fill(Color.robotBody)
                .overlay(Capsule().stroke(Color.robotAccent, lineWidth: 1.5))
                .frame(width: 5, height: 10)
                .offset(x: -6, y: 19)

            // Right leg
            Capsule()
                .fill(Color.robotBody)
                .overlay(Capsule().stroke(Color.robotAccent, lineWidth: 1.5))
                .frame(width: 5, height: 10)
                .offset(x: 6, y: 19)
        }
        .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
    }
}

#Preview("Idle") {
    RobotView(scaleX: 1, scaleY: 1, phase: "idle")
        .frame(width: 80, height: 80)
        .background(Color.skyBottom)
}

#Preview("All phases") {
    let phases = ["idle", "squat", "launch", "ascent", "apex", "descent", "land", "landing"]
    return ScrollView(.horizontal) {
        HStack(spacing: 24) {
            ForEach(phases, id: \.self) { phase in
                VStack(spacing: 8) {
                    RobotView(scaleX: 1, scaleY: 1, phase: phase)
                        .frame(width: 60, height: 60)
                    Text(phase)
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
    }
    .background(Color.skyBottom)
}
