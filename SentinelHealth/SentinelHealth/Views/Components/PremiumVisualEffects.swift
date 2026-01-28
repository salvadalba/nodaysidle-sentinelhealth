//
//  PremiumVisualEffects.swift
//  SentinelHealth
//
//  Premium visual effects including animated gradients, thermal indicators, and smooth animations.
//

import SwiftUI

// MARK: - Thermal Gradient View

/// Animated gradient view that reflects thermal intensity
struct ThermalGradientView: View {

    let thermalState: ThermalDisplayState

    @State private var animationPhase: Double = 0

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: animatedPoints,
            colors: thermalColors
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animationPhase = 1
            }
        }
    }

    private var animatedPoints: [SIMD2<Float>] {
        let offset = Float(sin(animationPhase * .pi) * 0.1)
        return [
            SIMD2(0, 0), SIMD2(0.5, 0), SIMD2(1, 0),
            SIMD2(0, 0.5 + offset), SIMD2(0.5, 0.5), SIMD2(1, 0.5 - offset),
            SIMD2(0, 1), SIMD2(0.5, 1), SIMD2(1, 1),
        ]
    }

    private var thermalColors: [Color] {
        switch thermalState {
        case .nominal:
            return [
                .green.opacity(0.3), .mint.opacity(0.2), .cyan.opacity(0.3),
                .green.opacity(0.2), .teal.opacity(0.3), .mint.opacity(0.2),
                .cyan.opacity(0.3), .green.opacity(0.2), .mint.opacity(0.3),
            ]
        case .fair:
            return [
                .yellow.opacity(0.3), .orange.opacity(0.2), .yellow.opacity(0.3),
                .orange.opacity(0.2), .yellow.opacity(0.4), .orange.opacity(0.2),
                .yellow.opacity(0.3), .orange.opacity(0.2), .yellow.opacity(0.3),
            ]
        case .serious:
            return [
                .orange.opacity(0.4), .red.opacity(0.3), .orange.opacity(0.4),
                .red.opacity(0.3), .orange.opacity(0.5), .red.opacity(0.3),
                .orange.opacity(0.4), .red.opacity(0.3), .orange.opacity(0.4),
            ]
        case .critical:
            return [
                .red.opacity(0.5), .pink.opacity(0.4), .red.opacity(0.5),
                .pink.opacity(0.4), .red.opacity(0.6), .pink.opacity(0.4),
                .red.opacity(0.5), .pink.opacity(0.4), .red.opacity(0.5),
            ]
        }
    }
}

// MARK: - Pulsing Warning Indicator

/// Pulsing indicator for warning states using PhaseAnimator
struct PulsingWarningIndicator: View {

    let isActive: Bool
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay {
                if isActive {
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 2)
                        .phaseAnimator([0.0, 1.0]) { content, phase in
                            content
                                .scaleEffect(1 + phase * 0.5)
                                .opacity(1 - phase)
                        }
                }
            }
    }
}

// MARK: - Animated Gauge

/// Smooth animated gauge using TimelineView for real-time updates
struct AnimatedGauge: View {

    let value: Double
    let label: String
    let color: Color

    @State private var displayValue: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)

                Circle()
                    .trim(from: 0, to: displayValue)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.5), color],
                            center: .center,
                            startAngle: .zero,
                            endAngle: .degrees(360 * displayValue)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: displayValue)

                VStack(spacing: 2) {
                    Text("\(Int(displayValue * 100))")
                        .font(.title2.bold().monospacedDigit())

                    Text("%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            displayValue = value
        }
        .onChange(of: value) { _, newValue in
            displayValue = newValue
        }
    }
}

// MARK: - Memory Bar with Animation

/// Animated memory usage bar with smooth transitions
struct AnimatedMemoryBar: View {

    let usedMemory: Double
    let totalLabel: String

    @State private var animatedValue: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Memory Usage")
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text("\(Int(animatedValue * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 6)
                        .fill(barGradient)
                        .frame(width: geometry.size.width * animatedValue)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.7), value: animatedValue)

                    // Highlight
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: geometry.size.width * animatedValue, height: 4)
                        .offset(y: -2)
                }
            }
            .frame(height: 12)

            Text(totalLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .onAppear {
            animatedValue = usedMemory
        }
        .onChange(of: usedMemory) { _, newValue in
            animatedValue = newValue
        }
    }

    private var barGradient: LinearGradient {
        let color = barColor
        return LinearGradient(
            colors: [color.opacity(0.7), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var barColor: Color {
        switch animatedValue {
        case 0..<0.5: return .green
        case 0.5..<0.75: return .yellow
        case 0.75..<0.9: return .orange
        default: return .red
        }
    }
}

// MARK: - Thermal State Card

/// Premium card showing thermal state with visual effects
struct ThermalStateCard: View {

    let state: ThermalDisplayState
    let predictionConfidence: Double

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 12) {
            // Icon with glow effect
            ZStack {
                Circle()
                    .fill(state.iconColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .blur(radius: isHovering ? 15 : 10)

                Image(systemName: state.iconName)
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(state.iconColor, .secondary)
            }
            .animation(.easeInOut(duration: 0.3), value: isHovering)

            // State label
            VStack(spacing: 4) {
                Text(state.description)
                    .font(.headline)

                if predictionConfidence > 0 {
                    Text("Confidence: \(Int(predictionConfidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(state.iconColor.opacity(0.3), lineWidth: 1)
                }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Matched Geometry Effect Container

/// Container for smooth list item transitions
struct AnimatedProcessListItem<Content: View>: View {

    let id: String
    let namespace: Namespace.ID
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .matchedGeometryEffect(id: id, in: namespace)
            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
    }
}

// MARK: - Shimmer Loading Effect

/// Shimmer effect for loading states
struct ShimmerView: View {

    @State private var phase: Double = 0

    var body: some View {
        LinearGradient(
            colors: [
                .white.opacity(0.1),
                .white.opacity(0.3),
                .white.opacity(0.1),
            ],
            startPoint: .init(x: phase - 1, y: 0.5),
            endPoint: .init(x: phase, y: 0.5)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 2
            }
        }
    }
}

// MARK: - Extensions

extension View {
    /// Apply shimmer loading effect
    func shimmer(isLoading: Bool) -> some View {
        overlay {
            if isLoading {
                ShimmerView()
            }
        }
        .mask(self)
    }
}
