//
//  HistoricalAnalyticsStore.swift
//  SentinelHealth
//
//  Actor wrapping SwiftData context for thread-safe analytics operations.
//

import Foundation
import OSLog
import SwiftData

// MARK: - Analytics Query Types

/// Date range for analytics queries
public struct DateRange: Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    /// Last N days from now
    public static func lastDays(_ days: Int) -> DateRange {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return DateRange(start: start, end: end)
    }

    /// Last 7 days
    public static var lastWeek: DateRange { lastDays(7) }

    /// Last 30 days
    public static var lastMonth: DateRange { lastDays(30) }

    /// Last 90 days
    public static var lastQuarter: DateRange { lastDays(90) }
}

/// Aggregated analytics summary
public struct AnalyticsSummary: Sendable {
    /// Total thermal events in period
    public let totalEvents: Int

    /// Number of accurate predictions
    public let accuratePredictions: Int

    /// Prediction accuracy percentage
    public let predictionAccuracy: Double

    /// Total memory saved (bytes)
    public let totalMemorySaved: Int64

    /// Total processes offloaded
    public let totalProcessesOffloaded: Int

    /// Average offload duration (seconds)
    public let averageOffloadDuration: TimeInterval

    /// Events by thermal state
    public let eventsByState: [ThermalStateValue: Int]

    /// Most frequently offloaded apps
    public let topOffloadedApps: [(name: String, count: Int)]

    /// Date range of the summary
    public let dateRange: DateRange
}

// MARK: - Historical Analytics Store Actor

