//
//  ProcessEnumerator.swift
//  SentinelHealth
//
//  Service for enumerating running processes with resource usage metrics.
//

import Darwin
import Foundation
import OSLog

// MARK: - Process Info Types

/// Information about a running process
public struct ProcessSnapshot: Sendable, Identifiable, Equatable {
    /// Process ID
    public let pid: pid_t

    /// Process name (executable name)
    public let name: String

    /// Bundle identifier (if available)
    public let bundleIdentifier: String?

    /// Memory footprint in bytes
    public let memoryBytes: UInt64

    /// CPU usage percentage (0-100)
    public let cpuUsage: Double

    /// Estimated idle duration in seconds
    public let idleDuration: TimeInterval

    /// Whether this process is safe to suspend
    public let isSafeToSuspend: Bool

    /// Path to the executable
    public let executablePath: String?

    /// Timestamp of the snapshot
    public let timestamp: Date

    public var id: pid_t { pid }

    /// Formatted memory footprint
    public var formattedMemory: String {
        MemoryMetrics.formatBytes(memoryBytes)
    }

    /// Whether this process is a good candidate for offloading
    public var isOffloadCandidate: Bool {
        isSafeToSuspend && memoryBytes >= SentinelConstants.Offloading.minimumMemoryFootprint
            && idleDuration >= SentinelConstants.Offloading.minimumIdleTime
    }
}

/// Filter options for process enumeration
public struct ProcessFilter: Sendable {
    /// Only include user-level processes
    public var userProcessesOnly: Bool = true

    /// Minimum memory footprint to include (bytes)
    public var minimumMemory: UInt64 = 0

    /// Minimum idle time to include (seconds)
    public var minimumIdleTime: TimeInterval = 0

    /// Exclude system-critical processes
    public var excludeSystemCritical: Bool = true

    /// Custom bundle IDs to exclude
    public var excludedBundleIDs: Set<String> = []

    public init() {}

    /// Default filter for offload candidates
    public static var offloadCandidates: ProcessFilter {
        var filter = ProcessFilter()
        filter.minimumMemory = SentinelConstants.Offloading.minimumMemoryFootprint
        filter.minimumIdleTime = SentinelConstants.Offloading.minimumIdleTime
        return filter
    }
}

// MARK: - Process Enumerator Actor

