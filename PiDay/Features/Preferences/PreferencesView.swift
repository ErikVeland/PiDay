import SwiftUI

// ── Layout structure ──────────────────────────────────────────────────────────
//
// NavigationStack
//   └── List (.insetGrouped)
//         ├── Section "Appearance"
//         │     ├── themePickerRow   — horizontal ScrollView of ThemeSwatchButtons,
//         │     │                      listRowInsets(.zero) so tiles bleed to the edge
//         │     └── customAccentRow  — ColorPicker, shown only when theme == .custom
//         │
//         ├── Section "Colour Coding"
//         │     ├── ColourCodingRow  Day
//         │     ├── ColourCodingRow  Month
//         │     └── ColourCodingRow  Year
//         │
//         ├── Section "Typography"
//         │     ├── fontStyleRow     — three FontStyleButtons (Rounded / Serif / Mono)
//         │     ├── digitSizeRow     — three DigitSizeButtons (S / M / L)
//         │     └── DigitPreviewCard — live preview, updates on every tap
//         │
//         ├── Section "Date Format"
//         │     ├── Picker  Search format
//         │     ├── Picker  Indexing convention
//         │     └── footer  explainer text
//         │
//         └── Section "About"
//               ├── LabeledContent  Version
//               └── LabeledContent  Pi index range
//
// WHY List + insetGrouped (not ScrollView + VStack):
//   • insetGrouped gives the exact section-card look iOS Settings uses — free
//   • List handles cell separators, swipe gestures, and keyboard avoidance
//   • The theme swatch row opts out of insets via listRowInsets(.zero);
//     every other row keeps the default 16 pt leading inset automatically

struct PreferencesView: View {
    @Environment(AppViewModel.self)    private var viewModel
    @Environment(PreferencesStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    private let twoColumnGrid = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    // WHY a local computed var (not a let): the palette must re-derive whenever
    // theme or customAccent changes. @Observable re-evaluates body automatically
    // when any accessed store property changes, which re-derives palette too.
    private var palette: ThemePalette { store.resolvedPalette }

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                colourCodingSection
                typographySection
                formatSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            // WHY .tint: FontStyleButton, DigitSizeButton, and Picker views inside
            // the List use Color.accentColor for their selected/active state. Without
            // this, they render in system blue regardless of the active theme.
            .tint(palette.accent)
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .preferredColorScheme(store.resolvedPreferredColorScheme)
    }

    // ── Appearance ────────────────────────────────────────────────────────────

