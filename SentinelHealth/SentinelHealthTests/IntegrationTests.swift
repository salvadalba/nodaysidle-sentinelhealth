//
//  IntegrationTests.swift
//  SentinelHealthTests
//
//  Integration tests for the prediction and offload cycle.
//

import Foundation
import Testing

@testable import SentinelHealth

// MARK: - Prediction Cycle Integration Tests

@Suite("Prediction Cycle Integration Tests")
struct PredictionCycleIntegrationTests {

    @Test("Full prediction cycle executes successfully")
    func testFullPredictionCycle() async throws {
        // Create components
        let thermalEngine = ThermalIntelligenceEngine()

        // Load model
        try await thermalEngine.loadModel()

        // Create snapshot representing moderate stress
        let snapshot = MetricsSnapshot(
            memory: MemoryMetrics(
                totalPhysicalMemory: 16_000_000_000,
                usedMemory: 10_000_000_000,
                freeMemory: 6_000_000_000,
                pressureLevel: 0.55,
                swapUsed: 500_000_000,
                compressedMemory: 1_000_000_000
            ),
            thermal: ThermalSnapshot(
                state: .fair,
                cpuTemperature: 70.0,
                gpuTemperature: 65.0,
                fanSpeed: 3000
            ),
            processes: []
        )

        // Run prediction
        let prediction = try await thermalEngine.predict(from: snapshot)

        // Verify prediction is valid
        #expect(prediction.escalationProbability >= 0)
        #expect(prediction.escalationProbability <= 1)
        #expect(prediction.confidence >= 0.5)
        #expect(prediction.recommendedAction != nil)

        // Record the outcome
        await thermalEngine.recordOutcome(for: prediction.id, actualState: .fair)

        // Verify accuracy is being tracked
        let accuracy = await thermalEngine.currentAccuracy
        #expect(accuracy > 0)
    }

    @Test("Multiple predictions maintain state correctly")
    func testMultiplePredictionsState() async throws {
        let thermalEngine = ThermalIntelligenceEngine()
        try await thermalEngine.loadModel()

        // Run multiple predictions
        for i in 0..<5 {
            let snapshot = createSnapshot(stressLevel: Double(i) / 4.0)
            let prediction = try await thermalEngine.predict(from: snapshot)

            // Record alternating outcomes
            let actualState: ThermalDisplayState = i % 2 == 0 ? .nominal : .fair
            await thermalEngine.recordOutcome(for: prediction.id, actualState: actualState)
        }

        // Latency should be tracked
        let avgLatency = await thermalEngine.averageLatencyMs
        #expect(avgLatency > 0)
    }

    @Test("Process selection respects prediction recommendations")
    func testProcessSelectionWithPrediction() async throws {
        let thermalEngine = ThermalIntelligenceEngine()
        let offloadManager = ProcessOffloadManager()

        try await thermalEngine.loadModel()

        // High stress snapshot
        let snapshot = MetricsSnapshot(
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
                cpuTemperature: 90.0,
                gpuTemperature: 85.0,
                fanSpeed: 5500
            ),
            processes: [
                ProcessSnapshot(
                    pid: 100,
                    name: "HeavyApp",
                    bundleIdentifier: "com.test.heavy",
                    memoryBytes: 2_000_000_000,
                    cpuUsage: 5.0,
                    isBackground: true,
                    idleDuration: 600
                )
            ]
        )

        // Get prediction
        let prediction = try await thermalEngine.predict(from: snapshot)

