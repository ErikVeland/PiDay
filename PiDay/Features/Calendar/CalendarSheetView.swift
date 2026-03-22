import SwiftUI
import ContactsUI

// WHY: Extracting the calendar sheet into its own file makes it independently
// navigable. Day cell rendering, heat-map logic, and accessibility labels are
// all co-located here — not scattered through a 900-line ContentView.

struct CalendarSheetView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    @State private var hapticTrigger = false
    @State private var showBirthdayPicker = false
    @State private var partialBirthday: PartialBirthday? = nil

    @ScaledMetric private var dayCellSize: CGFloat = 46
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

    var body: some View {
        let palette = preferences.resolvedPalette

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection(palette: palette)
                    gridSection(palette: palette)
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background {
                // WHY conditional: on iOS 26 sheets already provide the native Liquid Glass
                // material. Setting a custom background overrides it and loses the frosted
                // depth. On iOS < 26 we still need to paint our theme colour.
                if #available(iOS 26, *) { } else {
                    palette.background.ignoresSafeArea()
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") { viewModel.jumpToToday() }
                        .font(.body.weight(.semibold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .preferredColorScheme(preferences.resolvedPreferredColorScheme)
        .sensoryFeedback(.selection, trigger: hapticTrigger)
        // WHY .background for the picker: ContactPickerPresenter is an invisible
        // UIViewController host. Attaching it as a background keeps it in the view
        // hierarchy without contributing any visual space or layout influence.
        .background(
            ContactPickerPresenter(isPresented: $showBirthdayPicker, onContact: handleContact)
        )
        // Year prompt — only shown when a contact's birthday has no year stored.
        .sheet(item: $partialBirthday) { partial in
            BirthdayYearPromptView(partial: partial) { date in
                viewModel.selectBirthday(date)
                isPresented = false
            }
            .environment(viewModel)
            .environment(preferences)
            .presentationDetents([.medium])
        }
    }

    // MARK: - Sections

    private func headerSection(palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.monthSection.monthTitle)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(palette.panePrimaryText(for: colorScheme))

                    Text(viewModel.isDisplayedMonthInBundledRange
                         ? "Choose a day to center its sequence in pi."
                         : "Heat map is unavailable for this month. Pick a day to run a live lookup instead.")
                        .font(.subheadline)
                        .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                }

                Spacer()

                HStack(spacing: 10) {
                    birthdayButton(palette: palette)
                    monthControl(systemName: "chevron.left", palette: palette, action: viewModel.showPreviousMonth)
                    monthControl(systemName: "chevron.right", palette: palette, action: viewModel.showNextMonth)
                }
            }

            HStack(spacing: 12) {
                calendarBadge(title: "Selected", value: shortDate(viewModel.selectedDate), palette: palette)
                calendarBadge(
                    title: viewModel.isDisplayedMonthInBundledRange ? "Format" : "Lookup",
                    value: viewModel.isDisplayedMonthInBundledRange ? viewModel.searchPreference.title : "Live only",
                    palette: palette
                )
            }
        }
        .padding(20)
        // WHY glassCard: uses palette-aware surface on iOS < 26 (fixing the dark-theme
        // bug where hardcoded Color.white looked wrong) and Liquid Glass on iOS 26+.
        .glassCard(cornerRadius: 28, palette: palette)
    }

    private func gridSection(palette: ThemePalette) -> some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.monthSection.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                        .frame(maxWidth: .infinity)
                }

                ForEach(viewModel.monthSection.days) { day in
                    dayCell(for: day, palette: palette)
                }
            }

            legendRow(palette: palette)
        }
        .padding(18)
        .glassCard(cornerRadius: 32, palette: palette)
        // WHY id + transition: keying on displayedMonth forces SwiftUI to replace
        // the grid view when the month changes, which plays the asymmetric slide
        // transition. Without an id change SwiftUI diffs in-place (no transition).
        .id(viewModel.displayedMonth)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: viewModel.displayedMonth)
    }

    private func legendRow(palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // WHY directional layout: "Earlier in Pi" conveys that hot = rare/early,
            // which is non-obvious. Bare colour dots with labels don't communicate
            // the ordering relationship — the arrow cues do.
            HStack(spacing: 0) {
                Text("Not found")
                    .font(.caption2)
                    .foregroundStyle(palette.paneSecondaryText(for: colorScheme))

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Text("Later")
                        .font(.caption2)
                        .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                    legendDot(palette.heatNone,  palette: palette)
                    legendDot(palette.heatFaint, palette: palette)
                    legendDot(palette.heatCool,  palette: palette)
                    legendDot(palette.heatWarm,  palette: palette)
                    legendDot(palette.heatHot,   palette: palette)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                    Text("Earlier in π")
                        .font(.caption2)
                        .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }
            }

            Text("Based on earliest position in the first 5 billion digits.")
                .font(.caption2)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
        }
        .padding(.top, 4)
    }

    // WHY no label param: dots are now unlabelled in the directional flow;
    // context is provided by the surrounding "Later → Earlier" text.
    // WHY accessibilityHidden: the dots are decorative — the surrounding
    // "Later → Earlier in π" text already conveys the full semantic meaning.
    // Exposing unlabelled coloured circles to VoiceOver adds focus noise.
    private func legendDot(_ color: Color, palette: ThemePalette) -> some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .accessibilityHidden(true)
    }

    // MARK: - Day cell

    private func dayCell(for day: CalendarDay, palette: ThemePalette) -> some View {
        let summary = viewModel.daySummaries[day.date]
        let heatLevel = summary?.heatLevel ?? .none
        let isToday = day.isInDisplayedMonth && day.date == viewModel.today

        return Button {
            viewModel.select(day.date)
            hapticTrigger.toggle()
            isPresented = false
        } label: {
            ZStack {
                Circle()
                    .fill(dayBackground(for: day, heatLevel: heatLevel, summary: summary, palette: palette))
                    .frame(width: dayCellSize, height: dayCellSize)
                    .overlay(
                        Circle()
                            .strokeBorder(summary?.isSelected == true ? PiPalette.selectionStroke : .clear, lineWidth: 1.5)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(isToday && summary?.isSelected != true ? palette.accent.opacity(0.55) : .clear, lineWidth: 2)
                    )

                Text("\(day.dayNumber)")
                    .font(.system(.body, design: .rounded).weight(summary?.isSelected == true ? .bold : .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
            .foregroundStyle(dayForeground(for: day, summary: summary, palette: palette))
        }
        .buttonStyle(.plain)
        .disabled(!day.isInDisplayedMonth)
        .accessibilityLabel(dayCellAccessibilityLabel(for: day, heatLevel: heatLevel, summary: summary))
        // WHY accessibilityHidden for out-of-month days: a disabled button with an
        // empty label still receives VoiceOver focus and announces nothing useful.
        // Hiding it entirely gives screen-reader users a clean 7-column grid.
        .accessibilityHidden(!day.isInDisplayedMonth)
    }

    private func dayCellAccessibilityLabel(for day: CalendarDay, heatLevel: PiHeatLevel, summary: DaySummary?) -> String {
        guard day.isInDisplayedMonth else { return "" }
        let dateStr = Self.longDateFormatter.string(from: day.date)
        let todayStr = day.date == viewModel.today ? ", today" : ""
        let selected = summary?.isSelected == true ? ", selected" : ""
        if summary?.isInBundledRange == false {
            return "\(dateStr)\(todayStr)\(selected), live lookup only"
        }
        let heat: String
        switch heatLevel {
        case .none:   heat = ", not found in pi"
        case .faint:  heat = ", found late in pi"
        case .cool:   heat = ", found in pi"
        case .warm:   heat = ", found early in pi"
        case .hot:    heat = ", found very early in pi"
        }
        return "\(dateStr)\(todayStr)\(selected)\(heat)"
    }

    private func dayBackground(for day: CalendarDay, heatLevel: PiHeatLevel, summary: DaySummary?, palette: ThemePalette) -> AnyShapeStyle {
        if !day.isInDisplayedMonth {
            return AnyShapeStyle(
                colorScheme == .dark
                    ? Color.white.opacity(0.10)
                    : palette.heatOutOfMonth
            )
        }
        if summary?.isSelected == true { return AnyShapeStyle(PiPalette.selectedFill) }
        if summary?.isInBundledRange == false {
            return AnyShapeStyle(
                colorScheme == .dark
                    ? Color.white.opacity(0.06)
                    : palette.heatOutOfMonth.opacity(0.75)
            )
        }

        if colorScheme == .dark {
            switch heatLevel {
            case .none:
                return AnyShapeStyle(Color.white.opacity(0.10))
            case .faint:
                return AnyShapeStyle(palette.accent.opacity(0.18))
            case .cool:
                return AnyShapeStyle(palette.accent.opacity(0.28))
            case .warm:
                return AnyShapeStyle(palette.day.opacity(0.26))
            case .hot:
                return AnyShapeStyle(palette.day.opacity(0.38))
            }
        }

        switch heatLevel {
        case .none:  return AnyShapeStyle(palette.heatNone)
        case .faint: return AnyShapeStyle(palette.heatFaint)
        case .cool:  return AnyShapeStyle(palette.heatCool)
        case .warm:  return AnyShapeStyle(palette.heatWarm)
        case .hot:   return AnyShapeStyle(palette.heatHot)
        }
    }

    private func dayForeground(for day: CalendarDay, summary: DaySummary?, palette: ThemePalette) -> Color {
        if !day.isInDisplayedMonth {
            return colorScheme == .dark
                ? Color(UIColor.tertiaryLabel)
                : palette.heatOutOfMonthForeground
        }
        if summary?.isSelected == true { return .white }
        if summary?.isInBundledRange == false {
            return palette.paneSecondaryText(for: colorScheme)
        }
        return palette.panePrimaryText(for: colorScheme)
    }

    // MARK: - Support views

    // WHY gift icon: universally understood symbol for "birthday present" — no label
    // needed. The icon doubles as a subtle hint that this is for birthdays specifically.
    private func birthdayButton(palette: ThemePalette) -> some View {
        Button { showBirthdayPicker = true } label: {
            Image(systemName: "gift")
                .font(.system(size: 15, weight: .bold))
                .frame(width: 44, height: 44)
        }
        .modifier(NativeGlassButtonModifier())
        .foregroundStyle(palette.panePrimaryText(for: colorScheme))
        .accessibilityLabel("Look up birthday from contacts")
    }

    // Handles the contact returned by the picker.
    // WHY guard month + day before year: a birthday with only a year is not useful —
    // we need at least month and day to identify the date. If both are present but year
    // is nil, we show the year prompt. If all three are present, we jump directly.
    private func handleContact(_ contact: CNContact) {
        guard let bday = contact.birthday,
              let month = bday.month,
              let day   = bday.day else { return }

        if let year = bday.year {
            var comps       = DateComponents()
            comps.year      = year
            comps.month     = month
            comps.day       = day
            // WHY gregorian: birthday components from CNDateComponents are in the
            // Gregorian calendar. Using Calendar.current (which could be Buddhist,
            // Hebrew, or Islamic on some devices) would produce an incorrect date.
            guard let date  = Calendar(identifier: .gregorian).date(from: comps) else { return }
            viewModel.selectBirthday(date)
            isPresented = false
        } else {
            // Year absent — prompt the user to supply it.
            partialBirthday = PartialBirthday(month: month, day: day)
        }
    }

    private func monthControl(systemName: String, palette: ThemePalette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                // WHY 44×44: Apple HIG minimum tap target. Previously 34×34.
                .frame(width: 44, height: 44)
        }
        .modifier(NativeGlassButtonModifier())
        .foregroundStyle(palette.panePrimaryText(for: colorScheme))
    }

    private func calendarBadge(title: String, value: String, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Capsule(style: .continuous).fill(palette.paneSurfaceFill(for: colorScheme)))
    }

    // MARK: - Formatters

    private static let longDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private func shortDate(_ date: Date) -> String {
        Self.shortDateFormatter.string(from: date)
    }
}
