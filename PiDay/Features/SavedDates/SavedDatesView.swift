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
        }
    }

    // MARK: - Subviews

    private var dateList: some View {
        List {
            ForEach(viewModel.savedDatesStore.dates) { saved in
                savedDateRow(saved)
            }
            .onDelete { indexSet in
                // WHY collect first: delete() mutates the array immediately.
                // Deleting one-by-one shifts subsequent indices, causing wrong
                // items to be deleted or an out-of-bounds crash when EditButton
                // delivers a multi-index set.
                let toDelete = indexSet.map { viewModel.savedDatesStore.dates[$0] }
                toDelete.forEach { viewModel.savedDatesStore.delete($0) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func savedDateRow(_ saved: SavedDate) -> some View {
        Button {
            viewModel.select(saved.date)
            isPresented = false
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(saved.label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(preferences.resolvedPalette.ink)
                    Text(saved.date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(preferences.resolvedPalette.mutedInk)
                }

                Spacer()

                // Edit label button
                Button {
                    labelDraft = saved.label
                    editingDate = saved
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundStyle(preferences.resolvedPalette.mutedInk)
                }
                .buttonStyle(.plain)
            }
        }
        .buttonStyle(.plain)
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
