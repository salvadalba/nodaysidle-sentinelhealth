//
//  ThermalPrediction.swift
//  SentinelHealth
//
//  Data structures for thermal prediction and feature vectors.
//

import Foundation

// MARK: - Feature Vector

/// ML feature vector constructed from system metrics.
/// Designed for 10Hz inference on Apple Neural Engine.
public struct ThermalFeatureVector: Sendable, Equatable {

    // MARK: - Memory Features (normalized 0-1)

    /// Current memory usage as fraction of total
    public let memoryUsageNormalized: Float

    /// Current memory pressure level (0=nominal, 1=critical)
    public let memoryPressureNormalized: Float

    /// Rate of memory usage change (delta over last second)
    public let memoryDelta: Float

    /// Rate of memory pressure change
    public let pressureDelta: Float

    // MARK: - Thermal Features (normalized 0-1)

    /// Current thermal state (0=nominal, 1=critical)
    public let thermalStateNormalized: Float

    /// Thermal trend (positive = heating, negative = cooling)
    public let thermalTrend: Float

    // MARK: - Process Features

    /// Number of offload candidate processes (normalized)
    public let candidateCountNormalized: Float

    /// Total potential memory savings (normalized)
    public let potentialSavingsNormalized: Float

    // MARK: - Temporal Features

    /// Rolling average memory usage (5 second window)
    public let rollingAvgMemory: Float

    /// Rolling variance of memory usage
    public let rollingVarianceMemory: Float

    /// Time since last thermal incident (normalized to hours, capped)
    public let timeSinceIncidentNormalized: Float

    /// Hour of day (normalized 0-1, for usage patterns)
    public let hourOfDayNormalized: Float

    // MARK: - Initialization

    public init(
        memoryUsageNormalized: Float,
        memoryPressureNormalized: Float,
        memoryDelta: Float,
        pressureDelta: Float,
        thermalStateNormalized: Float,
        thermalTrend: Float,
        candidateCountNormalized: Float,
        potentialSavingsNormalized: Float,
        rollingAvgMemory: Float,
        rollingVarianceMemory: Float,
        timeSinceIncidentNormalized: Float,
        hourOfDayNormalized: Float
    ) {
        self.memoryUsageNormalized = memoryUsageNormalized
        self.memoryPressureNormalized = memoryPressureNormalized
        self.memoryDelta = memoryDelta
        self.pressureDelta = pressureDelta
        self.thermalStateNormalized = thermalStateNormalized
        self.thermalTrend = thermalTrend
        self.candidateCountNormalized = candidateCountNormalized
        self.potentialSavingsNormalized = potentialSavingsNormalized
        self.rollingAvgMemory = rollingAvgMemory
        self.rollingVarianceMemory = rollingVarianceMemory
        self.timeSinceIncidentNormalized = timeSinceIncidentNormalized
        self.hourOfDayNormalized = hourOfDayNormalized
    }

    /// Total number of features in the vector
    public static let featureCount = 12

    /// Convert to flat array for ML input
    public var asArray: [Float] {
        [
            memoryUsageNormalized,
            memoryPressureNormalized,
            memoryDelta,
            pressureDelta,
            thermalStateNormalized,
            thermalTrend,
            candidateCountNormalized,
            potentialSavingsNormalized,
            rollingAvgMemory,
            rollingVarianceMemory,
            timeSinceIncidentNormalized,
            hourOfDayNormalized,
        ]
    }
}

// MARK: - Thermal Prediction

/// Result of thermal prediction inference.
public struct ThermalPrediction: Sendable, Equatable {

    /// Unique identifier for the prediction
    public let id: UUID

    /// Timestamp of the prediction
    public let timestamp: Date

    /// Probability of thermal escalation (0-1)
    public let escalationProbability: Double

    /// Predicted thermal state
    public let predictedState: ThermalStateValue

    /// Confidence level (0-1)
    public let confidence: Double

    /// Time to predicted state (seconds)
    public let timeToState: TimeInterval

    /// Inference latency (milliseconds)
    public let inferenceLatencyMs: Double

    /// Feature vector used for prediction
    public let features: ThermalFeatureVector

    /// Recommended action based on prediction
    public var recommendedAction: RecommendedAction {
        if escalationProbability >= 0.8 && confidence >= 0.7 {
            return .offloadAggressive
        } else if escalationProbability >= 0.6 && confidence >= 0.6 {
            return .offloadConservative
        } else if escalationProbability >= 0.4 {
            return .monitor
        }
        return .none
    }

    /// Whether this prediction should trigger action
    public var shouldTakeAction: Bool {
        recommendedAction != .none
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        escalationProbability: Double,
        predictedState: ThermalStateValue,
        confidence: Double,
        timeToState: TimeInterval,
        inferenceLatencyMs: Double,
        features: ThermalFeatureVector
    ) {
        self.id = id
        self.timestamp = timestamp
        self.escalationProbability = escalationProbability
        self.predictedState = predictedState
        self.confidence = confidence
        self.timeToState = timeToState
        self.inferenceLatencyMs = inferenceLatencyMs
        self.features = features
    }
}

// MARK: - Recommended Action

/// Action recommended by the prediction engine
public enum RecommendedAction: String, Sendable {
    /// No action needed
    case none