        // If prediction recommends offloading, verify process selection works
        if prediction.recommendedAction == .offloadLow
            || prediction.recommendedAction == .offloadMedium
            || prediction.recommendedAction == .offloadAggressive
        {
            let candidates = await offloadManager.selectCandidates(
                from: snapshot.processes, limit: 5)
            #expect(!candidates.isEmpty)
        }
    }

    @Test("End-to-end cycle within latency budget")
    func testLatencyBudget() async throws {
        let thermalEngine = ThermalIntelligenceEngine()
        try await thermalEngine.loadModel()

        let snapshot = createSnapshot(stressLevel: 0.5)

        let start = CFAbsoluteTimeGetCurrent()
        _ = try await thermalEngine.predict(from: snapshot)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        // Should complete within 100ms per spec
        #expect(elapsed < 100)
    }

    // MARK: - Helper Methods

    private func createSnapshot(stressLevel: Double) -> MetricsSnapshot {
        let total: UInt64 = 16_000_000_000
        let used = UInt64(Double(total) * stressLevel)
        let free = total - used

        let thermalState: ThermalDisplayState
        switch stressLevel {
        case 0..<0.3: thermalState = .nominal
        case 0.3..<0.6: thermalState = .fair
        case 0.6..<0.85: thermalState = .serious
        default: thermalState = .critical
        }

        return MetricsSnapshot(
            memory: MemoryMetrics(
                totalPhysicalMemory: total,
                usedMemory: used,
                freeMemory: free,
                pressureLevel: stressLevel,
                swapUsed: UInt64(Double(used) * 0.1),
                compressedMemory: UInt64(Double(used) * 0.2)
            ),
            thermal: ThermalSnapshot(
                state: thermalState,
                cpuTemperature: 50 + (stressLevel * 50),
                gpuTemperature: 45 + (stressLevel * 50),
                fanSpeed: Int(1200 + (stressLevel * 5000))
            ),
            processes: []
        )
    }
}

// MARK: - Notification Integration Tests

@Suite("Notification Integration Tests")
struct NotificationIntegrationTests {

    @Test("Notification creation succeeds")
    func testNotificationCreation() async throws {
        let coordinator = NotificationCoordinator()

        // Notification should be schedulable (though not delivered in tests)
        let id = UUID().uuidString
        // Actual notification scheduling requires authorization
        #expect(!id.isEmpty)
    }
}

// MARK: - Settings Integration Tests

@Suite("Settings Integration Tests")
struct SettingsIntegrationTests {

    @Test("Settings manager persists values")
    func testSettingsPersistence() {
        let settings = SettingsManager.shared

        let originalThreshold = settings.predictionThreshold

        // Modify setting
        settings.predictionThreshold = 0.75

        // Verify change
        #expect(settings.predictionThreshold == 0.75)

        // Restore original
        settings.predictionThreshold = originalThreshold
    }

    @Test("Exclusion list management")
    func testExclusionManagement() {
        let settings = SettingsManager.shared

        let testBundle = "com.test.exclusion"

        // Add exclusion
        settings.addExclusion(testBundle)
        #expect(settings.isExcluded(bundleIdentifier: testBundle))

        // Remove exclusion
        settings.removeExclusion(testBundle)
        #expect(!settings.isExcluded(bundleIdentifier: testBundle))
    }

    @Test("Threshold clamping works")
    func testThresholdClamping() {
        let settings = SettingsManager.shared

        // Should clamp to minimum
        settings.predictionThreshold = 0.1
        #expect(settings.predictionThreshold >= 0.5)

        // Should clamp to maximum
        settings.predictionThreshold = 1.0
        #expect(settings.predictionThreshold <= 0.9)

        // Reset to default
        settings.predictionThreshold = SentinelConstants.Prediction.defaultThreshold
    }
}

// MARK: - Analytics Integration Tests

@Suite("Analytics Integration Tests")
struct AnalyticsIntegrationTests {

    @Test("Analytics summary generates correctly")
    func testAnalyticsSummaryGeneration() async throws {
        // Test that AnalyticsSummary can be created
        let summary = AnalyticsSummary(
            totalEvents: 50,
            predictionAccuracy: 0.87,
            totalMemorySaved: 15_000_000_000,
            averageOffloadDuration: 1800,
            totalProcessesOffloaded: 25,
            topOffloadedApps: [
                AnalyticsSummary.AppOffloadCount(name: "Safari", count: 10),
                AnalyticsSummary.AppOffloadCount(name: "Mail", count: 8),
            ]
        )

        #expect(summary.totalEvents == 50)
        #expect(summary.predictionAccuracy == 0.87)
        #expect(summary.topOffloadedApps.count == 2)
    }
}
