//
//  SettingsView.swift
//  SentinelHealth
//
//  Native macOS Settings scene with premium styling.
//

import SwiftUI

/// Main settings view using native macOS Settings scene styling
struct SettingsView: View {

    // MARK: - State

    @State private var selectedTab: SettingsTab = .general

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            ExclusionsSettingsTab()
                .tabItem {
                    Label("Exclusions", systemImage: "xmark.shield")
                }
                .tag(SettingsTab.exclusions)

            AdvancedSettingsTab()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
                .tag(SettingsTab.advanced)
        }
        .frame(width: 450, height: 350)
    }
}

// MARK: - Settings Tabs Enum

enum SettingsTab: Hashable {
    case general
    case exclusions
    case advanced
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {

    @AppStorage(SentinelConstants.StorageKeys.launchAtLogin)
    private var launchAtLogin = false

    @AppStorage(SentinelConstants.StorageKeys.predictionThreshold)
    private var predictionThreshold = SentinelConstants.Prediction.defaultThreshold

    @AppStorage(SentinelConstants.StorageKeys.notificationFrequency)
    private var notificationFrequency = NotificationFrequency.always.rawValue

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .help("Automatically start Sentinel Health when you log in")
            } header: {
                Text("Startup")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Prediction Sensitivity")
                        Spacer()
                        Text("\(Int(predictionThreshold * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(
                        value: $predictionThreshold,
                        in: SentinelConstants.Prediction
                            .minimumThreshold...SentinelConstants.Prediction.maximumThreshold,
                        step: 0.05
                    )

                    Text("Higher values reduce false positives but may miss some thermal events.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Thermal Intelligence")
            }

            Section {
                Picker("Notification Frequency", selection: $notificationFrequency) {
                    ForEach(NotificationFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName).tag(frequency.rawValue)
                    }
                }
            } header: {
                Text("Notifications")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .padding()
    }
}

// MARK: - Exclusions Settings Tab

struct ExclusionsSettingsTab: View {

    @AppStorage(SentinelConstants.StorageKeys.excludedApps)
    private var excludedAppsData = Data()

    @State private var excludedApps: [ExcludedApp] = []
    @State private var isShowingFilePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Apps in this list will never be suspended by Sentinel Health.")
                .font(.callout)
                .foregroundStyle(.secondary)

            List {
                if excludedApps.isEmpty {
                    ContentUnavailableView {
                        Label("No Exclusions", systemImage: "checkmark.shield")
                    } description: {
                        Text("All apps can be managed by Sentinel Health.")
                    }
                } else {
                    ForEach(excludedApps) { app in
                        HStack {
                            Image(systemName: "app.fill")
                                .foregroundStyle(.secondary)
                            Text(app.name)
                            Spacer()
                            Button(role: .destructive) {
                                removeApp(app)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: 150)

            HStack {
                Spacer()
                Button("Add App...") {
                    isShowingFilePicker = true
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .onAppear(perform: loadExcludedApps)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    private func loadExcludedApps() {
        guard !excludedAppsData.isEmpty else { return }
        if let apps = try? JSONDecoder().decode([ExcludedApp].self, from: excludedAppsData) {
            excludedApps = apps
        }
    }

    private func saveExcludedApps() {
        if let data = try? JSONEncoder().encode(excludedApps) {
            excludedAppsData = data
        }
    }

    private func removeApp(_ app: ExcludedApp) {
        excludedApps.removeAll { $0.id == app.id }
        saveExcludedApps()
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let name = url.deletingPathExtension().lastPathComponent
        let bundleID = Bundle(url: url)?.bundleIdentifier ?? url.path

        let newApp = ExcludedApp(name: name, bundleIdentifier: bundleID)
        if !excludedApps.contains(where: { $0.bundleIdentifier == bundleID }) {
            excludedApps.append(newApp)
            saveExcludedApps()
        }
    }
}

// MARK: - Advanced Settings Tab

struct AdvancedSettingsTab: View {

    @AppStorage(SentinelConstants.StorageKeys.cpuOverheadLimit)
    private var cpuOverheadLimit = SentinelConstants.Performance.maxCPUOverhead

    @AppStorage(SentinelConstants.StorageKeys.debugLoggingEnabled)
    private var debugLoggingEnabled = false

    @AppStorage(SentinelConstants.StorageKeys.cloudKitSyncEnabled)
    private var cloudKitSyncEnabled = false

    @State private var isShowingResetConfirmation = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CPU Overhead Limit")
                        Spacer()
                        Text("\(Int(cpuOverheadLimit))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: $cpuOverheadLimit, in: 1...5, step: 1)

                    Text("Maximum CPU usage for background monitoring daemon.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Performance")
            }

            Section {
                Toggle("Enable Debug Logging", isOn: $debugLoggingEnabled)
                    .help("Log detailed diagnostic information for troubleshooting")
            } header: {
                Text("Diagnostics")
            }

            Section {
                Toggle("Sync Settings via iCloud", isOn: $cloudKitSyncEnabled)
                    .help("Sync preferences and exclusion list across your devices")
            } header: {
                Text("Cloud Sync")
            }

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    isShowingResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .padding()
        .alert("Reset Settings", isPresented: $isShowingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values.")
        }
    }

    private func resetToDefaults() {
        cpuOverheadLimit = SentinelConstants.Performance.maxCPUOverhead
        debugLoggingEnabled = false
        cloudKitSyncEnabled = false
        SentinelLogger.settings.info("Settings reset to defaults")
    }
}

// MARK: - Supporting Types

enum NotificationFrequency: String, CaseIterable {
    case always
    case hourly
    case daily
    case never

    var displayName: String {
        switch self {
        case .always: return "Always"
        case .hourly: return "At Most Hourly"
        case .daily: return "At Most Daily"
        case .never: return "Never"
        }
    }
}

struct ExcludedApp: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let bundleIdentifier: String

    init(id: UUID = UUID(), name: String, bundleIdentifier: String) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
