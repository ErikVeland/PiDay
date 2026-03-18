import SwiftUI

// WHY: Shared color constants used across the app and widget.
// Theme-aware palette tokens live in ThemePalette (AppTheme.swift).
// This file retains only:
//   • background / mutedInk / logoInk / day / month / year  — used by the widget
//   • error                                                  — error states in app views
//   • focusGlow                                              — canvas radial overlay
//   • selectedFill / selectionStroke                         — calendar selected day
enum PiPalette {
    // Frost-theme background — used by the widget containerBackground.
    static let background = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.97, blue: 0.99),
            Color(red: 0.90, green: 0.94, blue: 0.98)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Frost-theme text tokens — used by the widget.
    static let mutedInk = Color(red: 0.39, green: 0.46, blue: 0.55)
    static let logoInk  = Color(red: 0.24, green: 0.29, blue: 0.36).opacity(0.92)

    // Frost-theme digit segment colours — used by the widget.
    static let day   = Color(red: 0.88, green: 0.37, blue: 0.20)
    static let month = Color(red: 0.12, green: 0.57, blue: 0.61)
    static let year  = Color(red: 0.27, green: 0.40, blue: 0.87)

    // Semantic error colour — theme-independent (red reads as "error" on any background).
    static let error = Color(red: 0.85, green: 0.20, blue: 0.22)

    // Canvas ambient glow overlay.
    static let focusGlow = RadialGradient(
        colors: [
            Color.white.opacity(0.0),
            Color.white.opacity(0.12),
            Color(red: 1.0, green: 0.96, blue: 0.89).opacity(0.75),
            Color.white.opacity(0.0)
        ],
        center: .center,
        startRadius: 40,
        endRadius: 420
    )

    // Calendar selected-day fill and stroke — accent-blue gradient that works on all themes.
    static let selectedFill = LinearGradient(
        colors: [Color(red: 0.23, green: 0.50, blue: 0.79), Color(red: 0.18, green: 0.39, blue: 0.66)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let selectionStroke = Color.white.opacity(0.72)
}
