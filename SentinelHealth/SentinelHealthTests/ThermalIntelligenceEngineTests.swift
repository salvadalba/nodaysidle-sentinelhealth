//
//  ThermalIntelligenceEngineTests.swift
//  SentinelHealthTests
//
//  Unit tests for the ThermalIntelligenceEngine.
//

import Foundation
import Testing

@testable import SentinelHealth

// MARK: - Thermal Intelligence Engine Tests

@Suite("ThermalIntelligenceEngine Tests")
struct ThermalIntelligenceEngineTests {

    // MARK: - Model Loading Tests

    @Test("Engine loads model successfully")
    func testModelLoadsSuccessfully() async throws {
        let engine = ThermalIntelligenceEngine()

        try await engine.loadModel()

        let isReady = await engine.isReady
        #expect(isReady == true)
    }

    @Test("Engine unloads model correctly")
    func testModelUnloadsCorrectly() async throws {
        let engine = ThermalIntelligenceEngine()

        try await engine.loadModel()
        await engine.unloadModel()

        let isReady = await engine.isReady
        #expect(isReady == false)
    }

    // MARK: - Prediction Tests

    @Test("Prediction returns valid results for nominal metrics")
    func testPredictionNominalMetrics() async throws {
        let engine = ThermalIntelligenceEngine()
        try await engine.loadModel()

        let snapshot = createNominalMetricsSnapshot()
        let prediction = try await engine.predict(from: snapshot)

        #expect(prediction.escalationProbability >= 0)
        #expect(prediction.escalationProbability <= 1)
        #expect(prediction.confidence >= 0.5)
    }

    @Test("Prediction returns high probability for stressed metrics")
    func testPredictionStressedMetrics() async throws {
        let engine = ThermalIntelligenceEngine()
        try await engine.loadModel()

        let snapshot = createStressedMetricsSnapshot()
        let prediction = try await engine.predict(from: snapshot)

        // Stressed system should have higher escalation probability
        #expect(prediction.escalationProbability > 0.5)
    }

    @Test("Prediction fails when model not loaded")
    func testPredictionFailsWithoutModel() async throws {
        let engine = ThermalIntelligenceEngine()

        let snapshot = createNominalMetricsSnapshot()

        await #expect(throws: SentinelError.self) {
            _ = try await engine.predict(from: snapshot)
        }
    }

    @Test("Prediction tracks latency")
    func testPredictionTracksLatency() async throws {
        let engine = ThermalIntelligenceEngine()
        try await engine.loadModel()

        let snapshot = createNominalMetricsSnapshot()
        _ = try await engine.predict(from: snapshot)

        let latency = await engine.averageLatencyMs
        #expect(latency > 0)
        #expect(latency < 100)  // Should be under 100ms per spec
    }

    // MARK: - Accuracy Tracking Tests

    @Test("Records outcome correctly")
    func testRecordsOutcome() async throws {
        let engine = ThermalIntelligenceEngine()
        try await engine.loadModel()

        let snapshot = createNominalMetricsSnapshot()
        let prediction = try await engine.predict(from: snapshot)

        await engine.recordOutcome(for: prediction.id, actualState: prediction.predictedState)

        let accuracy = await engine.currentAccuracy
        #expect(accuracy > 0)  // Should have some accuracy recorded
    }

    // MARK: - Threshold Tests

    @Test("Prediction respects configurable threshold")
    func testPredictionThreshold() async throws {
        let engine = ThermalIntelligenceEngine()
        try await engine.loadModel()

        let snapshot = createNominalMetricsSnapshot()
        let prediction = try await engine.predict(from: snapshot)

        // Nominal system should not recommend immediate action
        if prediction.escalationProbability < 0.7 {
            #expect(
                prediction.recommendedAction == .continue
                    || prediction.recommendedAction == .monitor)
        }
    }

    // MARK: - Helper Methods

    private func createNominalMetricsSnapshot() -> MetricsSnapshot {
        MetricsSnapshot(
            memory: MemoryMetrics(
                totalPhysicalMemory: 16_000_000_000,
                usedMemory: 8_000_000_000,
                freeMemory: 8_000_000_000,
                pressureLevel: 0.3,
                swapUsed: 0,
                compressedMemory: 500_000_000
            ),
            thermal: ThermalSnapshot(
                state: .nominal,
                cpuTemperature: 55.0,
                gpuTemperature: 50.0,
                fanSpeed: 1200
            ),
            processes: []
        )
    }

    private func createStressedMetricsSnapshot() -> MetricsSnapshot {
        MetricsSnapshot(
            memory: MemoryMetrics(
                totalPhysicalMemory: 16_000_000_000,
                usedMemory: 15_000_000_000,
                freeMemory: 1_000_000_000,
                pressureLevel: 0.9,
                swapUsed: 2_000_000_000,
                compressedMemory: 3_000_000_000
            ),
            thermal: ThermalSnapshot(
                state: .serious,
                cpuTemperature: 95.0,
                gpuTemperature: 90.0,
                fanSpeed: 6000
            ),
            processes: []
        )
    }
}

