//
//  ThermalEvent.swift
//  SentinelHealth
//
//  SwiftData model for historical thermal events and predictions.
//

import Foundation
import SwiftData

/// SwiftData model representing a thermal event with prediction and outcome.
@Model
public final class ThermalEvent {

    // MARK: - Identifiers

    /// Unique identifier for this event
    @Attribute(.unique)
    public var id: UUID

    // MARK: - Prediction Data

    /// Timestamp when prediction was made
    public var predictionTimestamp: Date

    /// Predicted thermal risk level (0-1)
    public var predictedRisk: Double

    /// Confidence level of the prediction (0-1)
    public var predictionConfidence: Double

    /// Predicted thermal state
    public var predictedState: ThermalStateValue

    // MARK: - Actual Outcome

    /// Actual thermal state observed
    public var actualState: ThermalStateValue?

    /// Timestamp when actual state was observed
    public var actualStateTimestamp: Date?

    /// Whether prediction was accurate
    public var predictionAccurate: Bool?

    // MARK: - System State at Prediction

    /// Memory usage percentage at time of prediction
    public var memoryUsageAtPrediction: Double

    /// Memory pressure level at time of prediction
    public var memoryPressureAtPrediction: Double

    /// CPU overhead of daemon at time of prediction
    public var daemonCPUOverhead: Double?

    // MARK: - Actions Taken

    /// Number of processes offloaded in response
    public var processesOffloadedCount: Int

    /// Total memory reclaimed from offloading (bytes)
    public var memoryReclaimedBytes: Int64

    /// Whether user was notified
    public var userNotified: Bool

    // MARK: - Relationships

    /// Processes that were offloaded during this event
    @Relationship(deleteRule: .cascade)
    public var offloadedProcesses: [OffloadedProcess]

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        predictionTimestamp: Date = Date(),
        predictedRisk: Double,
        predictionConfidence: Double,
        predictedState: ThermalStateValue,
        memoryUsageAtPrediction: Double,
        memoryPressureAtPrediction: Double,
        daemonCPUOverhead: Double? = nil,
        processesOffloadedCount: Int = 0,
        memoryReclaimedBytes: Int64 = 0,
        userNotified: Bool = false
    ) {
        self.id = id
        self.predictionTimestamp = predictionTimestamp
        self.predictedRisk = predictedRisk
        self.predictionConfidence = predictionConfidence
        self.predictedState = predictedState
        self.memoryUsageAtPrediction = memoryUsageAtPrediction
        self.memoryPressureAtPrediction = memoryPressureAtPrediction
        self.daemonCPUOverhead = daemonCPUOverhead
        self.processesOffloadedCount = processesOffloadedCount
        self.memoryReclaimedBytes = memoryReclaimedBytes
        self.userNotified = userNotified
        self.offloadedProcesses = []
    }

    // MARK: - Helper Methods

    /// Record the actual thermal state outcome
    public func recordActualState(_ state: ThermalStateValue, at timestamp: Date = Date()) {
        self.actualState = state
        self.actualStateTimestamp = timestamp
        self.predictionAccurate =
            (predictedState == state) || (predictedState.severity >= state.severity)  // Predicting higher is considered accurate
    }

    /// Calculate accuracy for this prediction
    public var accuracyScore: Double? {
        guard let accurate = predictionAccurate else { return nil }
        return accurate ? 1.0 : 0.0
    }

    /// Prediction lead time (how long before actual event)
    public var leadTime: TimeInterval? {
        guard let actualTimestamp = actualStateTimestamp else { return nil }
        return actualTimestamp.timeIntervalSince(predictionTimestamp)
    }

    /// Formatted memory reclaimed string
    public var formattedMemoryReclaimed: String {
        MemoryMetrics.formatBytes(UInt64(memoryReclaimedBytes))
    }

    /// Event severity for display
    public var severity: EventSeverity {
        switch predictedState {
        case .nominal: return .low
        case .fair: return .medium
        case .serious: return .high
        case .critical: return .critical
        }
    }
}

// MARK: - Thermal State Value Enum

/// Codable thermal state for persistence
public enum ThermalStateValue: String, Codable, Sendable, CaseIterable {
    case nominal
    case fair
    case serious
    case critical

    /// Convert from ProcessInfo.ThermalState
    public init(from thermalState: ProcessInfo.ThermalState) {
        switch thermalState {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }

    /// Numeric severity (0-3)
    public var severity: Int {
        switch self {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        }
    }

    /// Display description
    public var displayDescription: String {
        switch self {
        case .nominal: return "Optimal"
        case .fair: return "Moderate"
        case .serious: return "Warning"
        case .critical: return "Critical"
        }
    }
}

// MARK: - Event Severity Enum

/// Severity level for display purposes
public enum EventSeverity: String, Codable, Sendable, Comparable {
    case low
    case medium
    case high
    case critical

    public static func < (lhs: EventSeverity, rhs: EventSeverity) -> Bool {
        let order: [EventSeverity] = [.low, .medium, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
            let rhsIndex = order.firstIndex(of: rhs)
        else { return false }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Performance Snapshot Model

/// SwiftData model for periodic performance snapshots
@Model
public final class PerformanceSnapshot {

    /// Unique identifier
    @Attribute(.unique)
    public var id: UUID

    /// Timestamp of the snapshot
    public var timestamp: Date

    /// Memory usage percentage
    public var memoryUsage: Double

    /// Memory pressure level
    public var memoryPressure: Double

    /// Thermal state
    public var thermalState: ThermalStateValue

    /// CPU overhead of daemon
    public var daemonCPUOverhead: Double

    /// Number of actively offloaded processes
    public var activeOffloadCount: Int

    /// Total memory saved by offloading
    public var memorySavedBytes: Int64

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        memoryUsage: Double,
        memoryPressure: Double,
        thermalState: ThermalStateValue,
        daemonCPUOverhead: Double,
        activeOffloadCount: Int = 0,
        memorySavedBytes: Int64 = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.memoryUsage = memoryUsage
        self.memoryPressure = memoryPressure
        self.thermalState = thermalState
        self.daemonCPUOverhead = daemonCPUOverhead
        self.activeOffloadCount = activeOffloadCount
        self.memorySavedBytes = memorySavedBytes
    }
}
