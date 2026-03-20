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

    // Request permission from an explicit user action, then schedule the annual reminder.
    static func requestAndSchedulePiDay() async -> AuthorizationState {
        let center = UNUserNotificationCenter.current()
        let currentState = await authorizationState()

        guard currentState != .denied else { return .denied }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else {
            return await authorizationState()
        }

        await schedulePiDayIfNeeded(center: center)
        return .authorized
    }

    static func schedulePiDayIfAuthorized() async {
        let center = UNUserNotificationCenter.current()
        guard await authorizationState() == .authorized else { return }
        await schedulePiDayIfNeeded(center: center)
    }

    // MARK: - Private

    private static let notificationID = "academy.glasscode.piday.piday-notification"

    private static func schedulePiDayIfNeeded(center: UNUserNotificationCenter) async {
        // Don't reschedule if one is already pending.
        let pending = await center.pendingNotificationRequests()
        if pending.contains(where: { $0.identifier == notificationID }) { return }

        let content = UNMutableNotificationContent()
        content.title = "Happy Pi Day! 🥧"
        content.body = "It's March 14 — Pi Day. Open PiDay to find your place in π."
        content.sound = .default

        // March 14 at 9:14 AM — π day at π time.
        var components = DateComponents()
        components.month = 3
        components.day = 14
        components.hour = 9
        components.minute = 14

        // repeats: true means this fires every year automatically.
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }
}
