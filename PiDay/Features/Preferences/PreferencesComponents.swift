import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Section header style
// ─────────────────────────────────────────────────────────────────────────────

// WHY a ViewModifier for section headers: each section header adds an SF Symbol
// for visual hierarchy. The modifier keeps every call site to a single chained call
// instead of repeating the same font/color/case stack in five places.
extension View {
    func prefSectionHeader() -> some View {
        modifier(PrefSectionHeaderModifier())
    }
}

private struct PrefSectionHeaderModifier: ViewModifier {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .font(.footnote.weight(.semibold))
            .foregroundStyle(preferences.resolvedPalette.paneSecondaryText(for: colorScheme))
            .textCase(.uppercase)
            .listRowInsets(.init(top: 22, leading: 4, bottom: 6, trailing: 0))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ThemeSwatchButton
// ─────────────────────────────────────────────────────────────────────────────

// A compact tile that communicates a theme's identity at a glance:
//   • Background fill           — the theme surface colour
//   • π wordmark in accent      — shows the primary accent
//   • DD·MM·YY with three tints — shows the digit colour coding
//   • Checkmark badge           — confirms the active selection
//
// WHY 72 × 90 pt: tall enough to show three rows of info, narrow enough
// that six tiles fit across a 390 pt screen without horizontal scrolling.
struct ThemeSwatchButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let customAccent: Color
    let onTap: () -> Void

    private var p: ThemePalette { theme.palette(customAccent: customAccent) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                tileBody
                    .frame(width: 72, height: 90)
                    // WHY darker shadow on dark tiles: dark-background tiles need more
                    // shadow intensity to lift off the sheet; light tiles stay subtle.
                    .shadow(
                        color: Color.black.opacity(isSelected
                            ? (theme.isDark ? 0.40 : 0.22)
                            : (theme.isDark ? 0.20 : 0.09)),
                        radius: isSelected ? 10 : 4,
                        y: isSelected ? 5 : 2
                    )

                Text(theme.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) theme\(isSelected ? ", selected" : "")")
    }

