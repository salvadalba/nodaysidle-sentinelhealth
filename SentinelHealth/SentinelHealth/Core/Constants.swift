//
//  Constants.swift
//  SentinelHealth
//
//  Application-wide constants and configuration values.
//

import Foundation

/// Application-wide constants
public enum SentinelConstants {

    // MARK: - App Identity

    /// Bundle identifier
    public static let bundleIdentifier = "com.sentinel.health"

    /// App name for display
    public static let appName = "Sentinel Health"

    /// App version (retrieved from bundle)
    public static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Build number (retrieved from bundle)
    public static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Monitoring Intervals

    public enum Monitoring {
        /// Default polling interval for UI updates (1 Hz)
        public static let uiRefreshInterval: TimeInterval = 1.0

        /// Polling interval for ML inference (10 Hz)
        public static let mlInferenceInterval: TimeInterval = 0.1

        /// Process enumeration refresh interval
        public static let processEnumInterval: TimeInterval = 5.0
    }

    // MARK: - Performance Thresholds

    public enum Performance {
        /// Maximum CPU overhead percentage for background daemon
        public static let maxCPUOverhead: Double = 1.0

        /// Target latency for offload decisions (milliseconds)
        public static let offloadDecisionLatencyMs: Double = 100.0

        /// Target restore latency (milliseconds)
        public static let restoreLatencyMs: Double = 500.0

        /// Maximum memory footprint for daemon (bytes)
        public static let maxMemoryFootprint: UInt64 = 50 * 1024 * 1024  // 50 MB
    }

    // MARK: - Prediction Settings

    public enum Prediction {
        /// Default prediction threshold (70% confidence)
        public static let defaultThreshold: Double = 0.7

        /// Minimum prediction threshold
        public static let minimumThreshold: Double = 0.5

        /// Maximum prediction threshold
        public static let maximumThreshold: Double = 0.95

        /// Number of predictions to keep for accuracy calculation
        public static let accuracyWindowSize: Int = 100

        /// Prediction lookahead window (seconds)
        public static let lookaheadSeconds: TimeInterval = 30.0
    }

    // MARK: - Process Offloading

    public enum Offloading {
        /// Minimum idle time before a process is candidate for offload (seconds)
        public static let minimumIdleTime: TimeInterval = 60.0

        /// Minimum memory footprint to consider for offloading (bytes)
        public static let minimumMemoryFootprint: UInt64 = 50 * 1024 * 1024  // 50 MB

        /// Maximum number of processes to offload simultaneously
        public static let maxConcurrentOffloads: Int = 5

        /// Grace period before forced offload after warning (seconds)
        public static let warningGracePeriod: TimeInterval = 10.0

        /// Minimum time a process should stay offloaded before auto-restore (seconds)
        public static let minimumOffloadDuration: TimeInterval = 30.0
    }

    // MARK: - System-Critical Processes (Never Offload)

    public enum SystemProcesses {
        /// Bundle IDs of system-critical processes that must never be suspended
        public static let protected: Set<String> = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.WindowServer",
            "com.apple.SystemUIServer",
            "com.apple.Spotlight",
            "com.apple.coreservicesd",
            "com.apple.launchd",
            "com.apple.kernel_task",
            "com.sentinel.health",  // Don't suspend ourselves!
        ]

        /// Process names that should never be suspended (for processes without bundle IDs)
        public static let protectedProcessNames: Set<String> = [
            "kernel_task",
            "launchd",
            "WindowServer",
            "Finder",
            "Dock",
            "SystemUIServer",
            "loginwindow",
            "coreservicesd",
        ]
    }

    // MARK: - Storage Keys

    public enum StorageKeys {
        /// @AppStorage key for prediction threshold
        public static let predictionThreshold = "predictionThreshold"

        /// @AppStorage key for notification frequency
        public static let notificationFrequency = "notificationFrequency"

        /// @AppStorage key for launch at login
        public static let launchAtLogin = "launchAtLogin"

        /// @AppStorage key for CloudKit sync enabled
        public static let cloudKitSyncEnabled = "cloudKitSyncEnabled"

        /// @AppStorage key for debug logging
        public static let debugLoggingEnabled = "debugLoggingEnabled"

        /// @AppStorage key for CPU overhead limit
        public static let cpuOverheadLimit = "cpuOverheadLimit"

        /// @AppStorage key for excluded apps (stored as JSON array)
        public static let excludedApps = "excludedApps"

        /// @AppStorage key for has completed onboarding
        public static let hasCompletedOnboarding = "hasCompletedOnboarding"

        /// @AppStorage key for notification permission state
        public static let notificationPermissionGranted = "notificationPermissionGranted"
    }

    // MARK: - Notification Categories

    public enum NotificationCategories {
        /// Category for thermal warning notifications
        public static let thermalWarning = "THERMAL_WARNING"

        /// Category for offload action notifications
        public static let offloadAction = "OFFLOAD_ACTION"

        /// Category for restore notifications
        public static let restoreAction = "RESTORE_ACTION"
    }
}
