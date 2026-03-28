import SwiftUI

// WHY a separate sheet (not inline in DetailSheetView):
// The saved dates list can grow and needs its own navigation context for
// editing labels. Keeping it in a separate NavigationStack sheet avoids
// nested navigation stacks, which are buggy in SwiftUI.

struct SavedDatesView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(PreferencesStore.self) private var preferences
    @Binding var isPresented: Bool
    @State private var editingDate: SavedDate?
    @State private var battlingDate: SavedDate?
    @State private var sortOption: SavedDatesSortOption = .bestPosition
    @State private var labelDraft = ""
    @State private var labelError = false

    var body: some View {
        let palette = preferences.resolvedPalette

        NavigationStack {
            Group {
                if viewModel.savedDatesStore.dates.isEmpty {
                    emptyState
                } else {
                    dateList
                }
            }
            .background {
                if #available(iOS 26, *) { } else {
                    palette.background.ignoresSafeArea()
                }
            }
            .navigationTitle("Saved Dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .font(.body.weight(.semibold))
                }
            }
            .sheet(item: $editingDate) { date in
                editLabelSheet(for: date)
            }
            .sheet(item: $battlingDate) { date in
                DateBattleView(anchorDate: viewModel.selectedDate, initialOpponent: date.date)
                    .environment(viewModel)
                    .environment(preferences)
            }
        }
    }

    // MARK: - Subviews

    private var dateList: some View {
        List {
            Section {
                Picker("Sort", selection: $sortOption) {
                    ForEach(SavedDatesSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Leaderboard") {
                ForEach(viewModel.rankedSavedDates(sortedBy: sortOption)) { ranked in
                    savedDateRow(ranked)
                }
                .onDelete { indexSet in
                    let current = viewModel.rankedSavedDates(sortedBy: sortOption)
                    let toDelete = indexSet.map { current[$0].savedDate }
                    toDelete.forEach { viewModel.savedDatesStore.delete($0) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func savedDateRow(_ ranked: RankedSavedDate) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.select(ranked.savedDate.date)
                isPresented = false
            } label: {
                HStack(spacing: 12) {
                    if let rank = ranked.rank, sortOption == .bestPosition {
                        Text("#\(rank)")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(preferences.resolvedPalette.accent)
                            .frame(width: 30, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(ranked.savedDate.label)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(preferences.resolvedPalette.ink)
                        Text(ranked.savedDate.date, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(preferences.resolvedPalette.mutedInk)

                        if let position = ranked.bestStoredPosition {
                            HStack(spacing: 8) {
                                Text("digit \(viewModel.displayedPosition(for: position).formatted())")
                                if let percentile = ranked.percentileLabel {
                                    Text(percentile)
                                }
                                if let format = ranked.bestFormat {
                                    Text(format.displayName)
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(preferences.resolvedPalette.accent)
                        } else {
                            Text("No exact bundled hit")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(preferences.resolvedPalette.mutedInk)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                battlingDate = ranked.savedDate
            } label: {
                Image(systemName: "bolt.shield")
                    .font(.subheadline)
                    .foregroundStyle(preferences.resolvedPalette.accent)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Button {
                labelDraft = ranked.savedDate.label
                editingDate = ranked.savedDate
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(preferences.resolvedPalette.mutedInk)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 44))
                .foregroundStyle((preferences.resolvedPalette.mutedInk.opacity(0.4) as Color))
            Text("No saved dates")
                .font(.headline)
                .foregroundStyle(preferences.resolvedPalette.ink)
            Text("Open a date and tap the bookmark\nbutton to save it here.")
                .font(.subheadline)
                .foregroundStyle(preferences.resolvedPalette.mutedInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Edit label sheet

    private func editLabelSheet(for date: SavedDate) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(date.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(preferences.resolvedPalette.mutedInk)

                TextField("Label", text: $labelDraft)
                    .font(.title3.weight(.semibold))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: labelDraft) { labelError = false }

                if labelError {
                    Text("Label cannot be empty")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(20)
            .background {
                if #available(iOS 26, *) { } else {
                    preferences.resolvedPalette.background.ignoresSafeArea()
                }
            }
            .navigationTitle("Edit Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { editingDate = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmed = labelDraft.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else {
                            labelError = true
                            return
                        }
                        let updated = SavedDate(id: date.id, label: trimmed, date: date.date)
                        viewModel.savedDatesStore.upsert(updated)
                        editingDate = nil
                    }
                    .font(.body.weight(.semibold))
                    .disabled(labelDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
