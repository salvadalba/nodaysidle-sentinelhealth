//
//  NotificationCoordinator.swift
//  SentinelHealth
//
//  Actor managing user notifications for thermal events.
//

import Foundation
import OSLog
import UserNotifications

// MARK: - Notification Types

/// Types of notifications sent by Sentinel Health
public enum SentinelNotificationType: String, Sendable {
    /// Thermal warning notification
    case thermalWarning = "thermal_warning"

    /// Process offload notification
    case processOffloaded = "process_offloaded"

    /// Processes restored notification
    case processesRestored = "processes_restored"

    /// System health summary
    case healthSummary = "health_summary"

    /// Action required notification
    case actionRequired = "action_required"
}

/// Notification preference levels
public enum NotificationLevel: String, Sendable, CaseIterable {
    /// All notifications
    case all = "all"

    /// Important only (warnings and critical)
    case important = "important"

    /// Critical only
    case critical = "critical"

    /// No notifications
    case none = "none"

    public var displayName: String {
        switch self {
        case .all: return "All Notifications"
        case .important: return "Important Only"
        case .critical: return "Critical Only"
        case .none: return "None"
        }
    }
}

// MARK: - Notification Content

/// Content for a Sentinel notification
public struct SentinelNotificationContent: Sendable {
    public let type: SentinelNotificationType
    public let title: String
    public let body: String
    public let subtitle: String?
    public let badge: Int?
    public let sound: Bool
    public let categoryIdentifier: String?
    public let userInfo: [String: String]

    public init(
        type: SentinelNotificationType,
        title: String,
        body: String,
        subtitle: String? = nil,
        badge: Int? = nil,
        sound: Bool = true,
        categoryIdentifier: String? = nil,
        userInfo: [String: String] = [:]
    ) {
        self.type = type
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.badge = badge
        self.sound = sound
        self.categoryIdentifier = categoryIdentifier
        self.userInfo = userInfo
    }
}

// MARK: - Notification Coordinator Actor

