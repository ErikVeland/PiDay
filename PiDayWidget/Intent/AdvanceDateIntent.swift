import AppIntents
import WidgetKit
import Foundation

// WHY AppIntent for interactive widgets:
// iOS 17 introduced buttons and toggles in widgets that execute code WITHOUT
// launching the app. The code runs in the widget extension process via AppIntents.
// This lets users tap "next day" / "prev day" directly on the home screen.
//
// PREREQUISITE — this intent requires an App Group to be configured:
// 1. In Xcode → PiDay target → Signing & Capabilities → + → App Groups
//    Add: group.academy.glasscode.piday
// 2. Repeat for PiDayWidget target.
// 3. Register the group at developer.apple.com (Xcode usually does this automatically).
//
// Until the App Group is set up, the intent will write to .standard UserDefaults
// (via the fallback in sharedDefaults), which the widget can read but the app cannot.

enum DateAdvanceDirection: String, AppEnum {
    case previous
    case next

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Direction")
    static let caseDisplayRepresentations: [DateAdvanceDirection: DisplayRepresentation] = [
        .previous: DisplayRepresentation(title: "Previous Day"),
        .next: DisplayRepresentation(title: "Next Day")
    ]
}

struct AdvanceDateIntent: AppIntent {
    static let title: LocalizedStringResource = "Advance Date"
    static let description = IntentDescription("Move the widget date forward or backward one day.")

    @Parameter(title: "Direction")
    var direction: DateAdvanceDirection

    init() {}

    init(direction: DateAdvanceDirection) {
        self.direction = direction
    }

    func perform() async throws -> some IntentResult {
        let defaults = sharedDefaults
        let stored = defaults.object(forKey: offsetKey) as? Date
        let base = stored ?? Calendar.current.startOfDay(for: Date.now)

        let newDate: Date
        switch direction {
        case .previous:
            newDate = Calendar.current.date(byAdding: .day, value: -1, to: base) ?? base
        case .next:
            newDate = Calendar.current.date(byAdding: .day, value: 1, to: base) ?? base
        }

        defaults.set(newDate, forKey: offsetKey)

        // Reload the widget timeline immediately so the new date renders.
        WidgetCenter.shared.reloadTimelines(ofKind: "academy.glasscode.piday.widget")
        WidgetCenter.shared.reloadTimelines(ofKind: "academy.glasscode.piday.accessory")

        return .result()
    }

    // MARK: - Shared storage keys

    private let offsetKey = "academy.glasscode.piday.widget.displayDate"
    private let appGroupID = "group.academy.glasscode.piday"

    private var sharedDefaults: UserDefaults {
        // Falls back to .standard if the App Group isn't configured yet.
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}
