//
//  MenuBarView.swift
//  SentinelHealth
//
//  Menu bar popover view with thermal status and quick actions.
//

import SwiftUI

/// Primary menu bar popover view showing thermal status and controls
struct MenuBarView: View {

    // MARK: - Environment

    @Environment(ApplicationController.self) private var appController

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Status Section
            statusSection

            Divider()

            // Quick Actions
            quickActionsSection

            Divider()

            // Footer
            footerSection
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .task {
            await appController.start()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sentinel Health")
                    .font(.headline)

                HStack(spacing: 4) {
                    Circle()
                        .fill(appController.thermalDisplayState.iconColor)
                        .frame(width: 8, height: 8)

                    Text(appController.thermalDisplayState.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: appController.thermalDisplayState.iconName)
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(appController.thermalDisplayState.iconColor, .secondary)
        }
        .padding()
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 16) {
            // Memory Usage Gauge
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Unified Memory")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(appController.memoryUsage * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(memoryColor)
                            .frame(width: geometry.size.width * appController.memoryUsage)
                            .animation(.easeInOut(duration: 0.3), value: appController.memoryUsage)
                    }
                }
                .frame(height: 8)
            }

            // Offloaded Processes Count
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.purple)

                Text("Offloaded Processes")
                    .font(.subheadline)

                Spacer()

                Text("\(appController.offloadedProcessCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Memory Reclaimed
            if appController.memoryReclaimed > 0 {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.green)

                    Text("Memory Reclaimed")
                        .font(.subheadline)

                    Spacer()

                    Text(MemoryMetrics.formatBytes(appController.memoryReclaimed))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            // Prediction Accuracy
            if appController.predictionAccuracy > 0 {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.blue)

                    Text("Prediction Accuracy")
                        .font(.subheadline)

                    Spacer()

                    Text("\(Int(appController.predictionAccuracy * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await appController.triggerOffload()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text("Offload Inactive Apps")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

            Button {
                Task {
                    await appController.restoreAllProcesses()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.circle")
                    Text("Restore All")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            .disabled(appController.offloadedProcessCount == 0)
        }
        .padding()
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack {
            Button("Analytics") {
                appController.openAnalytics()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)

            Spacer()

            SettingsLink {
                Text("Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Quit") {
                Task {
                    await appController.stop()
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Computed Properties

    private var memoryColor: Color {
        switch appController.memoryUsage {
        case 0..<0.5: return .green
        case 0.5..<0.75: return .yellow
        case 0.75..<0.9: return .orange
        default: return .red
        }
    }
}

// MARK: - ThermalDisplayState Extension

extension ThermalDisplayState {
    var statusText: String {
        switch self {
        case .nominal: return "System Optimal"
        case .fair: return "Monitoring Active"
        case .serious: return "Thermal Warning"
        case .critical: return "Critical Temperature"
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environment(ApplicationController())
        .frame(width: 320, height: 400)
}