/// Actor responsible for managing user notifications.
public actor NotificationCoordinator {

    // MARK: - Properties

    private let logger = SentinelLogger.uiController

    /// Notification center reference
    private let notificationCenter: UNUserNotificationCenter

    /// Current authorization status
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Current notification preference level
    private(set) var notificationLevel: NotificationLevel = .important

    /// Cooldown between similar notifications (seconds)
    private let notificationCooldown: TimeInterval = 30.0

    /// Last notification time by type
    private var lastNotificationTime: [SentinelNotificationType: Date] = [:]

    /// Whether notifications are currently suppressed
    private var isSuppressed: Bool = false

    // MARK: - Initialization

    public init() {
        self.notificationCenter = UNUserNotificationCenter.current()
        logger.info("NotificationCoordinator initialized")
    }

    // MARK: - Authorization

    /// Request notification authorization.
    /// - Returns: True if authorization was granted
    @discardableResult
    public func requestAuthorization() async -> Bool {
        logger.info("Requesting notification authorization")

        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            await updateAuthorizationStatus()

            if granted {
                logger.info("Notification authorization granted")
                await setupNotificationCategories()
            } else {
                logger.warning("Notification authorization denied")
            }

            return granted
        } catch {
            logger.error(
                "Failed to request notification authorization: \(error.localizedDescription)")
            return false
        }
    }

    /// Update the current authorization status.
    public func updateAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Check if notifications are authorized.
    public var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    // MARK: - Notification Management

    /// Set the notification preference level.
    public func setNotificationLevel(_ level: NotificationLevel) {
        notificationLevel = level
        logger.info("Notification level set to: \(level.rawValue)")
    }

    /// Suppress notifications temporarily.
    public func suppressNotifications(_ suppress: Bool) {
        isSuppressed = suppress
        logger.info("Notifications \(suppress ? "suppressed" : "enabled")")
    }

    /// Send a notification.
    /// - Parameter content: Notification content to send
    /// - Returns: True if notification was sent
    @discardableResult
    public func sendNotification(_ content: SentinelNotificationContent) async -> Bool {
        // Check suppression
        guard !isSuppressed else {
            logger.debug("Notification suppressed: \(content.type.rawValue)")
            return false
        }

        // Check authorization
        guard isAuthorized else {
            logger.warning("Cannot send notification - not authorized")
            return false
        }

        // Check notification level
        guard shouldSendNotification(type: content.type) else {
            logger.debug("Notification filtered by level: \(content.type.rawValue)")
            return false
        }

        // Check cooldown
        if let lastTime = lastNotificationTime[content.type],
            Date().timeIntervalSince(lastTime) < notificationCooldown
        {
            logger.debug("Notification in cooldown: \(content.type.rawValue)")
            return false
        }

        // Build notification
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = content.title
        notificationContent.body = content.body

        if let subtitle = content.subtitle {
            notificationContent.subtitle = subtitle
        }

        if let badge = content.badge {
            notificationContent.badge = NSNumber(value: badge)
        }

        if content.sound {
            notificationContent.sound = .default
        }

        if let category = content.categoryIdentifier {
            notificationContent.categoryIdentifier = category
        }

        // Add user info
        var userInfo: [String: Any] = content.userInfo
        userInfo["notification_type"] = content.type.rawValue
        notificationContent.userInfo = userInfo

        // Create request
        let identifier = "\(content.type.rawValue)_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: notificationContent,
            trigger: nil  // Deliver immediately
        )

        do {
            try await notificationCenter.add(request)
            lastNotificationTime[content.type] = Date()
            logger.info("Notification sent: \(content.type.rawValue)")
            return true
        } catch {
            logger.error("Failed to send notification: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Convenience Methods

    /// Send thermal warning notification.
    public func sendThermalWarning(state: ThermalStateValue) async {
        let content = SentinelNotificationContent(
            type: .thermalWarning,
            title: "Thermal Warning",
            body:
                "System temperature is \(state.displayDescription.lowercased()). Sentinel Health is taking action to cool down.",
            subtitle: "Performance may be affected",
            sound: state == .critical
        )

        await sendNotification(content)
    }

    /// Send process offloaded notification.
    public func sendProcessesOffloaded(count: Int, memorySaved: UInt64) async {
        let content = SentinelNotificationContent(
            type: .processOffloaded,
            title: "Processes Suspended",
            body:
                "Suspended \(count) idle \(count == 1 ? "process" : "processes") to reclaim \(MemoryMetrics.formatBytes(memorySaved)).",
            sound: false
        )

        await sendNotification(content)
    }

    /// Send processes restored notification.
    public func sendProcessesRestored(count: Int) async {
        let content = SentinelNotificationContent(
            type: .processesRestored,
            title: "Processes Restored",
            body: "Restored \(count) suspended \(count == 1 ? "process" : "processes").",
            sound: false
        )

        await sendNotification(content)
    }

    // MARK: - Private Methods

    private func shouldSendNotification(type: SentinelNotificationType) -> Bool {
        switch notificationLevel {
        case .none:
            return false
        case .critical:
            return type == .thermalWarning || type == .actionRequired
        case .important:
            return type != .healthSummary
        case .all:
            return true
        }
    }

    private func setupNotificationCategories() async {
        // Set up notification categories with actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View Details",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: []
        )

        let restoreAction = UNNotificationAction(
            identifier: "RESTORE_ACTION",
            title: "Restore All",
            options: [.foreground]
        )

        // Thermal warning category
        let thermalCategory = UNNotificationCategory(
            identifier: "THERMAL_WARNING",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        // Process offloaded category
        let offloadCategory = UNNotificationCategory(
            identifier: "PROCESS_OFFLOADED",
            actions: [viewAction, restoreAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([thermalCategory, offloadCategory])
        logger.debug("Notification categories configured")
    }

    /// Clear all pending notifications.
    public func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        logger.info("All notifications cleared")
    }

    /// Clear notifications of a specific type.
    public func clearNotifications(ofType type: SentinelNotificationType) async {
        let notifications = await notificationCenter.deliveredNotifications()
        let identifiersToRemove =
            notifications
            .filter { notification in
                (notification.request.content.userInfo["notification_type"] as? String)
                    == type.rawValue
            }
            .map { $0.request.identifier }

        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: identifiersToRemove)
    }
}
