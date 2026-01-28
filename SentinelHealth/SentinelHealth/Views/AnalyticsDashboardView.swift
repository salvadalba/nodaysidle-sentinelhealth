//
//  AnalyticsDashboardView.swift
//  SentinelHealth
//
//  Analytics dashboard showing historical thermal events, prediction accuracy, and memory savings.
//

import Charts
import SwiftUI

// MARK: - Analytics Dashboard View

/// Main analytics dashboard accessible from menu bar and settings
public struct AnalyticsDashboardView: View {

    // MARK: - State

    @State private var selectedTimeRange: TimeRangeOption = .week
    @State private var isLoading = true
    @State private var analyticsData: AnalyticsData?
    @State private var errorMessage: String?

    // Analytics store reference
    private let analyticsStore: HistoricalAnalyticsStore?

    // MARK: - Initialization

    public init(analyticsStore: HistoricalAnalyticsStore? = nil) {
        self.analyticsStore = analyticsStore
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time Range Picker
                    timeRangePicker

                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let data = analyticsData {
                        // Summary Cards
                        summaryCardsSection(data)

                        // Thermal Events Timeline
                        ThermalEventsTimelineView(events: data.thermalEvents)

                        // Memory Savings Summary
                        MemorySavingsSummaryView(summary: data.memorySummary)

                        // Top Offloaded Apps
                        TopOffloadedAppsView(apps: data.topApps)
                    }
                }
                .padding()
            }
            .background(.regularMaterial)
            .navigationTitle("Analytics Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") {
                        Task {
                            await loadAnalytics()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .task {
            await loadAnalytics()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            Task {
                await loadAnalytics()
            }
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRangeOption.allCases, id: \.self) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading analytics...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to Load Analytics", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task {
                    await loadAnalytics()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Summary Cards

    private func summaryCardsSection(_ data: AnalyticsData) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 16
        ) {
            SummaryCard(
                title: "Thermal Events",
                value: "\(data.totalEvents)",
                icon: "thermometer.sun",
                color: .orange
            )

            SummaryCard(
                title: "Prediction Accuracy",
                value: "\(Int(data.predictionAccuracy * 100))%",
                icon: "brain.head.profile",
                color: .blue
            )

            SummaryCard(
                title: "Memory Saved",
                value: MemoryMetrics.formatBytes(UInt64(max(0, data.totalMemorySaved))),
                icon: "arrow.down.circle",
                color: .green
            )
        }
    }

    // MARK: - Load Analytics

    private func loadAnalytics() async {
        isLoading = true
        errorMessage = nil

        // Simulate loading if no store available
        guard analyticsStore != nil else {
            // Generate sample data for preview/demo
            try? await Task.sleep(for: .milliseconds(500))
            analyticsData = AnalyticsData.sample(for: selectedTimeRange)
            isLoading = false
            return
        }

        do {
            let range = selectedTimeRange.dateRange
            let summary = try await analyticsStore!.generateSummary(for: range)

            analyticsData = AnalyticsData(
                totalEvents: summary.totalEvents,
                predictionAccuracy: summary.predictionAccuracy,
                totalMemorySaved: summary.totalMemorySaved,
                thermalEvents: [],  // Would fetch from store
                memorySummary: MemorySummary(
                    totalSaved: summary.totalMemorySaved,
                    averageOffloadDuration: summary.averageOffloadDuration,
                    processesOffloaded: summary.totalProcessesOffloaded
                ),
                topApps: summary.topOffloadedApps.map {
                    TopOffloadedApp(name: $0.name, count: $0.count)
                }
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Summary Card

struct SummaryCard: View {

    let title: String
    let value: String
    let icon: String
    let color: Color

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15), in: Circle())

            VStack(spacing: 4) {
                Text(value)
                    .font(.title2.bold().monospacedDigit())

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(isHovering ? 0.1 : 0), radius: 8)
        }
        .scaleEffect(isHovering ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Thermal Events Timeline View

struct ThermalEventsTimelineView: View {

    let events: [ThermalEventData]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Thermal Events Timeline")
                .font(.headline)

            if events.isEmpty {
                ContentUnavailableView {
                    Label("No Events", systemImage: "chart.line.downtrend.xyaxis")
                } description: {
                    Text("No thermal events in this time period.")
                }
                .frame(height: 200)
            } else {
                Chart(events) { event in
                    PointMark(
                        x: .value("Time", event.timestamp),
                        y: .value("Severity", event.severity)
                    )
                    .foregroundStyle(
                        by: .value("Accurate", event.wasAccurate ? "Accurate" : "Inaccurate")
                    )
                    .symbolSize(60)

                    LineMark(
                        x: .value("Time", event.timestamp),
                        y: .value("Severity", event.severity)
                    )
                    .foregroundStyle(.blue.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartYScale(domain: 0...4)
                .chartYAxis {
                    AxisMarks(values: [0, 1, 2, 3]) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text(severityLabel(intValue))
                            }
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "Accurate": Color.green,
                    "Inaccurate": Color.red,
                ])
                .chartLegend(position: .top)
                .frame(height: 250)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
    }

    private func severityLabel(_ value: Int) -> String {
        switch value {
        case 0: return "Nominal"
        case 1: return "Fair"
        case 2: return "Serious"
        case 3: return "Critical"
        default: return ""
        }
    }
}

// MARK: - Memory Savings Summary View

struct MemorySavingsSummaryView: View {

    let summary: MemorySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Memory Savings")
                .font(.headline)

            HStack(spacing: 24) {
                StatItem(
                    label: "Total Saved",
                    value: MemoryMetrics.formatBytes(UInt64(max(0, summary.totalSaved))),
                    icon: "arrow.down.circle.fill",
                    color: .green
                )

                Divider()
                    .frame(height: 50)

                StatItem(
                    label: "Avg Duration",
                    value: formatDuration(summary.averageOffloadDuration),
                    icon: "clock.fill",
                    color: .blue
                )

                Divider()
                    .frame(height: 50)

                StatItem(
                    label: "Processes",
                    value: "\(summary.processesOffloaded)",
                    icon: "square.stack.3d.up.fill",
                    color: .purple
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return "\(Int(seconds / 3600))h"
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {

    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.bold().monospacedDigit())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Top Offloaded Apps View

struct TopOffloadedAppsView: View {

    let apps: [TopOffloadedApp]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Most Offloaded Apps")
                .font(.headline)

            if apps.isEmpty {
                Text("No apps have been offloaded yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(apps) { app in
                    HStack {
                        Image(systemName: "app.fill")
                            .foregroundStyle(.purple)
                            .frame(width: 28, height: 28)
                            .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

                        Text(app.name)
                            .font(.subheadline)

                        Spacer()

                        Text("\(app.count) times")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
    }
}

// MARK: - Supporting Types

enum TimeRangeOption: CaseIterable {
    case week
    case month
    case quarter

    var displayName: String {
        switch self {
        case .week: return "7 Days"
        case .month: return "30 Days"
        case .quarter: return "90 Days"
        }
    }

    var dateRange: DateRange {
        switch self {
        case .week: return .lastWeek
        case .month: return .lastMonth
        case .quarter: return .lastQuarter
        }
    }
}

struct AnalyticsData {
    let totalEvents: Int
    let predictionAccuracy: Double
    let totalMemorySaved: Int64
    let thermalEvents: [ThermalEventData]
    let memorySummary: MemorySummary
    let topApps: [TopOffloadedApp]

    static func sample(for range: TimeRangeOption) -> AnalyticsData {
        let days = range == .week ? 7 : (range == .month ? 30 : 90)
        var events: [ThermalEventData] = []

        for i in 0..<min(days * 2, 50) {
            let date = Calendar.current.date(byAdding: .hour, value: -i * 12, to: Date()) ?? Date()
            events.append(
                ThermalEventData(
                    id: UUID(),
                    timestamp: date,
                    severity: Int.random(in: 0...3),
                    wasAccurate: Double.random(in: 0...1) > 0.15
                ))
        }

        return AnalyticsData(
            totalEvents: events.count,
            predictionAccuracy: 0.87,
            totalMemorySaved: Int64(days) * 1_500_000_000,
            thermalEvents: events,
            memorySummary: MemorySummary(
                totalSaved: Int64(days) * 1_500_000_000,
                averageOffloadDuration: 1800,
                processesOffloaded: days * 5
            ),
            topApps: [
                TopOffloadedApp(name: "Safari", count: 45),
                TopOffloadedApp(name: "Chrome", count: 32),
                TopOffloadedApp(name: "Slack", count: 28),
                TopOffloadedApp(name: "Discord", count: 21),
                TopOffloadedApp(name: "Spotify", count: 15),
            ]
        )
    }
}

struct ThermalEventData: Identifiable {
    let id: UUID
    let timestamp: Date
    let severity: Int
    let wasAccurate: Bool
}

struct MemorySummary {
    let totalSaved: Int64
    let averageOffloadDuration: TimeInterval
    let processesOffloaded: Int
}

struct TopOffloadedApp: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

// MARK: - Preview

#Preview {
    AnalyticsDashboardView()
}