// MARK: - Feature Vector Tests

@Suite("ThermalFeatureVector Tests")
struct ThermalFeatureVectorTests {

    @Test("Feature vector normalizes memory correctly")
    func testMemoryNormalization() {
        let builder = FeatureVectorBuilder()
        let snapshot = MetricsSnapshot(
            memory: MemoryMetrics(
                totalPhysicalMemory: 16_000_000_000,
                usedMemory: 8_000_000_000,
                freeMemory: 8_000_000_000,
                pressureLevel: 0.5,
                swapUsed: 0,
                compressedMemory: 0
            ),
            thermal: ThermalSnapshot(
                state: .nominal,
                cpuTemperature: 60.0,
                gpuTemperature: 55.0,
                fanSpeed: 2000
            ),
            processes: []
        )

        let vector = builder.buildVector(from: snapshot)

        #expect(vector.memoryUsageNormalized >= 0.4)
        #expect(vector.memoryUsageNormalized <= 0.6)
    }

    @Test("Feature vector normalizes thermal state correctly")
    func testThermalNormalization() {
        let builder = FeatureVectorBuilder()
        let snapshot = MetricsSnapshot(
            memory: MemoryMetrics(
                totalPhysicalMemory: 16_000_000_000,
                usedMemory: 8_000_000_000,
                freeMemory: 8_000_000_000,
                pressureLevel: 0.3,
                swapUsed: 0,
                compressedMemory: 0
            ),
            thermal: ThermalSnapshot(
                state: .critical,
                cpuTemperature: 100.0,
                gpuTemperature: 95.0,
                fanSpeed: 6200
            ),
            processes: []
        )

        let vector = builder.buildVector(from: snapshot)

        #expect(vector.thermalStateNormalized >= 0.9)
    }
}

// MARK: - Prediction Model Tests

@Suite("ThermalPredictionModel Tests")
struct ThermalPredictionModelTests {

    @Test("Model returns valid probability range")
    func testValidProbabilityRange() throws {
        let model = ThermalPredictionModel()
        let features = createTestFeatures()

        let result = try model.predict(from: features)

        #expect(result.escalationProbability >= 0)
        #expect(result.escalationProbability <= 1)
    }

    @Test("Model returns valid confidence range")
    func testValidConfidenceRange() throws {
        let model = ThermalPredictionModel()
        let features = createTestFeatures()

        let result = try model.predict(from: features)

        #expect(result.confidence >= 0.5)
        #expect(result.confidence <= 1.0)
    }

    @Test("Model predicts nominal for low-stress features")
    func testPredictsNominalForLowStress() throws {
        let model = ThermalPredictionModel()
        let features = ThermalFeatureVector(
            timestamp: Date(),
            memoryUsageNormalized: 0.3,
            memoryPressureNormalized: 0.2,
            thermalStateNormalized: 0.1,
            cpuTemperatureNormalized: 0.4,
            gpuTemperatureNormalized: 0.3,
            fanSpeedNormalized: 0.2,
            memoryDelta: 0.0,
            thermalTrend: 0.0,
            rollingAverageMemory: 0.3,
            rollingVarianceMemory: 0.05,
            timeSinceIncidentNormalized: 1.0
        )

        let result = try model.predict(from: features)

        #expect(result.predictedState == .nominal || result.predictedState == .fair)
    }

    @Test("Model predicts critical for high-stress features")
    func testPredictsCriticalForHighStress() throws {
        let model = ThermalPredictionModel()
        let features = ThermalFeatureVector(
            timestamp: Date(),
            memoryUsageNormalized: 0.95,
            memoryPressureNormalized: 0.9,
            thermalStateNormalized: 0.9,
            cpuTemperatureNormalized: 0.95,
            gpuTemperatureNormalized: 0.9,
            fanSpeedNormalized: 1.0,
            memoryDelta: 0.2,
            thermalTrend: 0.3,
            rollingAverageMemory: 0.9,
            rollingVarianceMemory: 0.1,
            timeSinceIncidentNormalized: 0.05
        )

        let result = try model.predict(from: features)

        #expect(result.predictedState == .serious || result.predictedState == .critical)
    }

    private func createTestFeatures() -> ThermalFeatureVector {
        ThermalFeatureVector(
            timestamp: Date(),
            memoryUsageNormalized: 0.5,
            memoryPressureNormalized: 0.4,
            thermalStateNormalized: 0.3,
            cpuTemperatureNormalized: 0.5,
            gpuTemperatureNormalized: 0.4,
            fanSpeedNormalized: 0.3,
            memoryDelta: 0.0,
            thermalTrend: 0.0,
            rollingAverageMemory: 0.5,
            rollingVarianceMemory: 0.1,
            timeSinceIncidentNormalized: 0.5
        )
    }
}
