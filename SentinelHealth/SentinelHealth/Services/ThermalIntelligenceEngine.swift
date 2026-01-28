//
//  ThermalIntelligenceEngine.swift
//  SentinelHealth
//
//  Actor implementing ML inference for thermal prediction.
//

import CoreML
import Foundation
import OSLog

// MARK: - Intelligence Engine Actor

/// Actor responsible for running ML inference to predict thermal escalation.
/// Designed to run at 10Hz with <100ms latency for ANE offload.
public actor ThermalIntelligenceEngine {

    // MARK: - Properties

    private let logger = SentinelLogger.thermalEngine
    private let signposter = SentinelSignpost.thermalEngine

    /// Feature vector builder for preprocessing
    private var featureBuilder: FeatureVectorBuilder

    /// CoreML model (placeholder - actual model loaded from bundle)
    private var model: ThermalPredictionModel?

    /// Prediction history for accuracy tracking
    private var predictionHistory: [(prediction: ThermalPrediction, outcome: ThermalStateValue?)]

    /// Maximum prediction history size
    private let maxHistorySize = 100

    /// Inference interval (10Hz = 100ms)
    private let inferenceInterval: TimeInterval

    /// Current prediction accuracy
    private(set) var currentAccuracy: Double = 0.0

    /// Average inference latency in ms
    private(set) var averageLatencyMs: Double = 0.0

    /// Whether the model is loaded and ready
    private(set) var isReady: Bool = false

    // MARK: - Initialization

    /// Initialize the thermal intelligence engine.
    /// - Parameter inferenceInterval: Interval between inferences (default: 100ms for 10Hz)
    public init(inferenceInterval: TimeInterval = SentinelConstants.Monitoring.mlInferenceInterval)
    {
        self.inferenceInterval = inferenceInterval
        self.featureBuilder = FeatureVectorBuilder()
        self.predictionHistory = []
        logger.info(
            "ThermalIntelligenceEngine initialized with \(Int(1/inferenceInterval))Hz inference rate"
        )
    }

    // MARK: - Model Management

    /// Load the ML model from the bundle.
    /// - Throws: SentinelError.modelNotLoaded if model cannot be loaded
    public func loadModel() async throws {
        logger.info("Loading thermal prediction model")

        do {
            // In production, this would load the actual CoreML model
            // For now, we use a placeholder that implements heuristic-based prediction
            model = ThermalPredictionModel()
            isReady = true
            logger.info("Model loaded successfully")
        } catch {
            logger.error("Failed to load model: \(error.localizedDescription)")
            throw SentinelError.modelNotLoaded(recoverySuggestion: .downloadModel)
        }
    }

    /// Unload the model to free memory.
    public func unloadModel() {
        model = nil
        isReady = false
        logger.info("Model unloaded")
    }

    // MARK: - Inference

    /// Run inference on current metrics to predict thermal state.
    /// - Parameter snapshot: Current system metrics snapshot
    /// - Returns: ThermalPrediction with probability and recommended action
    /// - Throws: SentinelError.modelNotLoaded if model is not ready
    public func predict(from snapshot: MetricsSnapshot) async throws -> ThermalPrediction {
        guard isReady, let model = model else {
            throw SentinelError.modelNotLoaded(recoverySuggestion: .restartApp)
        }

        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("inference", id: signpostID)
        defer { signposter.endInterval("inference", state) }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Build feature vector
        let features = featureBuilder.buildVector(from: snapshot)

        // Run model inference
        let result = try model.predict(from: features)

        let endTime = CFAbsoluteTimeGetCurrent()
        let latencyMs = (endTime - startTime) * 1000

        // Map result to prediction
        let prediction = ThermalPrediction(
            escalationProbability: result.escalationProbability,
            predictedState: result.predictedState,
            confidence: result.confidence,
            timeToState: result.timeToState,
            inferenceLatencyMs: latencyMs,
            features: features
        )

        // Track prediction for accuracy calculation
        recordPrediction(prediction)
        updateLatencyMetrics(latencyMs)

        logger.debug(
            "Prediction: \(result.predictedState.displayDescription) with \(Int(result.escalationProbability * 100))% probability"
        )

        return prediction
    }

    /// Record actual outcome for accuracy feedback.
    /// - Parameters:
    ///   - predictionID: ID of the prediction to update
    ///   - actualState: Observed thermal state
    public func recordOutcome(for predictionID: UUID, actualState: ThermalStateValue) {
        if let index = predictionHistory.firstIndex(where: { $0.prediction.id == predictionID }) {
            predictionHistory[index].outcome = actualState
            updateAccuracyMetrics()
        }
    }

    // MARK: - Private Methods

    private func recordPrediction(_ prediction: ThermalPrediction) {
        predictionHistory.append((prediction: prediction, outcome: nil))

        // Trim history to max size
        if predictionHistory.count > maxHistorySize {
            predictionHistory.removeFirst(predictionHistory.count - maxHistorySize)
        }
    }

    private func updateAccuracyMetrics() {
        let completedPredictions = predictionHistory.filter { $0.outcome != nil }
        guard !completedPredictions.isEmpty else { return }

        let accurateCount = completedPredictions.filter { item in
            guard let outcome = item.outcome else { return false }
            // Prediction is accurate if state matches or we predicted higher (safe)
            return item.prediction.predictedState == outcome
                || item.prediction.predictedState.severity >= outcome.severity
        }.count

        currentAccuracy = Double(accurateCount) / Double(completedPredictions.count)
        logger.debug("Prediction accuracy updated: \(Int(self.currentAccuracy * 100))%")
    }

    private func updateLatencyMetrics(_ latencyMs: Double) {
        // Exponential moving average
        let alpha = 0.1
        averageLatencyMs = alpha * latencyMs + (1 - alpha) * averageLatencyMs
    }
}

