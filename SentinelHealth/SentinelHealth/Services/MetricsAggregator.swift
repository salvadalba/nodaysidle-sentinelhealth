//
//  MetricsAggregator.swift
//  SentinelHealth
//
//  Aggregates memory, thermal, and process metrics for UI and ML inference.
//

import Foundation
import OSLog
import Observation

// MARK: - Metrics Snapshot

/// Complete system metrics snapshot
public struct MetricsSnapshot: Sendable, Equatable {
    /// Current thermal snapshot
    public let thermalSnapshot: ThermalSnapshot

    /// Top process candidates for offloading
    public let offloadCandidates: [ProcessSnapshot]

    /// Total number of running user processes
    public let userProcessCount: Int

    /// Total memory used by offload candidates
    public let potentialSavings: UInt64

    /// Timestamp of the snapshot
    public let timestamp: Date

    /// Convenience accessor for thermal state
    public var thermalState: ProcessInfo.ThermalState {
        thermalSnapshot.thermalState
    }

    /// Convenience accessor for memory metrics
    public var memoryMetrics: MemoryMetrics {
        thermalSnapshot.memoryMetrics
    }

    /// Formatted potential memory savings
    public var formattedPotentialSavings: String {
        MemoryMetrics.formatBytes(potentialSavings)
    }
}

// MARK: - Metrics Aggregator

/// Observable class that aggregates all system metrics for UI consumption.
/// Publishes updates at configurable intervals.
@Observable
public final class MetricsAggregator: @unchecked Sendable {

    // MARK: - Published Properties

    /// Current aggregated metrics snapshot
    public private(set) var currentSnapshot: MetricsSnapshot?

    /// Current thermal display state for UI binding
    public private(set) var thermalDisplayState: ThermalDisplayState = .nominal

    /// Current memory usage percentage (0-1)
    public private(set) var memoryUsagePercentage: Double = 0

    /// Current number of offloaded processes
    public private(set) var offloadedProcessCount: Int = 0

    /// Whether monitoring is active
    public private(set) var isMonitoring: Bool = false

    /// Prediction accuracy over last 100 predictions
    public private(set) var predictionAccuracy: Double = 0

    /// ML inference latency in milliseconds
    public private(set) var inferenceLatencyMs: Double = 0

    // MARK: - Private Properties

    private let logger = SentinelLogger.memoryMonitor
    private let memoryMonitor: UnifiedMemoryMonitor
    private let thermalMonitor: ThermalStateMonitor
    private let processEnumerator: ProcessEnumerator

    /// Polling interval for UI updates
    private var uiPollingInterval: TimeInterval

    /// Polling interval for ML inference
    private var mlPollingInterval: TimeInterval

    /// Active monitoring task
    private var monitoringTask: Task<Void, Never>?

    /// Lock for thread-safe property updates
    private let lock = NSLock()

    // MARK: - Initialization

    /// Initialize the metrics aggregator with component monitors.
    /// - Parameters:
    ///   - uiPollingInterval: Interval for UI updates (default: 1Hz)
    ///   - mlPollingInterval: Interval for ML inference (default: 10Hz)
    public init(
        uiPollingInterval: TimeInterval = SentinelConstants.Monitoring.uiRefreshInterval,
        mlPollingInterval: TimeInterval = SentinelConstants.Monitoring.mlInferenceInterval
    ) {
        self.uiPollingInterval = uiPollingInterval
        self.mlPollingInterval = mlPollingInterval

        // Initialize sub-monitors
        self.memoryMonitor = UnifiedMemoryMonitor(pollingInterval: uiPollingInterval)
        self.thermalMonitor = ThermalStateMonitor(
            memoryMonitor: memoryMonitor,
            pollingInterval: uiPollingInterval
        )
        self.processEnumerator = ProcessEnumerator()

        logger.info("MetricsAggregator initialized")
    }

    // MARK: - Public API

    /// Start aggregating metrics and publishing updates.
    public func startMonitoring() async {
        guard !isMonitoring else {
            logger.warning("Monitoring already active")
            return
        }

        logger.info("Starting metrics aggregation")
        updateProperty { self.isMonitoring = true }

        monitoringTask = Task { [weak self] in
            await self?.runMonitoringLoop()
        }
    }