    /// Continue monitoring closely
    case monitor

    /// Offload conservatively (low memory impact processes)
    case offloadConservative

    /// Offload aggressively (high memory impact processes)
    case offloadAggressive

    /// Display description
    public var description: String {
        switch self {
        case .none: return "No action needed"
        case .monitor: return "Monitoring closely"
        case .offloadConservative: return "Light offloading recommended"
        case .offloadAggressive: return "Aggressive offloading recommended"
        }
    }
}

// MARK: - Feature Vector Builder

/// Builds feature vectors from system metrics.
public struct FeatureVectorBuilder: Sendable {

    // MARK: - Configuration

    /// Maximum memory to normalize against (32GB)
    private let maxMemoryGB: Double = 32.0

    /// Maximum candidate count for normalization
    private let maxCandidates: Int = 50

    /// Maximum potential savings for normalization (8GB)
    private let maxSavingsGB: Double = 8.0

    /// Time window for rolling statistics (seconds)
    private let rollingWindowSize: Int = 50  // 5 seconds at 10Hz

    // MARK: - State

    /// Ring buffer for memory samples
    private var memoryHistory: [Float]

    /// Index into ring buffer
    private var historyIndex: Int

    /// Last thermal state for trend calculation
    private var lastThermalState: Float

    /// Last memory value for delta calculation
    private var lastMemoryUsage: Float

    /// Last pressure value for delta calculation
    private var lastPressure: Float

    /// Last thermal incident timestamp
    private var lastIncidentTime: Date?

    // MARK: - Initialization

    public init() {
        self.memoryHistory = Array(repeating: 0.5, count: rollingWindowSize)
        self.historyIndex = 0
        self.lastThermalState = 0
        self.lastMemoryUsage = 0.5
        self.lastPressure = 0
        self.lastIncidentTime = nil
    }

    // MARK: - Building

    /// Build a feature vector from current metrics.
    public mutating func buildVector(from snapshot: MetricsSnapshot) -> ThermalFeatureVector {
        let memory = snapshot.memoryMetrics
        let thermal = snapshot.thermalSnapshot

        // Normalize memory usage
        let memUsage = Float(memory.usagePercentage)

        // Normalize pressure (0=nominal, 1=critical) - pressureLevel is already 0-1
        let pressureNorm = Float(memory.pressureLevel)

        // Calculate deltas
        let memDelta = memUsage - lastMemoryUsage
        let pressureDelta = pressureNorm - lastPressure

        // Normalize thermal state
        let thermalNorm = normalizeThermalState(thermal.thermalState)
        let thermalTrend = thermalNorm - lastThermalState

        // Process features
        let candidateNorm =
            Float(min(snapshot.offloadCandidates.count, maxCandidates)) / Float(maxCandidates)
        let savingsBytes = Double(snapshot.potentialSavings)
        let savingsGB = savingsBytes / (1024 * 1024 * 1024)
        let savingsNorm = Float(min(savingsGB / maxSavingsGB, 1.0))

        // Update rolling history
        memoryHistory[historyIndex] = memUsage
        historyIndex = (historyIndex + 1) % rollingWindowSize

        // Calculate rolling statistics
        let rollingAvg = memoryHistory.reduce(0, +) / Float(rollingWindowSize)
        let variance =
            memoryHistory.map { pow($0 - rollingAvg, 2) }.reduce(0, +) / Float(rollingWindowSize)

        // Time since incident
        let timeSince: Float
        if let lastIncident = lastIncidentTime {
            let hours = Float(Date().timeIntervalSince(lastIncident) / 3600)
            timeSince = min(hours / 24.0, 1.0)  // Cap at 24 hours
        } else {
            timeSince = 1.0  // No incident recorded
        }

        // Hour of day
        let hour = Calendar.current.component(.hour, from: Date())
        let hourNorm = Float(hour) / 24.0

        // Track thermal incidents
        if thermal.thermalState == .serious || thermal.thermalState == .critical {
            lastIncidentTime = Date()
        }

        // Update state for next iteration
        lastMemoryUsage = memUsage
        lastPressure = pressureNorm
        lastThermalState = thermalNorm

        return ThermalFeatureVector(
            memoryUsageNormalized: memUsage,
            memoryPressureNormalized: pressureNorm,
            memoryDelta: memDelta,
            pressureDelta: pressureDelta,
            thermalStateNormalized: thermalNorm,
            thermalTrend: thermalTrend,
            candidateCountNormalized: candidateNorm,
            potentialSavingsNormalized: savingsNorm,
            rollingAvgMemory: rollingAvg,
            rollingVarianceMemory: variance,
            timeSinceIncidentNormalized: timeSince,
            hourOfDayNormalized: hourNorm
        )
    }

    // MARK: - Private Helpers

    private func normalizePressure(_ level: MemoryPressureLevel) -> Float {
        switch level {
        case .normal: return 0.0
        case .moderate: return 0.33
        case .high: return 0.67
        case .critical: return 1.0
        }
    }

    private func normalizeThermalState(_ state: ProcessInfo.ThermalState) -> Float {
        switch state {
        case .nominal: return 0.0
        case .fair: return 0.33
        case .serious: return 0.67
        case .critical: return 1.0
        @unknown default: return 0.0
        }
    }
}
