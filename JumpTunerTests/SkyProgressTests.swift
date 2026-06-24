// SkyProgressTests.swift
// Tests for SkyProgress: maps jump loop count to sky content visibility.

import Testing
@testable import JumpTuner

@Suite("SkyProgress")
@MainActor
struct SkyProgressTests {

    // MARK: Stars

    @Test func baselineStarsAtZeroJumps() {
        let s = SkyProgress(jumpCount: 0)
        #expect(s.visibleStars == 45)
    }

    @Test func starsGrowWithJumpCount() {
        let s = SkyProgress(jumpCount: 10)
        #expect(s.visibleStars == 55)
    }

    @Test func starsCappedAtMaximum() {
        let s = SkyProgress(jumpCount: 1000)
        #expect(s.visibleStars == SkyProgress.maxStars)
    }

    @Test func starsNeverBelowBaseline() {
        let s = SkyProgress(jumpCount: 0)
        #expect(s.visibleStars >= 45)
    }

    // MARK: Planets

    @Test func noPlanetsAtStart() {
        let s = SkyProgress(jumpCount: 0)
        #expect(s.visiblePlanets == 0)
    }

    @Test func noPlanetsBeforeThreshold() {
        let s = SkyProgress(jumpCount: 9)
        #expect(s.visiblePlanets == 0)
    }

    @Test func firstPlanetAppearsAtThreshold() {
        let s = SkyProgress(jumpCount: 10)
        #expect(s.visiblePlanets == 1)
    }

    @Test func secondPlanetAppearsAfterInterval() {
        let s = SkyProgress(jumpCount: 25)
        #expect(s.visiblePlanets == 2)
    }

    @Test func thirdPlanetAppearsAfterInterval() {
        let s = SkyProgress(jumpCount: 40)
        #expect(s.visiblePlanets == 3)
    }

    @Test func planetsCappedAtMaximum() {
        let s = SkyProgress(jumpCount: 1000)
        #expect(s.visiblePlanets == SkyProgress.maxPlanets)
    }

    // MARK: Constants

    @Test func maxStarsIsAtLeastBaseline() {
        #expect(SkyProgress.maxStars >= 45)
    }

    @Test func maxPlanetsIsPositive() {
        #expect(SkyProgress.maxPlanets > 0)
    }
}