    private var appearanceSection: some View {
        Section {
            themePickerRow
            appearanceModeRow
            if store.theme == .custom {
                customAccentRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        } header: {
            Label("Appearance", systemImage: "paintpalette")
                .prefSectionHeader()
        } footer: {
            Text("Theme controls the palette, while Appearance decides whether PiDay follows system mode or forces light or dark.")
                .font(.footnote)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
        }
    }

    // WHY listRowInsets(.zero) + listRowBackground(.clear):
    // The horizontal scroll must reach the card edge so the swatch tiles feel
    // at home inside the section. Non-zero insets would leave awkward gaps.
    private var themePickerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeSwatchButton(
                        theme: theme,
                        isSelected: store.theme == theme,
                        customAccent: store.customAccent
                    ) {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) {
                            store.theme = theme
                        }
                        store.save()
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private var customAccentRow: some View {
        // supportsOpacity: false — a transparent accent colour breaks against
        // both light and dark backgrounds, so we don't offer that option.
        ColorPicker(
            "Accent Colour",
            selection: Binding(
                get: { store.customAccent },
                set: { store.customAccent = $0; store.save() }
            ),
            supportsOpacity: false
        )
    }

    private var appearanceModeRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
                .font(.subheadline)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))

            HStack(spacing: 10) {
                LazyVGrid(columns: twoColumnGrid, spacing: 10) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        AppearanceModeButton(
                            mode: mode,
                            isSelected: store.appearanceMode == mode
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                                store.appearanceMode = mode
                            }
                            store.save()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // ── Colour Coding ─────────────────────────────────────────────────────────

    private var colourCodingSection: some View {
        Section {
            ColourCodingRow(label: "Day",   color: palette.day,   sample: "14",   fontStyle: store.fontStyle, fontWeight: store.fontWeight)
            ColourCodingRow(label: "Month", color: palette.month, sample: "03",   fontStyle: store.fontStyle, fontWeight: store.fontWeight)
            ColourCodingRow(label: "Year",  color: palette.year,  sample: "2026", fontStyle: store.fontStyle, fontWeight: store.fontWeight)
        } header: {
            Label("Colour Coding", systemImage: "paintbrush.pointed")
                .prefSectionHeader()
        } footer: {
            Text("Each segment of the date uses a distinct colour to help you parse day, month, and year at a glance.")
                .font(.footnote)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
        }
    }

    // ── Typography ────────────────────────────────────────────────────────────

    // WHY one section for both font style and digit size:
    // They're tightly coupled — you want to see how size and typeface interact
    // in the live preview immediately below both controls, not in two separate sections.
    private var typographySection: some View {
        Section {
            fontStyleRow
            fontWeightRow
            digitSizeRow
            DigitPreviewCard(
                fontStyle: store.fontStyle,
                fontWeight: store.fontWeight,
                digitSize: store.digitSize,
                palette: palette
            )
            .listRowBackground(Color.clear)
            .listRowInsets(.init(top: 6, leading: 12, bottom: 10, trailing: 12))
        } header: {
            Label("Typography", systemImage: "textformat")
                .prefSectionHeader()
        } footer: {
            Text("Font and size apply to the digit canvas on the main screen.")
                .font(.footnote)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
        }
    }

    private var fontStyleRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Font Style")
                .font(.subheadline)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))

            LazyVGrid(columns: twoColumnGrid, spacing: 10) {
                ForEach(AppFontStyle.allCases) { style in
                    FontStyleButton(
                        style: style,
                        isSelected: store.fontStyle == style
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                            store.fontStyle = style
                        }
                        store.save()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var digitSizeRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Digit Size")
                .font(.subheadline)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))

            HStack(spacing: 10) {
                ForEach(DigitSize.allCases) { size in
                    DigitSizeButton(
                        size: size,
                        isSelected: store.digitSize == size
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                            store.digitSize = size
                        }
                        store.save()
                    }
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private var fontWeightRow: some View {
        FontWeightSliderRow(
            selection: store.fontWeight,
            onChange: {
                store.fontWeight = $0
                store.save()
            },
            previewFont: { size, weight in
                store.fontStyle.font(size: size, weight: weight)
            }
        )
    }

    // ── Date Format ───────────────────────────────────────────────────────────

    // WHY Binding(get:set:) here (not @Bindable): AppViewModel is injected via
    // @Environment, which returns a non-mutable value. Binding(get:set:) wraps
    // the @Observable property into a SwiftUI Binding without making a copy.
    private var formatSection: some View {
        Section {
            Picker("Format", selection: Binding(
                get: { viewModel.searchPreference },
                set: { viewModel.setSearchPreference($0) }
            )) {
                ForEach(SearchFormatPreference.allCases) { p in
                    Text(p.title).tag(p)
                }
            }

            Picker("Indexing", selection: Binding(
                get: { viewModel.indexingConvention },
                set: { viewModel.setIndexingConvention($0) }
            )) {
                ForEach(IndexingConvention.allCases) { c in
                    Text(c.label).tag(c)
                }
            }
        } header: {
            Label("Date Format", systemImage: "calendar")
                .prefSectionHeader()
        } footer: {
            Text(viewModel.indexingConvention.explainer)
                .font(.footnote)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
        }
    }

    // ── About ─────────────────────────────────────────────────────────────────

    private var aboutSection: some View {
        Section {
            LabeledContent("Version") {
                Text(appVersion)
                    .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
            }
            LabeledContent("Pi index") {
                Text(viewModel.indexedYearRange.isEmpty ? "—" : viewModel.indexedYearRange)
                    .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
            }
        } header: {
            Label("About", systemImage: "info.circle")
                .prefSectionHeader()
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
