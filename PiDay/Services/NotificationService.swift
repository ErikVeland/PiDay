import UserNotifications

// WHY a static service (not a class instance): notifications are fire-and-forget.
// There's no state to keep alive between calls, so a class instance adds no value.
enum NotificationService {
    enum AuthorizationState: Equatable {
        case notDetermined
        case denied
        case authorized
    }

    static func authorizationState() async -> AuthorizationState {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    // Request permission from an explicit user action, then schedule annual reminders
    // for each featured number day.
    static func requestAndScheduleFeaturedDays() async -> AuthorizationState {
        let center = UNUserNotificationCenter.current()
        let currentState = await authorizationState()

        guard currentState != .denied else { return .denied }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else {
            return await authorizationState()
        }

        await scheduleFeaturedDaysIfNeeded(center: center)
        return .authorized
    }

    static func scheduleFeaturedDaysIfAuthorized() async {
        let center = UNUserNotificationCenter.current()
        guard await authorizationState() == .authorized else { return }
        await scheduleFeaturedDaysIfNeeded(center: center)
    }

    // MARK: - Private

    private static func scheduleFeaturedDaysIfNeeded(center: UNUserNotificationCenter) async {
        // Don't reschedule if a given reminder is already pending.
        let pending = await center.pendingNotificationRequests()

        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: Date())

        for featured in CalendarFeaturedNumber.allCases {
            let id = "academy.glasscode.piday.featuredDay.\(featured.rawValue)"
            if pending.contains(where: { $0.identifier == id }) { continue }

            guard let date = featured.highlightDate(inYear: year, calendar: cal) else { continue }
            let comps = cal.dateComponents([.month, .day], from: date)
            guard let month = comps.month, let day = comps.day else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Happy \(featured.title) Day"
            content.body = "It's \(featured.observedDayLabel). Open PiDay to find your place in \(featured.heatMapSymbol)."
            content.sound = .default

            // Keep a consistent time across numbers (equal treatment): 9:14 AM local time.
            var triggerComponents = DateComponents()
            triggerComponents.month = month
            triggerComponents.day = day
            triggerComponents.hour = 9
            triggerComponents.minute = 14

            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
