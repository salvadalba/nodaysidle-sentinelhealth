//
//  UnifiedMemoryMonitor.swift
//  SentinelHealth
//
//  Actor-isolated monitor for M4 unified memory and system metrics.
//

import Foundation
import OSLog

// MARK: - Memory Metrics Types

/// Snapshot of unified memory metrics at a point in time
public struct MemoryMetrics: Sendable, Equatable {
    /// Total physical memory in bytes
    public let totalMemory: UInt64

    /// Currently used memory in bytes
    public let usedMemory: UInt64

    /// Available memory in bytes
    public let availableMemory: UInt64

    /// Memory pressure level (0.0 to 1.0)
    public let pressureLevel: Double

    /// Wired (non-swappable) memory in bytes
    public let wiredMemory: UInt64

    /// Compressed memory in bytes
    public let compressedMemory: UInt64

    /// Timestamp of the measurement
    public let timestamp: Date

    /// Memory usage as a percentage (0.0 to 1.0)
    public var usagePercentage: Double {
        guard totalMemory > 0 else { return 0 }
        return Double(usedMemory) / Double(totalMemory)
    }

    /// Human-readable memory pressure description
    public var pressureDescription: String {
        switch pressureLevel {
        case 0..<0.5: return "Normal"
        case 0.5..<0.75: return "Moderate"
        case 0.75..<0.9: return "High"
        default: return "Critical"
        }
    }
}

/// Memory pressure level enumeration
public enum MemoryPressureLevel: String, Sendable, CaseIterable {
    case normal
    case moderate
    case high
    case critical

    init(from value: Double) {
        switch value {
        case 0..<0.5: self = .normal
        case 0.5..<0.75: self = .moderate
        case 0.75..<0.9: self = .high
        default: self = .critical
        }
    }
}

// MARK: - Unified Memory Monitor Actor

