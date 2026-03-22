import SwiftUI

// WHY: The detail sheet is the primary result surface for the selected date.
// Layout: date title → result cards → Share/Search/Saved row → Appearance → Reminder.
// Format and indexing pickers live in Preferences only (no duplication).

struct DetailSheetView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Binding var isPresented: Bool
    @State private var showSavedDates = false
    @State private var showFreeSearch = false
    @State private var navigateToPreferences = false

    var body: some View {
        let palette = preferences.resolvedPalette

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(formattedDate(viewModel.selectedDate))
                        .font(.title.weight(.black))
                        .foregroundStyle(palette.panePrimaryText(for: colorScheme))

                    if let match = viewModel.bestMatch {
                        HStack(spacing: 12) {
                            detailCard(title: match.format.displayName, body: viewModel.exactQuery, palette: palette)
                            positionCard(for: match, palette: palette)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if let errorMessage = viewModel.errorMessage {
                        lookupErrorCard(message: errorMessage, palette: palette)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if !viewModel.isLoading {
                        // WHY explicit not-found card: without it the space between the date
                        // title and the reminder card is an unexplained gap that reads as a bug.
                        notFoundCard(palette: palette)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Share · Search · Saved — three equal-width actions in one row.
                    // WHY row not stack: these are peer actions, not a ranked list.
                    // WHY no separate bookmark button here: the toolbar already has
                    // a bookmark toggle; a second one in this row was redundant and
                    // appeared as a blank/icon-only button that confused users.
                    HStack(spacing: 8) {
                        ShareLink(
                            item: viewModel.shareableCard(palette: palette),
                            preview: SharePreview("PiDay", image: Image(systemName: "chart.bar.doc.horizontal"))
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(palette.accent)
                        .disabled(viewModel.isLoading || viewModel.errorMessage != nil)

                        Button { showFreeSearch = true } label: {
                            Label("Search", systemImage: "magnifyingglass")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(palette.accent)

                        Button { showSavedDates = true } label: {
                            Label("Saved", systemImage: "bookmark")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(palette.accent)
                    }

                    Button {
                        navigateToPreferences = true
                    } label: {
                        Label("Appearance & Preferences", systemImage: "paintpalette")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(palette.accent)

                    // Reminder lives last — it's a one-time setup action, not a
                    // primary interaction, so it shouldn't compete with the result cards.
                    reminderCard(palette: palette)
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity, alignment: .top)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.bestMatch != nil)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.isLoading)
            }
            .background {
                if #available(iOS 26, *) { } else {
                    palette.background.ignoresSafeArea()
                }
            }
            .navigationTitle(formattedDate(viewModel.selectedDate))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // WHY bookmark leading / gear trailing: iOS 26 groups multiple items
                // on the same side into one wide glass pill instead of individual
                // circles. Keeping one button per side forces the OS to size each
                // glass shape around just that icon.
                ToolbarItem(placement: .topBarLeading) {
                    // Bookmark toggle — save or unsave the currently selected date.
                    Button {
                        viewModel.toggleSaveCurrentDate()
                    } label: {
                        // WHY symbolEffect replace: animates the fill/empty transition
                        // on the bookmark icon so the state change feels intentional.
                        Image(systemName: viewModel.isCurrentDateSaved ? "bookmark.fill" : "bookmark")
                            .frame(width: 24, height: 24)
                            .contentTransition(.symbolEffect(.replace.offUp))
                            .foregroundStyle(viewModel.isCurrentDateSaved ? palette.accent : palette.paneSecondaryText(for: colorScheme))
                    }
                    .accessibilityLabel(viewModel.isCurrentDateSaved ? "Remove saved date" : "Save date")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navigateToPreferences = true
                    } label: {
                        Image(systemName: "gearshape")
                            .frame(width: 24, height: 24)
                            .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                    }
                    .accessibilityLabel("Preferences")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
            .sheet(isPresented: $showSavedDates) {
                SavedDatesView(isPresented: $showSavedDates)
                    .environment(viewModel)
                    .environment(preferences)
            }
            .sheet(isPresented: $showFreeSearch) {
                FreeSearchView()
                    .environment(viewModel)
                    .environment(preferences)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            // WHY navigationDestination (not sheet): avoids sheet-within-sheet nesting.
            // @Environment(\.dismiss) in PreferencesView works for both push and sheet contexts.
            .navigationDestination(isPresented: $navigateToPreferences) {
                PreferencesView()
                    .environment(viewModel)
                    .environment(preferences)
            }
        }
        // WHY preferredColorScheme here: sheets don't always inherit the window-level
        // override, especially when opened from within another sheet. This ensures
        // system colours (.primary/.secondary, nav bars) match the theme's intent.
        .preferredColorScheme(preferences.resolvedPreferredColorScheme)
    }

    // MARK: - Cards

    // WHY palette parameter (not re-derived inside): the caller already holds
    // `let palette = preferences.resolvedPalette` from body. Re-deriving it in
    // every sub-function adds redundant struct construction per render pass.
    // Separate card for position so AnimatedCounterView can roll the digits.
    private func positionCard(for match: BestPiMatch, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Position")
                .font(.headline)
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))

            HStack(spacing: 0) {
                Text("digit ")
                AnimatedCounterView(target: viewModel.displayedPosition(for: match.storedPosition))
            }
            .font(.body)
            .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
            .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20, palette: palette)
    }

    private func detailCard(title: String, body: String, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))

            Text(body)
                .font(.body)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20, palette: palette)
    }

    private func notFoundCard(palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Not found in pi", systemImage: "magnifyingglass")
                .font(.headline)
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))

            Text(
                viewModel.isSelectedDateInRange
                    ? "This date does not appear as an exact sequence in the first 5 billion digits of pi."
                    : "This date is outside the bundled search range (\(viewModel.indexedYearRange))."
            )
            .font(.subheadline)
            .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20, palette: palette)
    }

    private func lookupErrorCard(message: String, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "wifi.exclamationmark")
                .font(.subheadline)
                .foregroundStyle(PiPalette.error)

            Button {
                viewModel.retryCurrentLookup()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(palette.accent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20, palette: palette)
    }

    private func reminderCard(palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pi Day Reminder")
                .font(.headline)
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))

            Text(reminderStatusText)
                .font(.subheadline)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    if viewModel.notificationAuthState == .denied {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            openURL(settingsURL)
                        }
                    } else {
                        let newState = await NotificationService.requestAndSchedulePiDay()
                        viewModel.notificationAuthState = newState
                    }
                }
            } label: {
                Label(reminderButtonTitle, systemImage: "bell.badge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            // WHY disabled when authorized: tapping "Reminder enabled" would
            // silently re-request an already-granted permission with no visible effect.
            .disabled(viewModel.notificationAuthState == .authorized)
        }
        .compactSectionCard()
    }

    private var reminderStatusText: String {
        switch viewModel.notificationAuthState {
        case .authorized:
            return "Annual reminder scheduled for March 14 at 9:14 AM."
        case .denied:
            return "Notifications are off for PiDay. Re-enable them in Settings if you want a yearly reminder."
        case .notDetermined:
            return "Turn on a yearly Pi Day reminder after you decide you want it."
        }
    }

    private var reminderButtonTitle: String {
        switch viewModel.notificationAuthState {
        case .authorized:
            return "Reminder enabled"
        case .denied:
            return "Open Settings to enable"
        case .notDetermined:
            return "Enable reminder"
        }
    }

    private static let longDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        return f
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.longDateFormatter.string(from: date)
    }
}
