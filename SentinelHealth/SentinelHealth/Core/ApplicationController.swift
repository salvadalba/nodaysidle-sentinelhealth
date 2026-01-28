//
//  ApplicationController.swift
//  SentinelHealth
//
//  Central controller orchestrating all Sentinel Health services.
//

import Foundation
import OSLog
import Observation
import SwiftData

// MARK: - Application Controller

/// Central observable controller that orchestrates all Sentinel Health services.
@MainActor
@Observable
public final class ApplicationController {

    // MARK: - Published State

    /// Current thermal display state for UI binding
    public private(set) var thermalDisplayState: ThermalDisplayState = .nominal

    /// Current memory usage (0-1)
    public private(set) var memoryUsage: Double = 0

    /// Number of currently offloaded processes
    public private(set) var offloadedProcessCount: Int = 0

    /// Total memory reclaimed by offloading
    public private(set) var memoryReclaimed: UInt64 = 0

    /// Prediction accuracy percentage
    public private(set) var predictionAccuracy: Double = 0

    /// Whether monitoring is active
    public private(set) var isMonitoring: Bool = false

    /// Last prediction result
    public private(set) var lastPrediction: ThermalPrediction?

    /// List of currently offloaded processes
    public private(set) var offloadedProcesses: [OffloadedProcess] = []

    /// Sendable info for offloaded processes (for UI binding)
    public private(set) var offloadedProcessInfos: [OffloadedProcessInfo] = []

    /// Current error state (if any)
    public private(set) var currentError: SentinelError?

    /// Whether onboarding should be shown
    public var showOnboarding: Bool {
        !SettingsManager.shared.hasCompletedOnboarding
    }

    /// Analytics store for dashboard access
    public var analyticsStore: HistoricalAnalyticsStore? {
        dataStore
    }

    // MARK: - Services

    private let logger = SentinelLogger.uiController

    /// Metrics aggregator for system monitoring
    private let metricsAggregator: MetricsAggregator

    /// Thermal intelligence engine for predictions
    private let intelligenceEngine: ThermalIntelligenceEngine

    /// Process offload manager
    private let offloadManager: ProcessOffloadManager

    /// Notification coordinator
    private let notificationCoordinator: NotificationCoordinator

    /// Data store for persistence
    private let dataStore: HistoricalAnalyticsStore?

    /// SwiftData model container
    private let modelContainer: ModelContainer?

    /// Monitoring task handle
    private var monitoringTask: Task<Void, Never>?

    /// ML inference task handle
    private var inferenceTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize the application controller.
    public init() {
        // Initialize data store (optional - can fail gracefully)
        var container: ModelContainer? = nil
        var store: HistoricalAnalyticsStore? = nil

        do {
            container = try DataStore.createContainer()
            store = HistoricalAnalyticsStore(container: container!)
            logger.info("Data persistence initialized")
        } catch {
            logger.warning("Data persistence unavailable: \(error.localizedDescription)")
        }

        self.modelContainer = container
        self.dataStore = store

        // Initialize services
        self.metricsAggregator = MetricsAggregator()
        self.intelligenceEngine = ThermalIntelligenceEngine()
        self.offloadManager = ProcessOffloadManager(dataStore: store)
        self.notificationCoordinator = NotificationCoordinator()

        logger.info("ApplicationController initialized")
    }

    // MARK: - Lifecycle

    /// Start the application services.
    public func start() async {
        logger.info("Starting Sentinel Health services")

        // Request notification permissions
        await notificationCoordinator.requestAuthorization()

        // Load ML model
        do {
            try await intelligenceEngine.loadModel()
        } catch {
            logger.error("Failed to load ML model: \(error.localizedDescription)")
            currentError = error as? SentinelError
        }

        // Start metrics monitoring
        await metricsAggregator.startMonitoring()
        isMonitoring = true

        // Start monitoring loop
        startMonitoringLoop()

        // Start inference loop
        startInferenceLoop()

        logger.info("Sentinel Health services started")
    }

    /// Stop the application services.
    public func stop() async {
        logger.info("Stopping Sentinel Health services")

        // Cancel monitoring tasks
        monitoringTask?.cancel()
        inferenceTask?.cancel()

        monitoringTask = nil
        inferenceTask = nil

        // Restore all offloaded processes
        await offloadManager.prepareForTermination()

        // Stop metrics collection
        await metricsAggregator.stopMonitoring()
        isMonitoring = false

        logger.info("Sentinel Health services stopped")
    }

    // MARK: - Public Actions

    /// Manually trigger process offloading.
    public func triggerOffload() async {
        logger.info("Manual offload triggered")

        do {
            let candidates = try await metricsAggregator.getProcessEnumerator()
                .getOffloadCandidates(limit: 5)
            let results = await offloadManager.offloadProcesses(candidates)

            let successCount = results.filter { $0.success }.count
            let totalReclaimed = results.filter { $0.success }.reduce(0) { $0 + $1.memoryReclaimed }

            if successCount > 0 {
                await notificationCoordinator.sendProcessesOffloaded(
                    count: successCount, memorySaved: totalReclaimed)
            }

            await updateOffloadState()

        } catch {
            logger.error("Offload failed: \(error.localizedDescription)")
        }
    }

    /// Restore all offloaded processes.
    public func restoreAllProcesses() async {
        logger.info("Restoring all processes")

        let results = await offloadManager.restoreAllProcesses(reason: .userRequested)
        let successCount = results.filter { $0.success }.count

        if successCount > 0 {
            await notificationCoordinator.sendProcessesRestored(count: successCount)
        }

        await updateOffloadState()
    }

