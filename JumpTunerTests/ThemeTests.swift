// ThemeTests.swift
// Exercises all static color constants in Theme.swift to ensure coverage.

import Testing
import SwiftUI
@testable import JumpTuner

@Suite("Theme")
@MainActor
struct ThemeTests {

    @Test func sceneColorsAreDefined() {
        _ = Color.groundColor
        _ = Color.skyTop
        _ = Color.skyBottom
        _ = Color.robotBody
        _ = Color.robotAccent
    }

    @Test func sectionThemeColorsAreDefined() {
        _ = SectionTheme.timing
        _ = SectionTheme.height
        _ = SectionTheme.squash
        _ = SectionTheme.feel
        _ = SectionTheme.presets
    }
}