/// Actor responsible for enumerating running processes and collecting resource metrics.
public actor ProcessEnumerator {

    // MARK: - Properties

    private let logger = SentinelLogger.offloadManager

    /// Cache of last enumerated processes
    private var processCache: [pid_t: ProcessSnapshot] = [:]

    /// Last enumeration timestamp
    private var lastEnumerationTime: Date?

    // MARK: - Initialization

    public init() {
        logger.info("ProcessEnumerator initialized")
    }

    // MARK: - Public API

    /// Enumerate all running processes matching the filter.
    /// - Parameter filter: Filter options for process selection
    /// - Returns: Array of ProcessSnapshot for matching processes
    public func enumerateProcesses(filter: ProcessFilter = ProcessFilter()) async throws
        -> [ProcessSnapshot]
    {
        logger.debug("Enumerating processes with filter")

        var processes: [ProcessSnapshot] = []

        // Get list of all running processes
        let pids = try getRunningPIDs()

        for pid in pids {
            guard let snapshot = try? await getProcessSnapshot(pid: pid) else {
                continue
            }

            // Apply filters
            if filter.userProcessesOnly && !isUserProcess(snapshot) {
                continue
            }

            if filter.excludeSystemCritical && !snapshot.isSafeToSuspend {
                continue
            }

            if snapshot.memoryBytes < filter.minimumMemory {
                continue
            }

            if snapshot.idleDuration < filter.minimumIdleTime {
                continue
            }

            if let bundleID = snapshot.bundleIdentifier,
                filter.excludedBundleIDs.contains(bundleID)
            {
                continue
            }

            processes.append(snapshot)
            processCache[pid] = snapshot
        }

        lastEnumerationTime = Date()
        logger.info("Enumerated \(processes.count) processes matching filter")

        return processes
    }

    /// Get snapshot for a specific process by PID.
    /// - Parameter pid: Process ID
    /// - Returns: ProcessSnapshot for the process
    /// - Throws: SentinelError.processNotFound if process doesn't exist
    public func getProcessSnapshot(pid: pid_t) async throws -> ProcessSnapshot {
        // Get process name
        guard let name = getProcessName(pid: pid) else {
            throw SentinelError.processNotFound(pid: pid)
        }

        // Get bundle identifier
        let bundleID = getBundleIdentifier(pid: pid)

        // Get memory footprint
        let memoryBytes = getMemoryFootprint(pid: pid)

        // Get CPU usage (estimated)
        let cpuUsage = getCPUUsage(pid: pid)

        // Get executable path
        let executablePath = getExecutablePath(pid: pid)

        // Estimate idle duration (simplified - would need more sophisticated tracking)
        let idleDuration = estimateIdleDuration(pid: pid)

        // Determine if safe to suspend
        let isSafe = isSafeToSuspend(name: name, bundleID: bundleID)

        return ProcessSnapshot(
            pid: pid,
            name: name,
            bundleIdentifier: bundleID,
            memoryBytes: memoryBytes,
            cpuUsage: cpuUsage,
            idleDuration: idleDuration,
            isSafeToSuspend: isSafe,
            executablePath: executablePath,
            timestamp: Date()
        )
    }

    /// Get offload candidates ranked by memory footprint and idle time.
    /// - Parameter limit: Maximum number of candidates to return
    /// - Returns: Array of ProcessSnapshot sorted by offload priority
    public func getOffloadCandidates(limit: Int = 10) async throws -> [ProcessSnapshot] {
        let filter = ProcessFilter.offloadCandidates
        let processes = try await enumerateProcesses(filter: filter)

        // Sort by memory footprint (descending) and idle time (descending)
        let sorted = processes.sorted { a, b in
            // Primary sort: memory footprint
            if a.memoryBytes != b.memoryBytes {
                return a.memoryBytes > b.memoryBytes
            }
            // Secondary sort: idle duration
            return a.idleDuration > b.idleDuration
        }

        return Array(sorted.prefix(limit))
    }

    /// Check if a process is still running.
    /// - Parameter pid: Process ID
    /// - Returns: True if process exists
    public func isProcessRunning(pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    // MARK: - Private Methods

    private func getRunningPIDs() throws -> [pid_t] {
        // Use sysctl to get process list
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        var size: Int = 0

        // Get size needed
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0 else {
            throw SentinelError.memoryMetricsUnavailable(reason: "Failed to get process list size")
        }

        // Allocate buffer
        let count = size / MemoryLayout<kinfo_proc>.stride
        var processes = [kinfo_proc](repeating: kinfo_proc(), count: count)

        // Get process info
        guard sysctl(&mib, 3, &processes, &size, nil, 0) == 0 else {
            throw SentinelError.memoryMetricsUnavailable(reason: "Failed to get process list")
        }

        // Extract PIDs
        let actualCount = size / MemoryLayout<kinfo_proc>.stride
        return (0..<actualCount).map { processes[$0].kp_proc.p_pid }
    }

    private func getProcessName(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let result = proc_name(pid, &buffer, UInt32(buffer.count))
        guard result > 0 else { return nil }
        return String(cString: buffer)
    }

    private func getBundleIdentifier(pid: pid_t) -> String? {
        // Get app path and try to read bundle info
        guard let path = getExecutablePath(pid: pid) else { return nil }

        // Navigate up to .app bundle if possible
        let url = URL(fileURLWithPath: path)
        var bundleURL = url

        // Walk up path looking for .app bundle
        while bundleURL.pathExtension != "app" && bundleURL.path != "/" {
            bundleURL = bundleURL.deletingLastPathComponent()
        }

        guard bundleURL.pathExtension == "app" else { return nil }
        return Bundle(url: bundleURL)?.bundleIdentifier
    }

    private func getExecutablePath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let result = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard result > 0 else { return nil }
        return String(cString: buffer)
    }

    private func getMemoryFootprint(pid: pid_t) -> UInt64 {
        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.stride
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))

        guard result == size else { return 0 }
        return info.pti_resident_size
    }

    private func getCPUUsage(pid: pid_t) -> Double {
        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.stride
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))

        guard result == size else { return 0 }

        // Convert to percentage (simplified)
        let totalTime = info.pti_total_user + info.pti_total_system
        // This is a simplified calculation - real CPU % requires delta measurement
        return min(100.0, Double(totalTime) / 1_000_000_000.0)
    }

    private func estimateIdleDuration(pid: pid_t) -> TimeInterval {
        // Simplified idle estimation based on CPU usage
        // In a real implementation, we'd track actual user interaction events
        let cpuUsage = getCPUUsage(pid: pid)

        // If CPU usage is very low, estimate longer idle time
        if cpuUsage < 0.1 {
            // Check if we have cached data for trend analysis
            if let cached = processCache[pid] {
                // If it was already idle, add to the duration
                if cached.cpuUsage < 0.1 {
                    return cached.idleDuration + Date().timeIntervalSince(cached.timestamp)
                }
            }
            return 60.0  // Conservative estimate for newly idle processes
        }

        return 0  // Process is actively using CPU
    }

    private func isUserProcess(_ snapshot: ProcessSnapshot) -> Bool {
        // Exclude kernel-level processes
        guard snapshot.pid > 0 else { return false }

        // Check if in Applications folder or user space
        if let path = snapshot.executablePath {
            return path.contains("/Applications/") || path.contains("/Users/")
                || path.contains("/Library/")
        }

        return true
    }

    private func isSafeToSuspend(name: String, bundleID: String?) -> Bool {
        // Check protected process names
        if SentinelConstants.SystemProcesses.protectedProcessNames.contains(name) {
            return false
        }

        // Check protected bundle IDs
        if let bundleID = bundleID,
            SentinelConstants.SystemProcesses.protected.contains(bundleID)
        {
            return false
        }

        return true
    }
}

// MARK: - C Library Imports

// proc_pidinfo constants
private let PROC_PIDTASKINFO: Int32 = 4