    /// Stop aggregating metrics.
    public func stopMonitoring() async {
        logger.info("Stopping metrics aggregation")

        monitoringTask?.cancel()
        monitoringTask = nil

        await memoryMonitor.stopMonitoring()
        await thermalMonitor.stopMonitoring()

        updateProperty { self.isMonitoring = false }
    }

    /// Force an immediate metrics refresh.
    public func refresh() async {
        do {
            let snapshot = try await captureSnapshot()
            updateProperty {
                self.currentSnapshot = snapshot
                self.thermalDisplayState = snapshot.thermalSnapshot.displayState
                self.memoryUsagePercentage = snapshot.memoryMetrics.usagePercentage
            }
        } catch {
            logger.error("Failed to refresh metrics: \(error.localizedDescription)")
        }
    }

    /// Get the thermal state monitor for direct access.
    public func getThermalMonitor() -> ThermalStateMonitor {
        thermalMonitor
    }

    /// Get the memory monitor for direct access.
    public func getMemoryMonitor() -> UnifiedMemoryMonitor {
        memoryMonitor
    }

    /// Get the process enumerator for direct access.
    public func getProcessEnumerator() -> ProcessEnumerator {
        processEnumerator
    }

    /// Update offloaded process count (called by ProcessOffloadManager).
    public func setOffloadedProcessCount(_ count: Int) {
        updateProperty { self.offloadedProcessCount = count }
    }

    /// Update prediction accuracy (called by ThermalIntelligenceEngine).
    public func setPredictionAccuracy(_ accuracy: Double) {
        updateProperty { self.predictionAccuracy = accuracy }
    }

    /// Update inference latency (called by ThermalIntelligenceEngine).
    public func setInferenceLatency(_ latencyMs: Double) {
        updateProperty { self.inferenceLatencyMs = latencyMs }
        logger.logMetric(name: "thermal_prediction_latency", value: latencyMs)
    }

    // MARK: - Private Methods

    private func runMonitoringLoop() async {
        while !Task.isCancelled && isMonitoring {
            do {
                let snapshot = try await captureSnapshot()

                updateProperty {
                    self.currentSnapshot = snapshot
                    self.thermalDisplayState = snapshot.thermalSnapshot.displayState
                    self.memoryUsagePercentage = snapshot.memoryMetrics.usagePercentage
                }

            } catch {
                logger.warning("Monitoring loop error: \(error.localizedDescription)")
            }

            try? await Task.sleep(for: .seconds(uiPollingInterval))
        }
    }

    private func captureSnapshot() async throws -> MetricsSnapshot {
        // Get thermal snapshot
        let thermalSnapshot = try await thermalMonitor.getCurrentSnapshot()

        // Get offload candidates
        let candidates = try await processEnumerator.getOffloadCandidates(limit: 10)

        // Get total user process count
        let allProcesses = try await processEnumerator.enumerateProcesses()

        // Calculate potential savings
        let potentialSavings = candidates.reduce(0) { $0 + $1.memoryBytes }

        return MetricsSnapshot(
            thermalSnapshot: thermalSnapshot,
            offloadCandidates: candidates,
            userProcessCount: allProcesses.count,
            potentialSavings: potentialSavings,
            timestamp: Date()
        )
    }

    /// Thread-safe property update helper
    private func updateProperty(_ update: @escaping () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        update()
    }
}

// MARK: - Metric Recording Helpers

extension MetricsAggregator {

    /// Record a memory reclaim event
    public func recordMemoryReclaimed(bytes: UInt64) {
        logger.logMetric(name: "memory_reclaimed_bytes", value: Double(bytes), unit: "bytes")
    }

    /// Record an offload operation result
    public func recordOffloadOperation(success: Bool) {
        logger.info("Offload operation \(success ? "succeeded" : "failed")")
    }

    /// Record restore latency
    public func recordRestoreLatency(milliseconds: Double) {
        logger.logMetric(name: "restore_latency", value: milliseconds)
    }
}
