//
//  ProcessOffloadManager.swift
//  SentinelHealth
//
//  Actor managing process suspension and restoration via SIGSTOP/SIGCONT.
//

import Foundation
import OSLog

// MARK: - Offload Result Types

/// Result of an offload operation
public struct OffloadResult: Sendable {
    public let process: ProcessSnapshot
    public let success: Bool
    public let errorMessage: String?
    public let memoryReclaimed: UInt64
    public let timestamp: Date

    public init(
        process: ProcessSnapshot,
        success: Bool,
        errorMessage: String? = nil,
        memoryReclaimed: UInt64 = 0,
        timestamp: Date = Date()
    ) {
        self.process = process
        self.success = success
        self.errorMessage = errorMessage
        self.memoryReclaimed = memoryReclaimed
        self.timestamp = timestamp
    }
}

/// Result of a restore operation
public struct RestoreResult: Sendable {
    /// ID of the restored process record
    public let processId: UUID
    /// Name of the restored process
    public let processName: String
    /// PID of the restored process
    public let pid: Int32
    /// Whether restoration was successful
    public let success: Bool
    /// Error message if failed
    public let errorMessage: String?
    /// How long the process was offloaded
    public let offloadDuration: TimeInterval
    /// Latency of the restore operation in milliseconds
    public let latencyMs: Double
    /// When the restore occurred
    public let timestamp: Date

    public init(
        processId: UUID,
        processName: String,
        pid: Int32,
        success: Bool,
        errorMessage: String? = nil,
        offloadDuration: TimeInterval = 0,
        latencyMs: Double = 0,
        timestamp: Date = Date()
    ) {
        self.processId = processId
        self.processName = processName
        self.pid = pid
        self.success = success
        self.errorMessage = errorMessage
        self.offloadDuration = offloadDuration
        self.latencyMs = latencyMs
        self.timestamp = timestamp
    }

    /// Create from an OffloadedProcessDTO (Sendable)
    public init(
        from dto: OffloadedProcessDTO,
        success: Bool,
        errorMessage: String? = nil,
        latencyMs: Double = 0
    ) {
        self.processId = dto.id
        self.processName = dto.processName
        self.pid = dto.pid
        self.success = success
        self.errorMessage = errorMessage
        self.offloadDuration = dto.offloadDuration
        self.latencyMs = latencyMs
        self.timestamp = Date()
    }
}

// MARK: - Process Offload Manager Actor