/// Thread-safe actor for managing historical analytics data.
public actor HistoricalAnalyticsStore {

    // MARK: - Properties

    private let logger = SentinelLogger.analytics
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    // MARK: - Initialization

    /// Initialize with a ModelContainer.
    /// - Parameter container: SwiftData ModelContainer
    public init(container: ModelContainer) {
        self.modelContainer = container
        self.modelContext = ModelContext(container)
        modelContext.autosaveEnabled = true
        logger.info("HistoricalAnalyticsStore initialized")
    }

    // MARK: - Thermal Event CRUD

    /// Insert a new thermal event.
    /// - Parameter event: ThermalEvent to insert
    public func insertThermalEvent(_ event: ThermalEvent) throws {
        modelContext.insert(event)
        try modelContext.saveWithErrorHandling()
        logger.debug("Inserted thermal event: \(event.id)")
    }

    /// Fetch thermal events within a date range.
    /// - Parameters:
    ///   - range: Date range for the query
    ///   - state: Optional thermal state filter
    /// - Returns: Array of ThermalEvent matching criteria
    public func fetchThermalEvents(
        in range: DateRange,
        state: ThermalStateValue? = nil
    ) throws -> [ThermalEvent] {
        // Extract dates for predicate (SwiftData macro limitation)
        let startDate = range.start
        let endDate = range.end

        let predicate = #Predicate<ThermalEvent> { event in
            event.predictionTimestamp >= startDate && event.predictionTimestamp <= endDate
        }

        let descriptor = FetchDescriptor<ThermalEvent>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.predictionTimestamp, order: .reverse)]
        )

        var results = try modelContext.fetch(descriptor)

        // Filter by state in memory if needed (enum comparison not supported in Predicate)
        if let state = state {
            results = results.filter { $0.predictedState == state }
        }

        return results
    }

    /// Delete thermal events older than a specified date.
    /// - Parameter date: Delete events before this date
    /// - Returns: Number of events deleted
    @discardableResult
    public func deleteThermalEvents(before date: Date) throws -> Int {
        let predicate = #Predicate<ThermalEvent> { event in
            event.predictionTimestamp < date
        }

        let descriptor = FetchDescriptor<ThermalEvent>(predicate: predicate)
        let events = try modelContext.fetch(descriptor)

        for event in events {
            modelContext.delete(event)
        }

        try modelContext.saveWithErrorHandling()
        logger.info("Deleted \(events.count) thermal events before \(date)")

        return events.count
    }

    // MARK: - Offloaded Process CRUD

    /// Insert an offloaded process record.
    /// - Parameter process: OffloadedProcess to insert
    public func insertOffloadedProcess(_ process: OffloadedProcess) throws {
        modelContext.insert(process)
        try modelContext.saveWithErrorHandling()
        logger.debug("Inserted offloaded process: \(process.processName)")
    }

    /// Fetch currently offloaded (suspended) processes.
    /// - Returns: Array of currently suspended processes
    public func fetchActiveOffloads() throws -> [OffloadedProcess] {
        // Note: Can't filter by enum in SwiftData Predicate directly
        // Fetch all and filter in memory
        let descriptor = FetchDescriptor<OffloadedProcess>(
            sortBy: [SortDescriptor(\.offloadedAt, order: .reverse)]
        )

        let allProcesses = try modelContext.fetch(descriptor)
        return allProcesses.filter { $0.status == .suspended }
    }

    /// Fetch offload history within a date range.
    /// - Parameter range: Date range for the query
    /// - Returns: Array of OffloadedProcess in range
    public func fetchOffloadHistory(in range: DateRange) throws -> [OffloadedProcess] {
        // Extract dates for predicate (SwiftData macro limitation)
        let startDate = range.start
        let endDate = range.end

        let predicate = #Predicate<OffloadedProcess> { process in
            process.offloadedAt >= startDate && process.offloadedAt <= endDate
        }

        let descriptor = FetchDescriptor<OffloadedProcess>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.offloadedAt, order: .reverse)]
        )

        return try modelContext.fetch(descriptor)
    }

    /// Update an offloaded process record.
    /// - Parameter process: OffloadedProcess with updates
    public func updateOffloadedProcess(_ process: OffloadedProcess) throws {
        try modelContext.saveWithErrorHandling()
        logger.debug("Updated offloaded process: \(process.processName)")
    }

    // MARK: - Performance Snapshots

    /// Insert a performance snapshot.
    /// - Parameter snapshot: PerformanceSnapshot to insert
    public func insertPerformanceSnapshot(_ snapshot: PerformanceSnapshot) throws {
        modelContext.insert(snapshot)
        try modelContext.saveWithErrorHandling()
    }

    /// Fetch performance snapshots within a date range.
    /// - Parameter range: Date range for the query
    /// - Returns: Array of PerformanceSnapshot in range
    public func fetchPerformanceSnapshots(in range: DateRange) throws -> [PerformanceSnapshot] {
        // Extract dates for predicate (SwiftData macro limitation)
        let startDate = range.start
        let endDate = range.end

        let predicate = #Predicate<PerformanceSnapshot> { snapshot in
            snapshot.timestamp >= startDate && snapshot.timestamp <= endDate
        }

        let descriptor = FetchDescriptor<PerformanceSnapshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        return try modelContext.fetch(descriptor)
    }

    // MARK: - Analytics Aggregation

    /// Generate an analytics summary for a date range.
    /// - Parameter range: Date range for analysis
    /// - Returns: AnalyticsSummary with aggregated data
    public func generateSummary(for range: DateRange) throws -> AnalyticsSummary {
        logger.info("Generating analytics summary for \(range.start) to \(range.end)")

        // Fetch thermal events
        let events = try fetchThermalEvents(in: range)

        // Fetch offload history
        let offloads = try fetchOffloadHistory(in: range)

        // Calculate metrics
        let accurateCount = events.filter { $0.predictionAccurate == true }.count
        let accuracy = events.isEmpty ? 0 : Double(accurateCount) / Double(events.count)

        let totalMemory = events.reduce(0) { $0 + $1.memoryReclaimedBytes }
        let totalOffloaded = events.reduce(0) { $0 + $1.processesOffloadedCount }

        // Average offload duration
        let completedOffloads = offloads.filter { $0.restoredAt != nil }
        let avgDuration =
            completedOffloads.isEmpty
            ? 0
            : completedOffloads.reduce(0.0) { $0 + ($1.offloadDuration ?? 0) }
                / Double(completedOffloads.count)

        // Events by state
        var eventsByState: [ThermalStateValue: Int] = [:]
        for state in ThermalStateValue.allCases {
            eventsByState[state] = events.filter { $0.predictedState == state }.count
        }

        // Top offloaded apps
        var appCounts: [String: Int] = [:]
        for offload in offloads {
            appCounts[offload.processName, default: 0] += 1
        }
        let topApps = appCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { (name: $0.key, count: $0.value) }

        return AnalyticsSummary(
            totalEvents: events.count,
            accuratePredictions: accurateCount,
            predictionAccuracy: accuracy,
            totalMemorySaved: totalMemory,
            totalProcessesOffloaded: totalOffloaded,
            averageOffloadDuration: avgDuration,
            eventsByState: eventsByState,
            topOffloadedApps: Array(topApps),
            dateRange: range
        )
    }

    /// Calculate rolling prediction accuracy over last N predictions.
    /// - Parameter windowSize: Number of predictions to consider
    /// - Returns: Accuracy percentage (0-1)
    public func calculatePredictionAccuracy(windowSize: Int = 100) throws -> Double {
        let descriptor = FetchDescriptor<ThermalEvent>(
            sortBy: [SortDescriptor(\.predictionTimestamp, order: .reverse)]
        )

        var limitedDescriptor = descriptor
        limitedDescriptor.fetchLimit = windowSize

        let events = try modelContext.fetch(limitedDescriptor)
        let accurateEvents = events.filter { $0.predictionAccurate == true }

        guard !events.isEmpty else { return 0 }
        return Double(accurateEvents.count) / Double(events.count)
    }

    // MARK: - Maintenance

    /// Clean up old data beyond retention period.
    /// - Parameter retentionDays: Number of days to retain data
    public func performMaintenance(retentionDays: Int = 90) throws {
        guard
            let cutoffDate = Calendar.current.date(
                byAdding: .day, value: -retentionDays, to: Date())
        else {
            return
        }

        logger.info("Performing maintenance, deleting data before \(cutoffDate)")

        // Delete old thermal events
        try deleteThermalEvents(before: cutoffDate)

        // Delete old performance snapshots
        let snapshotPredicate = #Predicate<PerformanceSnapshot> { snapshot in
            snapshot.timestamp < cutoffDate
        }

        let snapshotDescriptor = FetchDescriptor<PerformanceSnapshot>(predicate: snapshotPredicate)
        let snapshots = try modelContext.fetch(snapshotDescriptor)

        for snapshot in snapshots {
            modelContext.delete(snapshot)
        }

        try modelContext.saveWithErrorHandling()
        logger.info("Maintenance complete, deleted \(snapshots.count) snapshots")
    }
}
