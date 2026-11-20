// RunCycleTests.swift
// Tests for the shared run animation and each character's run figure.

import Testing
import SpriteKit
@testable import JumpTuner

@Suite("RunCycle")
@MainActor
struct RunCycleTests {

    @Test func poseTablesCoverTheWholeCycle() {
        #expect(RunCycle.legs.count == RunCycle.frameCount)
        #expect(RunCycle.arms.count == RunCycle.frameCount)
    }

    @Test func consecutiveLegFramesAreDifferentPoses() {
        let legs = RunCycle.legs
        for i in legs.indices {
            let next = legs[(i + 1) % legs.count]
            #expect(legs[i].root != next.root || legs[i].joint != next.joint)
        }
    }

    /// Covers the leg lengths used by the robot, rabbit and pirate.
    @Test(arguments: [7.0, 6.5, 10.5] as [CGFloat])
    func feetNeverSinkBelowTheGround(legSegment: CGFloat) {
        let count = RunCycle.frameCount
        for frame in 0..<count {
            let near = RunCycle.footHeight(RunCycle.legs[frame], legSegment: legSegment)
            let far  = RunCycle.footHeight(RunCycle.legs[(frame + count / 2) % count], legSegment: legSegment)
            let bob  = RunCycle.bob(frame: frame, legSegment: legSegment)
            #expect(min(near, far) + bob >= -0.15, "frame \(frame)")
        }
    }

    @Test func runningJumpStaysOnTheRunFigure() {
        for skin in CharacterSkin.builtIn {
            let node = skin.make()
            let standing = node.children.filter { !$0.isHidden }
            node.setRunning(true)
            let running = node.children.filter { !$0.isHidden }

            for phase: JumpPhase in [.squat, .ascending, .apex, .descending, .landing, .idle] {
                node.setPhase(phase)
                let standingHidden = standing.allSatisfy { $0.isHidden }
                let runningShown = running.allSatisfy { !$0.isHidden }
                #expect(standingHidden, "\(skin.name) \(phase)")
                #expect(runningShown, "\(skin.name) \(phase)")
            }
        }
    }

    @Test func everyJumpPhaseExceptIdleHasAPose() {
        for phase: JumpPhase in [.squat, .ascending, .apex, .descending, .landing] {
            #expect(RunCycle.jumpPose(for: phase) != nil, "\(phase)")
        }
        #expect(RunCycle.jumpPose(for: .idle) == nil)
    }

    @Test func eachBuiltInCharacterSwapsToItsRunFigure() {
        for skin in CharacterSkin.builtIn {
            let node = skin.make()
            let standing = node.children.filter { !$0.isHidden }
            #expect(standing.count == 1, "\(skin.name)")

            node.setRunning(true)
            node.setRunning(true)
            let standingHidden = standing.allSatisfy { $0.isHidden }
            #expect(standingHidden, "\(skin.name) still standing")
            let running = node.children.filter { !$0.isHidden }
            #expect(running.count == 1, "\(skin.name)")

            node.setRunning(false)
            let standingShown = standing.allSatisfy { !$0.isHidden }
            let runningHidden = running.allSatisfy { $0.isHidden }
            #expect(standingShown, "\(skin.name) did not stand back up")
            #expect(runningHidden, "\(skin.name) still running")
        }
    }
}

@Suite("RunCycle pacing")
@MainActor
struct RunCyclePacingTests {

    private let robotLeg: CGFloat = 7

    @Test func autoRunSpeedPlaysAtNormalPace() {
        #expect(RunCycle.playbackRate(groundSpeed: 120, legSegment: robotLeg) == 1)
    }

    @Test func paceIsProportionalToSpeed() {
        #expect(RunCycle.playbackRate(groundSpeed: 180, legSegment: robotLeg) == 1.5)
        #expect(RunCycle.playbackRate(groundSpeed: 90, legSegment: robotLeg) == 0.75)
    }

    @Test func movingLeftPacesTheSameAsMovingRight() {
        #expect(RunCycle.playbackRate(groundSpeed: -90, legSegment: robotLeg)
                == RunCycle.playbackRate(groundSpeed: 90, legSegment: robotLeg))
    }

    @Test func longerLegsTakeSlowerStrides() {
        let rabbit = RunCycle.playbackRate(groundSpeed: 120, legSegment: 6.5)
        let robot  = RunCycle.playbackRate(groundSpeed: 120, legSegment: 7)
        let pirate = RunCycle.playbackRate(groundSpeed: 120, legSegment: 10.5)
        #expect(pirate < robot && robot < rabbit)
    }

    @Test func lightestPushStillMovesTheLegs() {
        #expect(RunCycle.playbackRate(groundSpeed: 1, legSegment: robotLeg) == RunCycle.minimumPlaybackRate)
    }

    private func makeRig() -> RunRig {
        let rig = RunRig(legSegment: robotLeg, standHipY: 10, leanDegrees: 9)
        func limb() -> RunLimb { RunLimb(length: 6, width: 4, fill: .white, stroke: .white) }
        rig.addLegs(far: limb(), near: limb(), farX: 0, nearX: 0)
        rig.addFarArm(limb(), at: .zero)
        rig.addNearArm(limb(), at: .zero)
        return rig
    }

    @Test func speedChangesApplyToARunningCycle() {
        let rig = makeRig()
        rig.setRunning(true, hiding: SKNode())
        rig.setGroundSpeed(180)
        #expect(rig.action(forKey: "runCycle")?.speed == 1.5)
    }

    @Test func speedSetBeforeRunningIsUsedWhenTheCycleStarts() {
        let rig = makeRig()
        rig.setGroundSpeed(60)
        rig.setRunning(true, hiding: SKNode())
        #expect(rig.action(forKey: "runCycle")?.speed == 0.5)
    }
}