/// Actor responsible for suspending and restoring processes to reclaim memory.
/// Uses OffloadedProcessDTO (Sendable) internally to avoid SwiftData concurrency issues.
public actor ProcessOffloadManager {

    // MARK: - Properties

    private let logger = SentinelLogger.offloadManager
    private let signposter = SentinelSignpost.offloadManager

    /// Currently offloaded processes (keyed by original PID)
    /// Uses Sendable DTO instead of SwiftData model to comply with Swift 6 concurrency
    private var offloadedProcesses: [pid_t: OffloadedProcessDTO] = [:]

    /// Data store for persistence
    private let dataStore: HistoricalAnalyticsStore?

    /// Delegate for notifications
    private weak var delegate: ProcessOffloadDelegate?

    /// Maximum concurrent offloads
    private let maxConcurrentOffloads: Int

    /// Whether automatic restoration is enabled
    private var autoRestoreEnabled: Bool = true

    // MARK: - Initialization

    /// Initialize the process offload manager.
    /// - Parameters:
    ///   - dataStore: Optional data store for persistence
    ///   - maxConcurrentOffloads: Maximum processes to offload simultaneously
    public init(
        dataStore: HistoricalAnalyticsStore? = nil,
        maxConcurrentOffloads: Int = SentinelConstants.Offloading.maxConcurrentOffloads
    ) {
        self.dataStore = dataStore
        self.maxConcurrentOffloads = maxConcurrentOffloads
        logger.info("ProcessOffloadManager initialized (max concurrent: \(maxConcurrentOffloads))")
    }

    /// Set the delegate for notifications.
    public func setDelegate(_ delegate: ProcessOffloadDelegate?) {
        self.delegate = delegate
    }

    // MARK: - Offload Operations

    /// Offload (suspend) a process.
    /// - Parameter process: Process snapshot to offload
    /// - Returns: OffloadResult indicating success or failure
    public func offloadProcess(_ process: ProcessSnapshot) async -> OffloadResult {
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("offload", id: signpostID)
        defer { signposter.endInterval("offload", state) }

        logger.info("Offloading process: \(process.name) (PID: \(process.pid))")

        // Validate process can be offloaded
        guard process.isSafeToSuspend else {
            logger.warning("Process \(process.name) is not safe to suspend")
            return OffloadResult(
                process: process,
                success: false,
                errorMessage: "Process is not safe to suspend"
            )
        }

        // Check if already offloaded
        if offloadedProcesses[process.pid] != nil {
            logger.warning("Process \(process.name) is already offloaded")
            return OffloadResult(
                process: process,
                success: false,
                errorMessage: "Process already offloaded"
            )
        }

        // Check concurrent limit
        if offloadedProcesses.count >= maxConcurrentOffloads {
            logger.warning("Maximum concurrent offloads reached")
            return OffloadResult(
                process: process,
                success: false,
                errorMessage: "Maximum concurrent offloads reached"
            )
        }

        // Send SIGSTOP to suspend the process
        let result = kill(process.pid, SIGSTOP)

        if result == 0 {
            // Create offload record using Sendable DTO
            let offloadRecord = OffloadedProcessDTO(
                pid: process.pid,
                processName: process.name,
                bundleIdentifier: process.bundleIdentifier,
                memoryBytes: Int64(process.memoryBytes),
                cpuUsageAtOffload: process.cpuUsage,
                idleDurationBeforeOffload: process.idleDuration,
                executablePath: process.executablePath,
                status: .suspended
            )

            offloadedProcesses[process.pid] = offloadRecord

            // Notify delegate with DTO (safe to pass across actor boundaries)
            await delegate?.processWasOffloaded(offloadRecord)

            return OffloadResult(
                process: process,
                success: true,
                memoryReclaimed: process.memoryBytes
            )
        } else {
            let errorCode = errno
            let errorMessage = String(cString: strerror(errorCode))
            logger.error("Failed to suspend \(process.name): \(errorMessage)")

            return OffloadResult(
                process: process,
                success: false,
                errorMessage: "SIGSTOP failed: \(errorMessage)"
            )
        }
    }

    /// Offload multiple processes.
    /// - Parameter processes: Array of process snapshots to offload
    /// - Returns: Array of offload results
    public func offloadProcesses(_ processes: [ProcessSnapshot]) async -> [OffloadResult] {
        logger.info("Batch offloading \(processes.count) processes")

        var results: [OffloadResult] = []

        for process in processes {
            let result = await offloadProcess(process)
            results.append(result)

            // Check if we've hit the limit
            if offloadedProcesses.count >= maxConcurrentOffloads {
                break
            }
        }

        let successCount = results.filter { $0.success }.count
        let totalReclaimed = results.filter { $0.success }.reduce(0) { $0 + $1.memoryReclaimed }

        logger.info(
            "Batch offload complete: \(successCount)/\(processes.count) succeeded, \(MemoryMetrics.formatBytes(totalReclaimed)) reclaimed"
        )

        return results
    }

    // MARK: - Restore Operations

    /// Restore (resume) an offloaded process.
    /// - Parameters:
    ///   - pid: PID of the process to restore
    ///   - reason: Reason for restoration
    /// - Returns: RestoreResult indicating success or failure
    public func restoreProcess(pid: pid_t, reason: RestorationReason) async -> RestoreResult? {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let offloadRecord = offloadedProcesses[pid] else {
            logger.warning("Process with PID \(pid) not found in offloaded list")
            return nil
        }

        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("restore", id: signpostID)
        defer { signposter.endInterval("restore", state) }

        logger.info(
            "Restoring process: \(offloadRecord.processName) (PID: \(pid), reason: \(reason.rawValue))"
        )

        // Check if process still exists
        let processExists = kill(pid, 0) == 0 || errno == EPERM

        if !processExists {
            // Process terminated while suspended - update DTO immutably
            let terminatedRecord = offloadRecord.markedTerminated()
            offloadedProcesses.removeValue(forKey: pid)

            logger.info("Process \(offloadRecord.processName) terminated while suspended")

            return RestoreResult(
                from: terminatedRecord,
                success: true,
                errorMessage: "Process terminated while suspended"
            )
        }

        // Send SIGCONT to resume the process
        let result = kill(pid, SIGCONT)
        let latencyMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        if result == 0 {
            // Update record immutably using DTO
            let restoredRecord = offloadRecord.markedRestored(reason: reason)
            offloadedProcesses.removeValue(forKey: pid)

            // Notify delegate with Sendable DTO
            await delegate?.processWasRestored(restoredRecord, reason: reason)

            return RestoreResult(
                from: restoredRecord,
                success: true,
                latencyMs: latencyMs
            )
        } else {
            let errorCode = errno
            let errorMessage = String(cString: strerror(errorCode))

            let failedRecord = offloadRecord.markedFailed(error: errorMessage)
            offloadedProcesses.removeValue(forKey: pid)

            logger.error("Failed to restore \(offloadRecord.processName): \(errorMessage)")

            return RestoreResult(
                from: failedRecord,
                success: false,
                errorMessage: "SIGCONT failed: \(errorMessage)",
                latencyMs: latencyMs
            )
        }
    }

    /// Restore all offloaded processes.
    /// - Parameter reason: Reason for restoration
    /// - Returns: Array of restore results
    public func restoreAllProcesses(reason: RestorationReason) async -> [RestoreResult] {
        logger.info("Restoring all \(self.offloadedProcesses.count) offloaded processes")

        var results: [RestoreResult] = []
        let pids = Array(offloadedProcesses.keys)

        for pid in pids {
            if let result = await restoreProcess(pid: pid, reason: reason) {
                results.append(result)
            }
        }

        let successCount = results.filter { $0.success }.count
        logger.info("Batch restore complete: \(successCount)/\(pids.count) succeeded")

        return results
    }

    // MARK: - Query Methods

    /// Get list of currently offloaded processes (as Sendable DTOs).
    public func getOffloadedProcesses() -> [OffloadedProcessDTO] {
        Array(offloadedProcesses.values).sorted { $0.offloadedAt > $1.offloadedAt }
    }

    /// Get count of currently offloaded processes.
    public var offloadedCount: Int {
        offloadedProcesses.count
    }

    /// Get total memory currently reclaimed.
    public var totalMemoryReclaimed: UInt64 {
        offloadedProcesses.values.reduce(0) { $0 + UInt64(max(0, $1.memoryBytes)) }
    }

    /// Check if a process is currently offloaded.
    public func isOffloaded(pid: pid_t) -> Bool {
        offloadedProcesses[pid] != nil
    }

    // MARK: - Auto-Restore

    /// Enable or disable automatic restoration.
    public func setAutoRestoreEnabled(_ enabled: Bool) {
        autoRestoreEnabled = enabled
        logger.info("Auto-restore \(enabled ? "enabled" : "disabled")")
    }

    /// Handle app activation event (user switched to offloaded app).
    /// - Parameter bundleIdentifier: Bundle ID of activated app
    public func handleAppActivation(bundleIdentifier: String) async {
        guard autoRestoreEnabled else { return }

        for (pid, record) in offloadedProcesses {
            if record.bundleIdentifier == bundleIdentifier {
                _ = await restoreProcess(pid: pid, reason: .userActivation)
                break
            }
        }
    }

    /// Handle thermal state cleared event.
    public func handleThermalCleared() async {
        guard autoRestoreEnabled else { return }

        // Restore processes in order of shortest offload duration first
        let sorted = offloadedProcesses.sorted { $0.value.offloadedAt > $1.value.offloadedAt }

        for (pid, _) in sorted {
            _ = await restoreProcess(pid: pid, reason: .thermalCleared)
        }
    }

    /// Prepare for app termination - restore all processes.
    public func prepareForTermination() async {
        logger.info("App terminating - restoring all offloaded processes")
        _ = await restoreAllProcesses(reason: .appShutdown)
    }
}

// MARK: - Delegate Protocol

/// Delegate protocol for process offload notifications.
/// Uses Sendable DTOs for safe cross-actor communication.
public protocol ProcessOffloadDelegate: AnyObject, Sendable {
    /// Called when a process is successfully offloaded.
    func processWasOffloaded(_ process: OffloadedProcessDTO) async

    /// Called when a process is restored.
    func processWasRestored(_ process: OffloadedProcessDTO, reason: RestorationReason) async
}