    /// Restore a specific process.
    public func restoreProcess(_ process: OffloadedProcess) async {
        logger.info("Restoring process: \(process.processName)")

        _ = await offloadManager.restoreProcess(pid: process.pid, reason: .userRequested)
        await updateOffloadState()
    }

    /// Restore a specific process by PID.
    public func restoreProcess(pid: pid_t) async {
        logger.info("Restoring process with PID: \(pid)")

        _ = await offloadManager.restoreProcess(pid: pid, reason: .userRequested)
        await updateOffloadState()
    }

    /// Refresh metrics immediately.
    public func refresh() async {
        await metricsAggregator.refresh()
        await updateUIState()
    }

    /// Open analytics view.
    public func openAnalytics() {
        // Navigate to analytics view (handled by SwiftUI navigation)
        logger.info("Opening analytics view")
    }

    // MARK: - Private Methods

    private func startMonitoringLoop() {
        monitoringTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                await self.updateUIState()
                try? await Task.sleep(for: .seconds(SentinelConstants.Monitoring.uiRefreshInterval))
            }
        }
    }

    private func startInferenceLoop() {
        inferenceTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                await self.runInference()
                try? await Task.sleep(
                    for: .seconds(SentinelConstants.Monitoring.mlInferenceInterval))
            }
        }
    }

    private func updateUIState() async {
        guard let snapshot = metricsAggregator.currentSnapshot else { return }

        thermalDisplayState = snapshot.thermalSnapshot.displayState
        memoryUsage = snapshot.memoryMetrics.usagePercentage

        // Update prediction accuracy from engine
        predictionAccuracy = await intelligenceEngine.currentAccuracy

        await updateOffloadState()
    }

    private func updateOffloadState() async {
        // Get count directly - OffloadedProcess is not Sendable but count/memory are
        offloadedProcessCount = await offloadManager.offloadedCount
        memoryReclaimed = await offloadManager.totalMemoryReclaimed
    }

    private func runInference() async {
        guard let snapshot = metricsAggregator.currentSnapshot else { return }

        do {
            let prediction = try await intelligenceEngine.predict(from: snapshot)
            lastPrediction = prediction

            // Take action based on prediction
            await handlePrediction(prediction, snapshot: snapshot)

        } catch {
            logger.warning("Inference failed: \(error.localizedDescription)")
        }
    }

    private func handlePrediction(_ prediction: ThermalPrediction, snapshot: MetricsSnapshot) async
    {
        // Send thermal warning if needed
        if prediction.predictedState.severity >= ThermalStateValue.serious.severity {
            await notificationCoordinator.sendThermalWarning(state: prediction.predictedState)
        }

        // Auto-offload if conditions warrant
        if prediction.recommendedAction == .offloadAggressive {
            logger.info("Auto-offloading due to high escalation probability")

            let candidates = snapshot.offloadCandidates.prefix(5)
            let results = await offloadManager.offloadProcesses(Array(candidates))

            let successCount = results.filter { $0.success }.count
            let totalReclaimed = results.filter { $0.success }.reduce(0) { $0 + $1.memoryReclaimed }

            if successCount > 0 {
                await notificationCoordinator.sendProcessesOffloaded(
                    count: successCount, memorySaved: totalReclaimed)
            }

            await updateOffloadState()

        } else if prediction.recommendedAction == .offloadConservative {
            // Less aggressive - offload only highest memory processes
            if let topProcess = snapshot.offloadCandidates.first {
                let result = await offloadManager.offloadProcess(topProcess)

                if result.success {
                    await notificationCoordinator.sendProcessesOffloaded(
                        count: 1, memorySaved: result.memoryReclaimed)
                }

                await updateOffloadState()
            }
        }

        // Auto-restore if thermal state cleared
        if snapshot.thermalState == .nominal && offloadedProcessCount > 0 {
            // Wait a bit before restoring to ensure stability
            let offloadedForEnough = offloadedProcesses.allSatisfy { process in
                Date().timeIntervalSince(process.offloadedAt)
                    >= SentinelConstants.Offloading.minimumOffloadDuration
            }

            if offloadedForEnough {
                await offloadManager.handleThermalCleared()
                await updateOffloadState()
            }
        }

        // Record event to data store
        await recordThermalEvent(prediction: prediction, snapshot: snapshot)
    }

    private func recordThermalEvent(prediction: ThermalPrediction, snapshot: MetricsSnapshot) async
    {
        guard let store = dataStore else { return }

        let event = ThermalEvent(
            predictedRisk: prediction.escalationProbability,
            predictionConfidence: prediction.confidence,
            predictedState: prediction.predictedState,
            memoryUsageAtPrediction: snapshot.memoryMetrics.usagePercentage,
            memoryPressureAtPrediction: snapshot.memoryMetrics.pressureLevel,
            processesOffloadedCount: offloadedProcessCount,
            memoryReclaimedBytes: Int64(memoryReclaimed)
        )

        // Record actual state for accuracy tracking
        event.recordActualState(ThermalStateValue(from: snapshot.thermalState))

        do {
            try await store.insertThermalEvent(event)
        } catch {
            logger.warning("Failed to record thermal event: \(error.localizedDescription)")
        }
    }
}

// MARK: - Model Container Access

extension ApplicationController {
    /// Get the model container for SwiftUI environment.
    public var container: ModelContainer? {
        modelContainer
    }
}
