// OnScreenControlsTests.swift
// Tests for the landscape controls and the character movement they drive.

import Testing
import SpriteKit
@testable import JumpTuner

@Suite("OnScreenControls")
@MainActor
struct OnScreenControlsTests {

    private func makeScene() -> JumpScene {
        let scene = JumpScene(size: CGSize(width: 800, height: 400))
        scene.didMove(to: SKView())
        return scene
    }

    @Test func knobFollowsAFingerInsideTheBase() {
        let offset = Joystick.knobOffset(for: CGSize(width: 10, height: -5), radius: 34)
        #expect(offset == CGSize(width: 10, height: -5))
    }

    @Test func knobStopsAtTheEdgeOfTheBase() {
        let offset = Joystick.knobOffset(for: CGSize(width: 300, height: 400), radius: 50)
        #expect(abs(offset.width - 30) < 0.001)
        #expect(abs(offset.height - 40) < 0.001)
    }

    @Test func smallPushesAreIgnored() {
        let input = Joystick.horizontalInput(forKnobOffset: CGSize(width: 4, height: 0), radius: 34)
        #expect(input == 0)
    }

    @Test func fullPushGivesFullInputInEachDirection() {
        #expect(Joystick.horizontalInput(forKnobOffset: CGSize(width: 34, height: 0), radius: 34) == 1)
        #expect(Joystick.horizontalInput(forKnobOffset: CGSize(width: -34, height: 0), radius: 34) == -1)
    }

    @Test func partialPushGivesPartialInput() {
        let input = Joystick.horizontalInput(forKnobOffset: CGSize(width: 17, height: 0), radius: 34)
        #expect(input > 0 && input < 1)
    }

    @Test func pushingStraightUpDoesNotMoveTheCharacter() {
        let input = Joystick.horizontalInput(forKnobOffset: CGSize(width: 0, height: -34), radius: 34)
        #expect(input == 0)
    }

    @Test func aPartialPushMovesMoreSlowlyThanAFullPush() {
        func distance(forInput input: CGFloat) -> CGFloat {
            let scene = makeScene()
            let start = scene.currentCharacterX
            scene.setMoveDirection(input)
            scene.update(1.0)
            scene.update(1.05)
            return scene.currentCharacterX - start
        }
        #expect(abs(distance(forInput: 0.5) - distance(forInput: 1) / 2) < 0.01)
    }

    @Test func holdingRightMovesTheCharacterRight() {
        let scene = makeScene()
        let start = scene.currentCharacterX
        scene.setMoveDirection(1)
        scene.update(1.0)
        scene.update(1.05)
        #expect(scene.currentCharacterX > start)
    }

    @Test func holdingLeftMovesTheCharacterLeft() {
        let scene = makeScene()
        let start = scene.currentCharacterX
        scene.setMoveDirection(-1)
        scene.update(1.0)
        scene.update(1.05)
        #expect(scene.currentCharacterX < start)
    }

    @Test func releasingStopsTheCharacter() {
        let scene = makeScene()
        scene.setMoveDirection(1)
        scene.update(1.0)
        scene.update(1.05)
        scene.setMoveDirection(0)
        let stopped = scene.currentCharacterX
        scene.update(1.1)
        #expect(scene.currentCharacterX == stopped)
    }

    @Test func characterStaysOnScreen() {
        let scene = makeScene()
        scene.setMoveDirection(1)
        for frame in 0..<400 { scene.update(Double(frame) * 0.05) }
        #expect(scene.currentCharacterX <= 800)

        scene.setMoveDirection(-1)
        for frame in 400..<800 { scene.update(Double(frame) * 0.05) }
        #expect(scene.currentCharacterX >= 0)
    }

    @Test func aLongStallDoesNotTeleportTheCharacter() {
        let scene = makeScene()
        let start = scene.currentCharacterX
        scene.setMoveDirection(1)
        scene.update(1.0)
        scene.update(60.0)
        #expect(scene.currentCharacterX - start <= 18.5)
    }

    @Test func clearingReturnsTheCharacterHome() {
        let scene = makeScene()
        let home = scene.currentCharacterX
        scene.setMoveDirection(1)
        scene.update(1.0)
        scene.update(1.05)
        scene.clearManualMovement()
        #expect(scene.currentCharacterX == home)
    }
}
