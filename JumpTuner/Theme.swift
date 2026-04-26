// Theme.swift
//
// Centralized color and theme constants for JumpTuner.
//
// All colors are defined here so that a visual redesign touches exactly
// one file. Views import these via the Color extension and SectionTheme enum
// rather than hardcoding hex values inline.

import SwiftUI

// MARK: - Scene colors

extension Color {
    /// Ground platform color — mint green, visible against the dark sky.
    static let groundColor = Color(red: 0.20, green: 0.78, blue: 0.55)

    /// Top of the sky gradient — deep indigo.
    static let skyTop      = Color(red: 0.13, green: 0.09, blue: 0.30)

    /// Bottom of the sky gradient — mid purple, transitions into ground.
    static let skyBottom   = Color(red: 0.22, green: 0.16, blue: 0.48)

    /// Robot body fill color — warm yellow, high contrast against the sky.
    static let robotBody   = Color(red: 0.95, green: 0.82, blue: 0.25)

    /// Robot outline and accent color — orange, complements the yellow body.
    static let robotAccent = Color(red: 1.00, green: 0.45, blue: 0.20)
}

// MARK: - Section accent colors

/// Accent colors for the five collapsible parameter sections.
/// Each section gets a distinct hue so the drawer is scannable at a glance.
enum SectionTheme {
    /// Timing section — cool blue.
    static let timing  = Color(red: 0.38, green: 0.70, blue: 1.00)

    /// Jump height section — amber yellow.
    static let height  = Color(red: 0.95, green: 0.82, blue: 0.20)

    /// Squash & stretch section — warm pink/red.
    static let squash  = Color(red: 1.00, green: 0.45, blue: 0.55)

    /// Feel tweaks section — mint green (matches ground color family).
    static let feel    = Color(red: 0.45, green: 0.90, blue: 0.65)

    /// Presets section — soft purple.
    static let presets = Color(red: 0.75, green: 0.55, blue: 1.00)
}
