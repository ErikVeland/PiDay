import SwiftUI
import ContactsUI

// MARK: - Partial Birthday

// Wraps a birthday month + day from Contacts when the contact's year field is absent.
// WHY Identifiable with UUID: each picker invocation must produce a fresh value so
// .sheet(item:) re-presents the view even if the same month/day is returned twice
// in a row (e.g. user cancels the year prompt and opens the picker again).
struct PartialBirthday: Identifiable {
    let id = UUID()
    let month: Int
    let day: Int
}

// MARK: - Contact Picker Presenter

// An invisible UIViewControllerRepresentable that presents CNContactPickerViewController.
//
// WHY invisible presenter pattern: CNContactPickerViewController must be *presented*
// (not pushed onto a NavigationStack), and wrapping it as a SwiftUI .sheet is fragile —
// the picker internally manages its own dismissal lifecycle and conflicts with SwiftUI's
// sheet state machine. Embedding a plain UIViewController as .background gives us a
// stable UIKit host to call present(_:animated:) on, with no interference from
// SwiftUI sheet transitions.
//
// WHY CNContactPickerViewController vs CNContactStore: the picker requires no permission
// dialog. The system presents its own UI and returns only the selected contact to the app.
// CNContactStore requires NSContactsUsageDescription and full contacts access.
struct ContactPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onContact: (CNContact) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        if isPresented, host.presentedViewController == nil {
            let picker = CNContactPickerViewController()
            // Display the birthday field prominently in the contact list.
            // The user still selects a full contact; we read contact.birthday afterward.
            picker.displayedPropertyKeys = [CNContactBirthdayKey]
            picker.delegate = context.coordinator
            host.present(picker, animated: true)
        } else if !isPresented, host.presentedViewController is CNContactPickerViewController {
            host.presentedViewController?.dismiss(animated: true)
        }
    }

    // WHY closures instead of storing the whole parent struct: ContactPickerPresenter
    // is @MainActor-isolated (as UIViewControllerRepresentable). Storing it in the
    // Coordinator and accessing its properties from nonisolated UIKit callbacks
    // produces actor-isolation warnings regardless of @unchecked Sendable.
    //
    // Extracting callbacks at makeCoordinator() call time (which runs on @MainActor)
    // into plain () -> Void / (CNContact) -> Void closures avoids the issue:
    // • dismiss: closes over Binding<Bool> — its setter is not @MainActor-isolated
    // • onContact: stored as a non-isolated function value once captured
    // UIKit guarantees these callbacks arrive on the main thread, so calling
    // these closures from the delegate is safe without explicit actor hops.
    func makeCoordinator() -> Coordinator {
        let binding = $isPresented
        let handler = onContact
        return Coordinator(dismiss: { binding.wrappedValue = false }, onContact: handler)
    }

    // WHY @unchecked Sendable: Swift 6 requires Coordinator to be Sendable because it
    // crosses isolation boundaries when UIKit holds a reference. The closures stored here
    // are safe: dismiss only writes through a Binding, onContact is main-thread-only.
    final class Coordinator: NSObject, CNContactPickerDelegate, @unchecked Sendable {
        private let dismiss: () -> Void
        private let onContact: (CNContact) -> Void

        init(dismiss: @escaping () -> Void, onContact: @escaping (CNContact) -> Void) {
            self.dismiss = dismiss
            self.onContact = onContact
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            dismiss()
            onContact(contact)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            dismiss()
        }
    }
}

// MARK: - Birthday Year Prompt

// Shown when a contact's birthday has month + day stored but no year.
// The DatePicker is pre-filled with the correct month and day so the user
// only needs to scroll the year wheel to complete their birthday.
struct BirthdayYearPromptView: View {
    let partial: PartialBirthday
    let onConfirm: (Date) -> Void

    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date

    init(partial: PartialBirthday, onConfirm: @escaping (Date) -> Void) {
        self.partial = partial
        self.onConfirm = onConfirm
        // WHY -30 years: a neutral starting point that doesn't skew toward infants
        // or centenarians. The user corrects the year with a single scroll gesture.
        // WHY gregorian calendar: birthday components from CNDateComponents are always
        // in the Gregorian system. Using Calendar.current risks incorrect results on
        // devices set to Buddhist, Hebrew, or Islamic calendars.
        let gregorian = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year  = gregorian.component(.year, from: .now) - 30
        comps.month = partial.month
        comps.day   = partial.day
        _selectedDate = State(initialValue: gregorian.date(from: comps) ?? .now)
    }

    var body: some View {
        let palette = preferences.resolvedPalette
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: "birthday.cake")
                        .font(.system(size: 44))
                        .foregroundStyle(palette.accent)

                    Text("Your contact card has your birthday's month and day, but no year. Scroll to your birth year to continue.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 8)

                // WHY .date components: iOS has no year-only picker component.
                // We show the full date wheel but immediately snap month and day
                // back to the contact's known values if the user accidentally scrolls
                // them — this view's sole purpose is choosing the birth year.
                DatePicker(
                    "Birthday",
                    selection: $selectedDate,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .onChange(of: selectedDate) { _, new in
                    var gregorian = Calendar(identifier: .gregorian)
                    gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
                    let comps = gregorian.dateComponents([.year, .month, .day], from: new)
                    guard comps.month != partial.month || comps.day != partial.day else { return }
                    // Month or day drifted — snap them back while keeping the new year.
                    var corrected = DateComponents()
                    corrected.year  = comps.year
                    corrected.month = partial.month
                    corrected.day   = partial.day
                    if let fixed = gregorian.date(from: corrected) {
                        selectedDate = fixed
                    }
                }

                Button {
                    onConfirm(selectedDate)
                    dismiss()
                } label: {
                    Text("Find My Birthday in π")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Which year?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(preferences.resolvedPreferredColorScheme)
    }
}
