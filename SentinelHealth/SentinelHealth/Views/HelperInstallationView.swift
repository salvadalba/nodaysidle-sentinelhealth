//
//  HelperInstallationView.swift
//  SentinelHealth
//
//  UI flow for installing the privileged helper with admin authentication.
//

import SwiftUI

// MARK: - Helper Installation View

/// View for installing the privileged helper
public struct HelperInstallationView: View {

    // MARK: - State

    @State private var installationState: InstallationState = .notInstalled
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            headerSection

            Divider()

            // Content based on state
            switch installationState {
            case .notInstalled:
                notInstalledContent
            case .installing:
                installingContent
            case .installed:
                installedContent
            case .failed:
                failedContent
            }

            Spacer()

            // Actions
            actionButtons
        }
        .padding()
        .frame(width: 450, height: 400)
        .background(.regularMaterial)
        .task {
            await checkInstallationStatus()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Privileged Helper")
                .font(.title2.bold())

            Text(
                "The helper enables advanced process management capabilities for better thermal control."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
    }

    // MARK: - Not Installed Content

    private var notInstalledContent: some View {
        VStack(spacing: 16) {
            Text("Why Install the Helper?")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(
                    icon: "bolt.shield",
                    title: "Enhanced Process Control",
                    description: "Suspend and resume any user application"
                )

                BenefitRow(
                    icon: "lock.shield",
                    title: "Secure Operation",
                    description: "Runs with minimal privileges, validates all requests"
                )

                BenefitRow(
                    icon: "arrow.clockwise.circle",
                    title: "Reliable Recovery",
                    description: "Emergency resume if the main app crashes"
                )
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
        }
    }

    // MARK: - Installing Content

    private var installingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Installing Helper...")
                .font(.headline)

            Text("You may be prompted for your administrator password.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Installed Content

    private var installedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Helper Installed")
                .font(.headline)

            Text("The privileged helper is installed and ready to use.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Failed Content

    private var failedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Installation Failed")
                .font(.headline)

            if let error = errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Sentinel Health will continue to work with limited functionality.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch installationState {
        case .notInstalled:
            HStack {
                Button("Skip for Now") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Install Helper") {
                    installHelper()
                }
                .buttonStyle(.borderedProminent)
            }

        case .installing:
            EmptyView()

        case .installed:
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)

        case .failed:
            HStack {
                Button("Continue Without Helper") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Try Again") {
                    installHelper()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Actions

    private func checkInstallationStatus() async {
        let isInstalled = await XPCConnectionManager.shared.isHelperInstalled()
        installationState = isInstalled ? .installed : .notInstalled
    }

    private func installHelper() {
        installationState = .installing
        errorMessage = nil

        HelperInstallation.requestInstallation { success, error in
            DispatchQueue.main.async {
                if success {
                    installationState = .installed
                } else {
                    installationState = .failed
                    errorMessage =
                        error?.localizedDescription
                        ?? "An unknown error occurred during installation."
                }
            }
        }
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {

    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Installation State

enum InstallationState {
    case notInstalled
    case installing
    case installed
    case failed
}

// MARK: - Preview

#Preview {
    HelperInstallationView()
}