    private var tileBody: some View {
        ZStack(alignment: .topTrailing) {
            // Background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(p.background)

            // Border — thicker and accent-coloured when selected
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isSelected ? p.accent : p.ink.opacity(0.12),
                    lineWidth: isSelected ? 2.5 : 1
                )

            // Content
            VStack(spacing: 5) {
                // π in accent — the brand colour identity
                Text("π")
                    .font(.system(size: 20, weight: .black, design: .serif))
                    .italic()
                    .foregroundStyle(p.accent)

                // Mini date with colour-coded segments
                HStack(spacing: 0) {
                    Text("14").foregroundStyle(p.day)
                    Text("·").foregroundStyle(p.mutedInk.opacity(0.6))
                    Text("03").foregroundStyle(p.month)
                    Text("·").foregroundStyle(p.mutedInk.opacity(0.6))
                    Text("26").foregroundStyle(p.year)
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
            }

            // Selection checkmark — top-right badge
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(p.accent)
                    // White backing ensures legibility on any background
                    .background(
                        Circle().fill(p.background).padding(-2)
                    )
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Scale spring on selection communicates the tap meaningfully
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ColourCodingRow
// ─────────────────────────────────────────────────────────────────────────────

// One row per digit segment (Day / Month / Year).
// Shows a filled circle swatch, a label, and sample digits in that colour
// rendered in the user's chosen font style — so typography and colour are
// both visible simultaneously in this one section.
struct ColourCodingRow: View {
    let label: String
    let color: Color
    let sample: String
    let fontStyle: AppFontStyle
    let fontWeight: AppFontWeight

    var body: some View {
        HStack(spacing: 14) {
            // Filled swatch circle — immediately reads as a colour key
            Circle()
                .fill(color)
                .frame(width: 26, height: 26)
                .overlay(
                    // Subtle ring ensures legibility on pure-white list backgrounds
                    Circle().strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                )

            Text(label)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            // Digits rendered in both the colour AND the user's font style
            Text(sample)
                .font(fontStyle.font(size: 17, weight: fontWeight.fontWeight))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - FontStyleButton
// ─────────────────────────────────────────────────────────────────────────────

// Each button renders its own label in the font it represents.
// WHY self-demonstrating labels: users can judge "Rounded" vs "Serif" vs "Mono"
// instantly without reading documentation. The letterforms are the preview.
struct FontStyleButton: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    let style: AppFontStyle
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        let palette = preferences.resolvedPalette

        Button(action: onTap) {
            Text(style.displayName)
                .font(style.font(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : palette.panePrimaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected
                              ? palette.accent
                              : palette.paneSurfaceFill(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke((isSelected ? palette.accent.opacity(0.30) : palette.paneBorder(for: colorScheme)) as Color, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(style.displayName) font\(isSelected ? ", selected" : "")")
    }
}

struct AppearanceModeButton: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    let mode: AppAppearanceMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        let palette = preferences.resolvedPalette

        Button(action: onTap) {
            Text(mode.displayName)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : palette.panePrimaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? palette.accent : palette.paneSurfaceFill(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke((isSelected ? palette.accent.opacity(0.30) : palette.paneBorder(for: colorScheme)) as Color, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.displayName) appearance\(isSelected ? ", selected" : "")")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DigitSizeButton
// ─────────────────────────────────────────────────────────────────────────────

// S / M / L buttons where the label itself scales with the size it represents.
// WHY growing labels: the button becomes a tiny data visualisation — you feel
// the size difference before you read the letter.
struct DigitSizeButton: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    let size: DigitSize
    let isSelected: Bool
    let onTap: () -> Void

    // Each label grows proportionally with the size it represents.
    // WHY different frame widths: "XL"/"XXL" are wider strings than "S"/"M"/"L".
    private var labelFontSize: CGFloat {
        switch size {
        case .small:  return 13
        case .medium: return 17
        case .large:  return 22
        case .xl:     return 18
        case .xxl:    return 16
        }
    }

    private var buttonWidth: CGFloat {
        switch size {
        case .small, .medium, .large: return 52
        case .xl:   return 58
        case .xxl:  return 68
        }
    }

    var body: some View {
        let palette = preferences.resolvedPalette

        Button(action: onTap) {
            Text(size.displayName)
                .font(.system(size: labelFontSize, weight: isSelected ? .bold : .regular, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : palette.panePrimaryText(for: colorScheme))
                .frame(width: buttonWidth, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(isSelected
                              ? palette.accent
                              : palette.paneSurfaceFill(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke((isSelected ? palette.accent.opacity(0.30) : palette.paneBorder(for: colorScheme)) as Color, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(size.displayName) digit size\(isSelected ? ", selected" : "")")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DigitPreviewCard
// ─────────────────────────────────────────────────────────────────────────────

// A live preview tile showing "14 · 03 · 2026" in the user's chosen font
// and size, with theme-aware segment colours.
//
// WHY a distinct card (not inline text): the raised surface gives the preview
// its own visual context — it reads as "this is how your canvas will look",
// not "this is part of the settings form". The distinction matters.
struct DigitPreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let fontStyle: AppFontStyle
    let fontWeight: AppFontWeight
    let digitSize: DigitSize
    let palette: ThemePalette

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Group {
                Text("14").foregroundStyle(palette.day)
                + Text(" · ").foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                + Text("03").foregroundStyle(palette.month)
                + Text(" · ").foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                + Text("2026").foregroundStyle(palette.year)
            }
            .font(fontStyle.font(size: digitSize.previewFontSize, weight: fontWeight.fontWeight))
            Spacer()
        }
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 14, palette: palette)
        // All three typography controls animate together so the card previews feel alive.
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: digitSize.rawValue)
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: fontStyle.rawValue)
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: fontWeight.rawValue)
    }
}

struct FontWeightSliderRow: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    let selection: AppFontWeight
    let onChange: (AppFontWeight) -> Void
    let previewFont: (CGFloat, Font.Weight) -> Font

    private var sliderValue: Binding<Double> {
        Binding(
            get: { Double(selection.rawValue) },
            set: { onChange(AppFontWeight.fromSliderValue($0)) }
        )
    }

    var body: some View {
        let palette = preferences.resolvedPalette

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Weight")
                    .font(.subheadline)
                    .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                Spacer()
                Text(selection.displayName)
                    .font(previewFont(14, selection.fontWeight))
                    .foregroundStyle(palette.panePrimaryText(for: colorScheme))
            }

            Slider(value: sliderValue, in: 0...8, step: 1)

            HStack {
                Text("Light")
                Spacer()
                Text("Regular")
                Spacer()
                Text("Black")
            }
            .font(.caption2)
            .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Font weight")
        .accessibilityValue(selection.displayName)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PrefPickerRow  (generic inline-labelled picker)
// ─────────────────────────────────────────────────────────────────────────────

// A reusable labelled Picker row for List contexts.
// WHY generic over T: the same row works for SearchFormatPreference,
// IndexingConvention, or any future Identifiable+Hashable enum without
// duplicating layout code.
struct PrefPickerRow<T: Hashable & Identifiable>: View {
    let title: String
    let options: [T]
    let label: (T) -> String
    @Binding var selection: T

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options) { option in
                Text(label(option)).tag(option)
            }
        }
    }
}