/// Actor responsible for monitoring unified memory metrics on Apple Silicon Macs.
/// Uses IOKit and mach APIs to collect memory pressure, usage, and related metrics.
public actor UnifiedMemoryMonitor {

    // MARK: - Properties

    private let logger = SentinelLogger.memoryMonitor
    private let signposter = SentinelSignpost.memoryMonitor

    /// Current polling interval
    private var pollingInterval: TimeInterval

    /// Whether monitoring is currently active
    private var isMonitoring = false

    /// Continuation for the metrics stream
    private var streamContinuation: AsyncStream<MemoryMetrics>.Continuation?

    /// Last collected metrics
    private var lastMetrics: MemoryMetrics?

    // MARK: - Initialization

    /// Initialize the memory monitor with a specified polling interval.
    /// - Parameter pollingInterval: Interval between metric samples (default: 1 second)
    public init(pollingInterval: TimeInterval = SentinelConstants.Monitoring.uiRefreshInterval) {
        self.pollingInterval = pollingInterval
        logger.info("UnifiedMemoryMonitor initialized with \(pollingInterval)s polling interval")
    }

    // MARK: - Public API

    /// Start monitoring and return an async stream of memory metrics.
    /// - Returns: AsyncStream emitting MemoryMetrics at the configured interval
    public func startMonitoring() -> AsyncStream<MemoryMetrics> {
        logger.info("Starting memory monitoring")
        isMonitoring = true

        // Use makeStream to avoid actor isolation issues with continuation
        let (stream, continuation) = AsyncStream<MemoryMetrics>.makeStream()

        // Store continuation in actor-isolated property via Task
        Task { [weak self] in
            await self?.setStreamContinuation(continuation)
            await self?.monitoringLoop()
        }

        continuation.onTermination = { [weak self] _ in
            Task { [weak self] in
                await self?.handleStreamTermination()
            }
        }

        return stream
    }

    /// Set the stream continuation (actor-isolated helper)
    private func setStreamContinuation(_ continuation: AsyncStream<MemoryMetrics>.Continuation) {
        self.streamContinuation = continuation
    }

    /// Stop monitoring memory metrics.
    public func stopMonitoring() {
        logger.info("Stopping memory monitoring")
        isMonitoring = false
        streamContinuation?.finish()
        streamContinuation = nil
    }

    /// Get current memory metrics immediately (one-shot).
    /// - Returns: Current MemoryMetrics snapshot
    /// - Throws: SentinelError.memoryMetricsUnavailable if collection fails
    public func getCurrentMetrics() throws -> MemoryMetrics {
        let state = signposter.beginMetricsSample()
        defer { signposter.endMetricsSample(state) }

        do {
            let metrics = try collectMetrics()
            lastMetrics = metrics
            return metrics
        } catch {
            logger.error("Failed to collect memory metrics: \(error.localizedDescription)")
            throw SentinelError.memoryMetricsUnavailable(reason: error.localizedDescription)
        }
    }

    /// Update the polling interval.
    /// - Parameter interval: New polling interval in seconds
    public func setPollingInterval(_ interval: TimeInterval) {
        pollingInterval = max(0.1, interval)  // Minimum 100ms
        logger.info("Polling interval updated to \(interval)s")
    }

    /// Get the last collected metrics without triggering a new collection.
    public func getLastMetrics() -> MemoryMetrics? {
        lastMetrics
    }

    // MARK: - Private Methods

    private func handleStreamTermination() {
        isMonitoring = false
        streamContinuation = nil
        logger.debug("Memory monitoring stream terminated")
    }

    private func monitoringLoop() async {
        while isMonitoring {
            do {
                let metrics = try collectMetrics()
                lastMetrics = metrics
                streamContinuation?.yield(metrics)
            } catch {
                logger.warning("Metrics collection failed: \(error.localizedDescription)")
            }

            try? await Task.sleep(for: .seconds(pollingInterval))
        }
    }

    private func collectMetrics() throws -> MemoryMetrics {
        // Get VM statistics
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            throw SentinelError.memoryMetricsUnavailable(
                reason: "host_statistics64 failed with code \(result)")
        }

        // Get page size - use getpagesize() for thread-safe access
        let pageSize = UInt64(getpagesize())

        // Calculate memory values
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let freePages = UInt64(vmStats.free_count)
        let activePages = UInt64(vmStats.active_count)
        let inactivePages = UInt64(vmStats.inactive_count)
        let wiredPages = UInt64(vmStats.wire_count)
        let compressedPages = UInt64(vmStats.compressor_page_count)
        let speculativePages = UInt64(vmStats.speculative_count)

        // Available memory includes free, inactive, and speculative pages
        let availableMemory = (freePages + inactivePages + speculativePages) * pageSize
        let wiredMemory = wiredPages * pageSize
        let compressedMemory = compressedPages * pageSize
        let usedMemory = (activePages + wiredPages + compressedPages) * pageSize

        // Calculate pressure level (0.0 to 1.0)
        let pressureLevel = 1.0 - (Double(availableMemory) / Double(totalMemory))

        return MemoryMetrics(
            totalMemory: totalMemory,
            usedMemory: usedMemory,
            availableMemory: availableMemory,
            pressureLevel: min(1.0, max(0.0, pressureLevel)),
            wiredMemory: wiredMemory,
            compressedMemory: compressedMemory,
            timestamp: Date()
        )
    }
}

// MARK: - Memory Formatting Helpers

extension MemoryMetrics {
    /// Format bytes as human-readable string (e.g., "16.0 GB")
    public static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    /// Formatted total memory string
    public var formattedTotal: String {
        Self.formatBytes(totalMemory)
    }

    /// Formatted used memory string
    public var formattedUsed: String {
        Self.formatBytes(usedMemory)
    }

    /// Formatted available memory string
    public var formattedAvailable: String {
        Self.formatBytes(availableMemory)
    }
}
