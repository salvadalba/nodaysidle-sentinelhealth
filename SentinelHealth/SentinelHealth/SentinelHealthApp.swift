//
//  SentinelHealthApp.swift
//  SentinelHealth
//
//  Sentinel Health - Proactive thermal management for Apple Silicon Macs
//

import SwiftData
import SwiftUI

/// Main application entry point for Sentinel Health.
/// Provides a menu bar presence with popover UI and Settings scene.
@main
struct SentinelHealthApp: App {

    // MARK: - App Delegate

    /// Connect the AppDelegate for lifecycle events SwiftUI doesn't handle
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - State

    /// Central application controller
    @State private var appController = ApplicationController()

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body

    var body: some Scene {
        // Menu Bar Companion with popover
        MenuBarExtra {
            MenuBarView()
                .environment(appController)
                .onAppear {
                    // Connect appController to appDelegate for termination handling
                    appDelegate.appController = appController
                }
        } label: {
            Label {
                Text("Sentinel Health")
            } icon: {
                Image(systemName: appController.thermalDisplayState.iconName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(appController.thermalDisplayState.iconColor, .secondary)
            }
        }
        .menuBarExtraStyle(.window)

        // Native Settings scene
        Settings {
            SettingsView()
                .environment(appController)
        }
    }

    // MARK: - Initialization

    init() {
        // App initialization handled by ApplicationController
    }
}

// MARK: - App Delegate

/// App delegate for handling lifecycle events that SwiftUI doesn't cover.
final class AppDelegate: NSObject, NSApplicationDelegate {

    var appController: ApplicationController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for menu bar app
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Ensure processes are restored on termination
        Task { @MainActor in
            await appController?.stop()
        }
    }
}

// MARK: - Thermal Display State

/// Visual representation of thermal state for menu bar icon
public enum ThermalDisplayState: Sendable, Equatable {
    case nominal
    case fair
    case serious
    case critical

    public var iconName: String {
        switch self {
        case .nominal: return "thermometer.low"
        case .fair: return "thermometer.medium"
        case .serious: return "thermometer.high"
        case .critical: return "thermometer.sun.fill"
        }
    }

    public var iconColor: Color {
        switch self {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }

    public var description: String {
        switch self {
        case .nominal: return "Optimal"
        case .fair: return "Moderate"
        case .serious: return "Warning"
        case .critical: return "Critical"
        }
    }

    /// Initialize from ProcessInfo.ThermalState
    public init(from thermalState: ProcessInfo.ThermalState) {
        switch thermalState {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }
}