// MARK: - Placeholder Model

/// Placeholder CoreML model for thermal prediction.
/// In production, this would be replaced with actual ML model loaded from bundle.
public final class ThermalPredictionModel: @unchecked Sendable {

    private let logger = SentinelLogger.thermalEngine

    public init() {
        logger.debug("Initializing placeholder prediction model")
    }

    /// Prediction result from the model
    public struct PredictionResult {
        public let escalationProbability: Double
        public let predictedState: ThermalStateValue
        public let confidence: Double
        public let timeToState: TimeInterval
    }

    /// Run prediction on feature vector.
    /// This placeholder uses heuristic-based prediction until real ML model is integrated.
    public func predict(from features: ThermalFeatureVector) throws -> PredictionResult {
        // Heuristic-based prediction as placeholder for ML model

        // Base probability from memory and thermal features
        var probability = 0.0

        // Weight memory pressure heavily
        probability += Double(features.memoryPressureNormalized) * 0.3

        // Current thermal state is a strong indicator
        probability += Double(features.thermalStateNormalized) * 0.25

        // Trends indicate trajectory
        if features.memoryDelta > 0 {
            probability += Double(features.memoryDelta) * 0.15
        }
        if features.thermalTrend > 0 {
            probability += Double(features.thermalTrend) * 0.1
        }

        // High memory usage increases risk
        probability += Double(features.memoryUsageNormalized) * 0.15

        // Recent incidents indicate unstable state
        if features.timeSinceIncidentNormalized < 0.1 {  // Within ~2.4 hours
            probability += 0.05
        }

        // Cap probability
        probability = min(max(probability, 0.0), 1.0)

        // Determine predicted state based on probability
        let predictedState: ThermalStateValue
        if probability >= 0.8 {
            predictedState = .critical
        } else if probability >= 0.6 {
            predictedState = .serious
        } else if probability >= 0.3 {
            predictedState = .fair
        } else {
            predictedState = .nominal
        }

        // Confidence based on feature consistency
        let confidence = calculateConfidence(features: features)

        // Estimate time to state change (very approximate)
        let timeToState = estimateTimeToState(probability: probability)

        return PredictionResult(
            escalationProbability: probability,
            predictedState: predictedState,
            confidence: confidence,
            timeToState: timeToState
        )
    }

    private func calculateConfidence(features: ThermalFeatureVector) -> Double {
        // Lower confidence when features are volatile
        var confidence = 0.8

        // High variance decreases confidence
        if features.rollingVarianceMemory > 0.1 {
            confidence -= 0.1
        }

        // Conflicting signals decrease confidence
        if features.thermalStateNormalized > 0.5 && features.memoryPressureNormalized < 0.3 {
            confidence -= 0.1
        }

        return max(confidence, 0.5)
    }

    private func estimateTimeToState(probability: Double) -> TimeInterval {
        // Rough estimate: higher probability = sooner event
        if probability >= 0.8 {
            return 30  // 30 seconds
        } else if probability >= 0.6 {
            return 120  // 2 minutes
        } else if probability >= 0.4 {
            return 300  // 5 minutes
        } else {
            return 600  // 10+ minutes
        }
    }
}
