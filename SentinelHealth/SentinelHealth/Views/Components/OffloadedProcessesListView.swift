//
//  OffloadedProcessesListView.swift
//  SentinelHealth
//
//  List view showing currently offloaded processes with restore actions.
//

import SwiftUI

// MARK: - Offloaded Processes List View

/// Shows list of currently offloaded processes with restore buttons
struct OffloadedProcessesListView: View {

    // MARK: - Environment

    @Environment(ApplicationController.self) private var appController

    // MARK: - State

    @State private var selectedProcessID: pid_t?
    @State private var isRestoring = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            if appController.offloadedProcessInfos.isEmpty {
                emptyStateView
            } else {
                processList
            }
        }
        .frame(width: 340, height: 400)
        .background(.regularMaterial)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Offloaded Processes")
                    .font(.headline)

                Text("\(appController.offloadedProcessInfos.count) processes suspended")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !appController.offloadedProcessInfos.isEmpty {
                Button("Restore All") {
                    Task {
                        await appController.restoreAllProcesses()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isRestoring)
            }
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Offloaded Processes", systemImage: "checkmark.circle")
        } description: {
            Text("All processes are running normally.")
        } actions: {
            Button("Offload Inactive Apps") {
                Task {
                    await appController.triggerOffload()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Process List

    private var processList: some View {
        List(appController.offloadedProcessInfos, id: \.pid) { process in
            OffloadedProcessRow(
                process: process,
                isSelected: selectedProcessID == process.pid,
                onRestore: {
                    Task {
                        await restoreProcess(process)
                    }
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedProcessID = process.pid
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Actions

    private func restoreProcess(_ process: OffloadedProcessInfo) async {
        isRestoring = true
        defer { isRestoring = false }
        await appController.restoreProcess(pid: process.pid)
    }
}

// MARK: - Offloaded Process Row

struct OffloadedProcessRow: View {

    let process: OffloadedProcessInfo
    let isSelected: Bool
    let onRestore: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            Image(systemName: "app.fill")
                .font(.title2)
                .foregroundStyle(.purple)
                .frame(width: 32, height: 32)
                .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

            // Process Info
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Label(
                        MemoryMetrics.formatBytes(process.memorySaved),
                        systemImage: "memorychip"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.quaternary)

                    Label(formatDuration(process.duration), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Restore Button
            Button {
                onRestore()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.7)
            .help("Restore this process")
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "\(Int(duration))s"
        } else if duration < 3600 {
            return "\(Int(duration / 60))m"
        } else {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - Preview

#Preview {
    OffloadedProcessesListView()
        .environment(ApplicationController())
}
