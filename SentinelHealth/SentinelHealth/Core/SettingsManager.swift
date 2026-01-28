//
//  SettingsManager.swift
//  SentinelHealth
//
//  Observable settings manager with @AppStorage backing.
//

import Foundation
import OSLog
import ServiceManagement
import SwiftUI

// MARK: - Settings Manager

/// Observable class managing all app preferences with @AppStorage backing.
/// UserDefaults is thread-safe internally, so @unchecked Sendable is appropriate.
@Observable
public final class SettingsManager: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = SettingsManager()

    // MARK: - Properties

    private let logger = SentinelLogger.settings
    private let defaults = UserDefaults.standard

    // MARK: - General Settings

    /// Whether to launch at login
    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: SentinelConstants.StorageKeys.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: SentinelConstants.StorageKeys.launchAtLogin)
            updateLaunchAtLogin(newValue)
        }
    }

    /// Prediction threshold (0.5-0.9)
    public var predictionThreshold: Double {
        get {
            let value = defaults.double(forKey: SentinelConstants.StorageKeys.predictionThreshold)
            return value > 0 ? value : SentinelConstants.Prediction.defaultThreshold
        }
        set {
            let clamped = min(
                max(newValue, SentinelConstants.Prediction.minimumThreshold),
                SentinelConstants.Prediction.maximumThreshold)
            defaults.set(clamped, forKey: SentinelConstants.StorageKeys.predictionThreshold)
        }
    }

    /// Notification frequency setting
    public var notificationFrequency: NotificationFrequencySetting {
        get {
            let raw =
                defaults.string(forKey: SentinelConstants.StorageKeys.notificationFrequency)
                ?? NotificationFrequencySetting.always.rawValue
            return NotificationFrequencySetting(rawValue: raw) ?? .always
        }
        set {
            defaults.set(
                newValue.rawValue, forKey: SentinelConstants.StorageKeys.notificationFrequency)
        }
    }

    // MARK: - Advanced Settings

    /// CPU overhead limit percentage
    public var cpuOverheadLimit: Double {
        get {
            let value = defaults.double(forKey: SentinelConstants.StorageKeys.cpuOverheadLimit)
            return value > 0 ? value : SentinelConstants.Performance.maxCPUOverhead
        }
        set {
            defaults.set(
                min(max(newValue, 1), 5), forKey: SentinelConstants.StorageKeys.cpuOverheadLimit)
        }
    }

    /// Debug logging enabled
    public var debugLoggingEnabled: Bool {
        get { defaults.bool(forKey: SentinelConstants.StorageKeys.debugLoggingEnabled) }
        set { defaults.set(newValue, forKey: SentinelConstants.StorageKeys.debugLoggingEnabled) }
    }

    /// CloudKit sync enabled
    public var cloudKitSyncEnabled: Bool {
        get { defaults.bool(forKey: SentinelConstants.StorageKeys.cloudKitSyncEnabled) }
        set { defaults.set(newValue, forKey: SentinelConstants.StorageKeys.cloudKitSyncEnabled) }
    }

    // MARK: - Exclusions

    /// List of excluded bundle identifiers
    public var excludedBundleIdentifiers: Set<String> {
        get {
            guard let data = defaults.data(forKey: SentinelConstants.StorageKeys.excludedApps),
                let apps = try? JSONDecoder().decode([ExcludedAppInfo].self, from: data)
            else {
                return defaultExclusions
            }
            return Set(apps.map { $0.bundleIdentifier })
        }
        set {
            let apps = newValue.map { ExcludedAppInfo(name: $0, bundleIdentifier: $0) }
            if let data = try? JSONEncoder().encode(apps) {
                defaults.set(data, forKey: SentinelConstants.StorageKeys.excludedApps)
            }
        }
    }

    /// Default system apps to exclude
    private var defaultExclusions: Set<String> {
        [
            "com.apple.finder",
            "com.apple.systempreferences",
            "com.apple.loginwindow",
            "com.apple.dock",
            "com.apple.WindowManager",
            "com.apple.Spotlight",
            "com.apple.notificationcenterui",
            "com.apple.Safari.WebContent",
        ]
    }

    // MARK: - State

    /// Whether onboarding has been completed
    public var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    /// Whether notifications are authorized
    public var notificationsAuthorized: Bool {
        get { defaults.bool(forKey: "notificationsAuthorized") }
        set { defaults.set(newValue, forKey: "notificationsAuthorized") }
    }

    // MARK: - Initialization

    private init() {
        registerDefaults()
        logger.info("SettingsManager initialized")
    }

    /// Register default values
    private func registerDefaults() {
        defaults.register(defaults: [
            SentinelConstants.StorageKeys.launchAtLogin: false,
            SentinelConstants.StorageKeys.predictionThreshold: SentinelConstants.Prediction
                .defaultThreshold,
            SentinelConstants.StorageKeys.notificationFrequency: NotificationFrequencySetting.always
                .rawValue,
            SentinelConstants.StorageKeys.cpuOverheadLimit: SentinelConstants.Performance
                .maxCPUOverhead,
            SentinelConstants.StorageKeys.debugLoggingEnabled: false,
            SentinelConstants.StorageKeys.cloudKitSyncEnabled: false,
        ])
    }

    // MARK: - Launch at Login

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Registered for launch at login")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Unregistered from launch at login")
            }
        } catch {
            logger.error("Failed to update launch at login: \(error.localizedDescription)")
        }
    }

    // MARK: - Exclusion Management

    /// Check if a bundle identifier is excluded
    public func isExcluded(bundleIdentifier: String) -> Bool {
        excludedBundleIdentifiers.contains(bundleIdentifier)
    }

    /// Add a bundle identifier to exclusions
    public func addExclusion(_ bundleIdentifier: String) {
        var current = excludedBundleIdentifiers
        current.insert(bundleIdentifier)
        excludedBundleIdentifiers = current
        logger.info("Added exclusion: \(bundleIdentifier)")
    }

    /// Remove a bundle identifier from exclusions
    public func removeExclusion(_ bundleIdentifier: String) {
        var current = excludedBundleIdentifiers
        current.remove(bundleIdentifier)
        excludedBundleIdentifiers = current
        logger.info("Removed exclusion: \(bundleIdentifier)")
    }

    // MARK: - Reset

    /// Reset all settings to defaults
    public func resetToDefaults() {
        launchAtLogin = false
        predictionThreshold = SentinelConstants.Prediction.defaultThreshold
        notificationFrequency = .always
        cpuOverheadLimit = SentinelConstants.Performance.maxCPUOverhead
        debugLoggingEnabled = false
        cloudKitSyncEnabled = false
        excludedBundleIdentifiers = defaultExclusions
        logger.info("All settings reset to defaults")
    }
}

// MARK: - Supporting Types

/// Notification frequency options
public enum NotificationFrequencySetting: String, CaseIterable, Sendable {
    case always
    case hourly
    case daily
    case never

    public var displayName: String {
        switch self {
        case .always: return "Always"
        case .hourly: return "At Most Hourly"
        case .daily: return "At Most Daily"
        case .never: return "Never"
        }
    }

    /// Minimum interval between notifications
    public var minimumInterval: TimeInterval {
        switch self {
        case .always: return 0
        case .hourly: return 3600
        case .daily: return 86400
        case .never: return .infinity
        }
    }
}

/// Excluded app info for persistence
public struct ExcludedAppInfo: Codable, Sendable {
    public let name: String
    public let bundleIdentifier: String
}
