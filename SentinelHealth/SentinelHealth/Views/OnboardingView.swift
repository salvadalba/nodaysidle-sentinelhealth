//
//  OnboardingView.swift
//  SentinelHealth
//
//  First-launch onboarding wizard explaining app capabilities and requesting permissions.
//

import SwiftUI
import UserNotifications

// MARK: - Onboarding View

/// First-launch onboarding wizard
public struct OnboardingView: View {

    // MARK: - State

    @State private var currentStep: OnboardingStep = .welcome
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Binding var isComplete: Bool

    // MARK: - Initialization

    public init(isComplete: Binding<Bool>) {
        self._isComplete = isComplete
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Progress Indicator
            progressIndicator

            // Content
            TabView(selection: $currentStep) {
                WelcomeStep(onContinue: { currentStep = .howItWorks })
                    .tag(OnboardingStep.welcome)

                HowItWorksStep(onContinue: { currentStep = .permissions })
                    .tag(OnboardingStep.howItWorks)

                PermissionsStep(
                    notificationStatus: notificationStatus,
                    onRequestNotifications: requestNotifications,
                    onContinue: { currentStep = .launchAtLogin }
                )
                .tag(OnboardingStep.permissions)

                LaunchAtLoginStep(onComplete: completeOnboarding)
                    .tag(OnboardingStep.launchAtLogin)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 500, height: 450)
        .background(.ultraThinMaterial)
        .task {
            await checkNotificationStatus()
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Actions

    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    private func requestNotifications() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge])
                SettingsManager.shared.notificationsAuthorized = granted
                await checkNotificationStatus()
            } catch {
                SentinelLogger.uiController.error(
                    "Failed to request notifications: \(error.localizedDescription)")
            }
        }
    }

    private func completeOnboarding() {
        SettingsManager.shared.hasCompletedOnboarding = true
        withAnimation {
            isComplete = true
        }
    }
}

// MARK: - Onboarding Steps

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case howItWorks
    case permissions
    case launchAtLogin
}

// MARK: - Welcome Step

struct WelcomeStep: View {

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App Icon
            Image(systemName: "thermometer.and.liquid.waves")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("Welcome to Sentinel Health")
                    .font(.largeTitle.bold())

                Text("Intelligent thermal management for your Mac")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - How It Works Step

struct HowItWorksStep: View {

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("How It Works")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "thermometer.sun",
                    title: "Monitors Thermal State",
                    description: "Continuously tracks your Mac's temperature and memory pressure"
                )

                FeatureRow(
                    icon: "brain.head.profile",
                    title: "Predicts Issues",
                    description:
                        "Uses machine learning to predict thermal throttling before it happens"
                )

                FeatureRow(
                    icon: "moon.zzz",
                    title: "Suspends Idle Apps",
                    description:
                        "Temporarily pauses inactive apps to free memory and reduce heat"
                )

                FeatureRow(
                    icon: "bolt.circle",
                    title: "Restores Instantly",
                    description: "Automatically wakes apps when you need them, with zero delay"
                )
            }
            .padding(.horizontal)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - Feature Row

struct FeatureRow: View {

    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Permissions Step

struct PermissionsStep: View {

    let notificationStatus: UNAuthorizationStatus
    let onRequestNotifications: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Permissions")
                .font(.title.bold())

            Text("Sentinel Health needs a few permissions to work effectively.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                PermissionRow(
                    icon: "bell.badge",
                    title: "Notifications",
                    description: "Get alerts when thermal issues are detected",
                    status: notificationStatus,
                    action: onRequestNotifications
                )
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
            .padding(.horizontal)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - Permission Row

struct PermissionRow: View {

    let icon: String
    let title: String
    let description: String
    let status: UNAuthorizationStatus
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 40, height: 40)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusButton
        }
    }

    @ViewBuilder
    private var statusButton: some View {
        switch status {
        case .authorized:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)

        case .denied:
            Button("Open Settings") {
                if let url = URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.notifications?com.sentinel.health"
                ) {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .notDetermined:
            Button("Enable") {
                action()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

        default:
            EmptyView()
        }
    }
}

// MARK: - Launch at Login Step

struct LaunchAtLoginStep: View {

    let onComplete: () -> Void

    @State private var launchAtLogin = true

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.title.bold())

                Text("Sentinel Health will now protect your Mac from thermal issues.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Toggle("Launch Sentinel Health at Login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
                .padding(.horizontal)
                .onChange(of: launchAtLogin) { _, newValue in
                    SettingsManager.shared.launchAtLogin = newValue
                }

            Spacer()

            Button(action: onComplete) {
                Text("Start Using Sentinel Health")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(isComplete: .constant(false))
}
