//
//  Logging.swift
//  SentinelHealth
//
//  OSLog infrastructure with subsystem and category configuration.
//

import OSLog

// MARK: - Logger Categories

/// Centralized logging infrastructure for Sentinel Health.
/// Uses Apple's OSLog with structured categories for each module.
public enum SentinelLogger {

    /// The app's subsystem identifier for OSLog
    private static let subsystem = "com.sentinel.health"

    // MARK: - Category Loggers

    /// Logger for Thermal Intelligence Engine operations
    public static let thermalEngine = Logger(subsystem: subsystem, category: "ThermalEngine")

    /// Logger for Unified Memory Monitor operations
    public static let memoryMonitor = Logger(subsystem: subsystem, category: "MemoryMonitor")

    /// Logger for Process Offload Manager operations
    public static let offloadManager = Logger(subsystem: subsystem, category: "OffloadManager")

    /// Logger for UI and MenuBar Controller operations
    public static let uiController = Logger(subsystem: subsystem, category: "UIController")

    /// Logger for Settings and Configuration operations
    public static let settings = Logger(subsystem: subsystem, category: "Settings")

    /// Logger for Notification Coordinator operations
    public static let notifications = Logger(subsystem: subsystem, category: "Notifications")

    /// Logger for Historical Analytics Store operations
    public static let analytics = Logger(subsystem: subsystem, category: "Analytics")

    /// Logger for SwiftData persistence operations
    public static let persistence = Logger(subsystem: subsystem, category: "Persistence")

    /// Logger for CloudKit sync operations
    public static let cloudSync = Logger(subsystem: subsystem, category: "CloudSync")

    /// Logger for privileged helper operations
    public static let helper = Logger(subsystem: subsystem, category: "PrivilegedHelper")

    /// General purpose logger for app lifecycle
    public static let general = Logger(subsystem: subsystem, category: "General")
}

// MARK: - Signpost Support

/// Performance tracing signposts for Instruments profiling
public enum SentinelSignpost {

    /// Signpost log for Thermal Engine operations
    public static let thermalEngine = OSSignposter(
        subsystem: "com.sentinel.health", category: "ThermalEngine")

    /// Signpost log for Memory Monitor operations
    public static let memoryMonitor = OSSignposter(
        subsystem: "com.sentinel.health", category: "MemoryMonitor")

    /// Signpost log for Offload Manager operations
    public static let offloadManager = OSSignposter(
        subsystem: "com.sentinel.health", category: "OffloadManager")
}

// MARK: - Signpost Interval Helpers

extension OSSignposter {

    /// Begin an interval for prediction cycle timing
    public func beginPredictionCycle() -> OSSignpostIntervalState {
        beginInterval("Prediction Cycle")
    }

    /// End a prediction cycle interval
    public func endPredictionCycle(_ state: OSSignpostIntervalState) {
        endInterval("Prediction Cycle", state)
    }

    /// Begin an interval for offload operation timing
    public func beginOffloadOperation(processName: String) -> OSSignpostIntervalState {
        beginInterval("Offload Operation", "\(processName)")
    }

    /// End an offload operation interval
    public func endOffloadOperation(_ state: OSSignpostIntervalState, processName: String) {
        endInterval("Offload Operation", state, "\(processName)")
    }

    /// Begin an interval for restore operation timing
    public func beginRestoreOperation(processName: String) -> OSSignpostIntervalState {
        beginInterval("Restore Operation", "\(processName)")
    }

    /// End a restore operation interval
    public func endRestoreOperation(_ state: OSSignpostIntervalState, processName: String) {
        endInterval("Restore Operation", state, "\(processName)")
    }

    /// Begin an interval for metrics sampling
    public func beginMetricsSample() -> OSSignpostIntervalState {
        beginInterval("Metrics Sample")
    }

    /// End a metrics sample interval
    public func endMetricsSample(_ state: OSSignpostIntervalState) {
        endInterval("Metrics Sample", state)
    }
}

// MARK: - Debug Compilation Helpers

#if DEBUG
    /// Debug-only logging that's compiled out in release builds
    public func debugLog(
        _ message: @autoclosure () -> String, category: Logger = SentinelLogger.general
    ) {
        let msg = message()
        category.debug("\(msg)")
    }

#else
    /// No-op in release builds
    @inlinable
    public func debugLog(
        _ message: @autoclosure () -> String, category: Logger = SentinelLogger.general
    ) {
        // Compiled out in release
    }
#endif

// MARK: - Error Logging Extension

extension Logger {

    /// Log a SentinelError with appropriate level and context
    public func log(error: SentinelError, context: String = "") {
        let contextString = context.isEmpty ? "" : "[\(context)] "
        self.error("\(contextString)\(error.localizedDescription, privacy: .public)")

        if let reason = error.failureReason {
            self.debug("Failure reason: \(reason, privacy: .public)")
        }

        if let recovery = error.recoverySuggestion {
            self.debug("Recovery: \(recovery, privacy: .public)")
        }
    }

    /// Log a performance metric
    public func logMetric(name: String, value: Double, unit: String = "ms") {
        self.info(
            "📊 \(name, privacy: .public): \(value, format: .fixed(precision: 2)) \(unit, privacy: .public)"
        )
    }

    /// Log a state transition
    public func logStateTransition(from: String, to: String) {
        self.info("🔄 State: \(from, privacy: .public) → \(to, privacy: .public)")
    }
}
