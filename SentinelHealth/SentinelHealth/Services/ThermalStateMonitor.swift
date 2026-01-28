//
//  ThermalStateMonitor.swift
//  SentinelHealth
//
//  Monitor for thermal state using ProcessInfo and IOKit.
//

import Foundation
import OSLog

// MARK: - Thermal Snapshot

/// Complete snapshot of thermal state at a point in time
public struct ThermalSnapshot: Sendable, Equatable {
    /// ProcessInfo thermal state
    public let thermalState: ProcessInfo.ThermalState

    /// Associated memory metrics
    public let memoryMetrics: MemoryMetrics

    /// Timestamp of the snapshot
    public let timestamp: Date

    /// Whether the system is in a problematic thermal state
    public var isProblematic: Bool {
        thermalState == .serious || thermalState == .critical
    }

    /// Thermal state as a displayable enum
    public var displayState: ThermalDisplayState {
        switch thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }

    /// Human-readable description of thermal state
    public var stateDescription: String {
        switch thermalState {
        case .nominal: return "Optimal - System running cool"
        case .fair: return "Moderate - Slight thermal activity"
        case .serious: return "Warning - Thermal mitigation active"
        case .critical: return "Critical - Thermal throttling imminent"
        @unknown default: return "Unknown thermal state"
        }
    }
}

// MARK: - Thermal State Monitor Actor

/// Actor responsible for monitoring system thermal state.
/// Combines ProcessInfo.thermalState with memory metrics for comprehensive thermal snapshots.
public actor ThermalStateMonitor {

    // MARK: - Properties

    private let logger = SentinelLogger.thermalEngine
    private let memoryMonitor: UnifiedMemoryMonitor

    /// Current polling interval
    private var pollingInterval: TimeInterval

    /// Whether monitoring is active
    private var isMonitoring = false

    /// Continuation for the thermal stream
    private var streamContinuation: AsyncStream<ThermalSnapshot>.Continuation?

    /// Last captured thermal state
    private var lastThermalState: ProcessInfo.ThermalState = .nominal

    /// Last captured snapshot
    private var lastSnapshot: ThermalSnapshot?

    /// Observer token for thermal state notifications (must store to remove later)
    private var thermalObserverToken: (any NSObjectProtocol)?

    // MARK: - Initialization

    /// Initialize thermal state monitor.
    /// - Parameters:
    ///   - memoryMonitor: UnifiedMemoryMonitor instance for memory metrics
    ///   - pollingInterval: Interval between thermal state checks (default: 1 second)
    public init(
        memoryMonitor: UnifiedMemoryMonitor,
        pollingInterval: TimeInterval = SentinelConstants.Monitoring.uiRefreshInterval
    ) {
        self.memoryMonitor = memoryMonitor
        self.pollingInterval = pollingInterval
        logger.info("ThermalStateMonitor initialized")
    }

    // MARK: - Public API

    /// Start monitoring thermal state and return an async stream of snapshots.
    /// Emits on every poll interval AND whenever thermal state changes.
    /// - Returns: AsyncStream emitting ThermalSnapshot
    public func startMonitoring() -> AsyncStream<ThermalSnapshot> {
        logger.info("Starting thermal state monitoring")
        isMonitoring = true

        // Register for thermal state change notifications
        setupThermalStateObserver()

        // Use makeStream to avoid actor isolation issues with continuation
        let (stream, continuation) = AsyncStream<ThermalSnapshot>.makeStream()

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
    private func setStreamContinuation(_ continuation: AsyncStream<ThermalSnapshot>.Continuation) {
        self.streamContinuation = continuation
    }

    /// Stop monitoring thermal state.
    public func stopMonitoring() {
        logger.info("Stopping thermal state monitoring")
        isMonitoring = false
        streamContinuation?.finish()
        streamContinuation = nil
        removeThermalStateObserver()
    }

    /// Get current thermal snapshot immediately (one-shot).
    /// - Returns: Current ThermalSnapshot
    /// - Throws: SentinelError if metrics collection fails
    public func getCurrentSnapshot() async throws -> ThermalSnapshot {
        let thermalState = ProcessInfo.processInfo.thermalState
        let memoryMetrics = try await memoryMonitor.getCurrentMetrics()

        let snapshot = ThermalSnapshot(
            thermalState: thermalState,
            memoryMetrics: memoryMetrics,
            timestamp: Date()
        )

        lastSnapshot = snapshot
        lastThermalState = thermalState

        return snapshot
    }

    /// Get the last captured snapshot without triggering new collection.
    public func getLastSnapshot() -> ThermalSnapshot? {
        lastSnapshot
    }

    /// Get current thermal state without full snapshot.
    public func getCurrentThermalState() -> ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }

    // MARK: - Private Methods

    private func handleStreamTermination() {
        isMonitoring = false
        streamContinuation = nil
        removeThermalStateObserver()
        logger.debug("Thermal monitoring stream terminated")
    }

    private func monitoringLoop() async {
        while isMonitoring {
            do {
                let snapshot = try await captureSnapshot()

                // Check for thermal state change
                if snapshot.thermalState != lastThermalState {
                    logger.logStateTransition(
                        from: describeState(lastThermalState),
                        to: describeState(snapshot.thermalState)
                    )
                    lastThermalState = snapshot.thermalState
                }

                lastSnapshot = snapshot
                streamContinuation?.yield(snapshot)

            } catch {
                logger.warning("Snapshot capture failed: \(error.localizedDescription)")
            }

            try? await Task.sleep(for: .seconds(pollingInterval))
        }
    }

    private func captureSnapshot() async throws -> ThermalSnapshot {
        let thermalState = ProcessInfo.processInfo.thermalState
        let memoryMetrics = try await memoryMonitor.getCurrentMetrics()

        return ThermalSnapshot(
            thermalState: thermalState,
            memoryMetrics: memoryMetrics,
            timestamp: Date()
        )
    }

    private func setupThermalStateObserver() {
        // Store the observer token so we can properly remove it later
        thermalObserverToken = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.handleThermalStateChange()
            }
        }
        logger.debug("Thermal state observer registered")
    }

    private func removeThermalStateObserver() {
        // Remove using the stored token, not 'self'
        if let token = thermalObserverToken {
            NotificationCenter.default.removeObserver(token)
            thermalObserverToken = nil
        }
        logger.debug("Thermal state observer removed")
    }

    private func handleThermalStateChange() async {
        guard isMonitoring else { return }

        let newState = ProcessInfo.processInfo.thermalState
        logger.info("Thermal state changed to: \(self.describeState(newState))")

        // Emit an immediate snapshot on state change
        do {
            let snapshot = try await captureSnapshot()
            lastSnapshot = snapshot
            lastThermalState = newState
            streamContinuation?.yield(snapshot)
        } catch {
            logger.warning(
                "Failed to capture snapshot on state change: \(error.localizedDescription)")
        }
    }

    private func describeState(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - ProcessInfo.ThermalState Extension

extension ProcessInfo.ThermalState: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
