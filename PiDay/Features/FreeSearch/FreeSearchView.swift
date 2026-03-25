import SwiftUI

// WHY: Free search is a self-contained feature — its own ViewModel, its own sheet.
// The user types any digit sequence and sees where it appears in pi.
// It reuses PiLiveLookupService under the hood with no changes to the date lookup flow.

struct FreeSearchView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var searchVM = FreeSearchViewModel()
    @State private var didCopy = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        let palette = preferences.resolvedPalette

        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                inputField(palette: palette)
                resultArea(palette: palette)
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity, alignment: .top)
            .background {
                if #available(iOS 26, *) { } else {
                    palette.background.ignoresSafeArea()
                }
            }
            .navigationTitle("Search Digits in π")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                }
                // WHY keyboard placement: .numberPad has no Return key. Without this,
                // users must reach to the nav bar "Done" button to dismiss the keyboard.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Dismiss") { isInputFocused = false }
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .onAppear { isInputFocused = true }
    }

    // MARK: - Input

    private func inputField(palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // WHY .numberPad keyboard: the API only accepts digits.
                // We also filter in the ViewModel, but the keyboard is
                // the first line of defence against non-digit input.
                TextField("Enter digits…", text: $searchVM.query)
                    .keyboardType(.numberPad)
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                    .focused($isInputFocused)
                    .onChange(of: searchVM.query) { searchVM.queryDidChange() }
                    .accessibilityHint("Type a digit sequence to find where it appears in pi")

                if searchVM.isLoading {
                    ProgressView()
                        .tint(palette.mutedInk)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16, palette: palette)

            if searchVM.query.count < 3 && !searchVM.query.isEmpty {
                Text("Enter at least 3 digits")
                    .font(.caption)
                    .foregroundStyle(palette.mutedInk)
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private func resultArea(palette: ThemePalette) -> some View {
        if let error = searchVM.errorMessage {
            errorCard(message: error, palette: palette)
        } else if let result = searchVM.result {
            resultCard(result, palette: palette)
        } else if searchVM.hasSearched && !searchVM.isLoading {
            notFoundCard(palette: palette)
        } else {
            hintCard(palette: palette)
        }
    }

    private func resultCard(_ result: FreeSearchResult, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Position headline
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Found at digit")
                    .font(.subheadline)
                    .foregroundStyle(palette.mutedInk)
                Text(result.storedPosition.formatted(.number))
                    .font(.title2.weight(.black))
                    .foregroundStyle(palette.ink)
            }

            // Pi digit excerpt with the matched sequence highlighted
            excerptText(result.displayExcerpt, highlight: result.query, palette: palette)
                .font(.system(.callout, design: .monospaced, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Divider()

            Button {
                UIPasteboard.general.string = "\(result.query) at digit \(result.storedPosition)"
                didCopy = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    didCopy = false
                }
            } label: {
                Label(didCopy ? "Copied!" : "Copy result", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(palette.accent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20, palette: palette)
    }

    private func notFoundCard(palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not found")
                .font(.headline)
                .foregroundStyle(palette.ink)
            Text("\"\(searchVM.query)\" does not appear in the first ~5 billion digits of pi.")
                .font(.subheadline)
                .foregroundStyle(palette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20, palette: palette)
    }

    private func errorCard(message: String, palette: ThemePalette) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .foregroundStyle(PiPalette.error)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 20, palette: palette)
    }

    private func hintCard(palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Try your phone number, a year, or any sequence of digits.")
                .font(.subheadline)
                .foregroundStyle(palette.mutedInk)
            Text("Searches the live pi index — requires internet.")
                .font(.caption)
                .foregroundStyle((palette.mutedInk.opacity(0.6) as Color))
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Excerpt text builder

    private func excerptText(_ display: FreeSearchResult.ExcerptDisplay, highlight: String, palette: ThemePalette) -> Text {
        Text(display.before).foregroundStyle((palette.mutedInk.opacity(0.55) as Color))
        + Text(display.highlight).foregroundStyle(palette.accent).bold()
        + Text(display.after).foregroundStyle((palette.mutedInk.opacity(0.55) as Color))
    }
}
