# Architecture Requirements Document

## 🧱 System Overview
Sentinel Health is a native macOS 15+ application that provides proactive thermal management for Apple Silicon M4 Macs through ML-driven prediction and intelligent process offloading. The system operates as a lightweight background daemon with a menu bar companion and native Settings integration, performing all inference on-device using CoreML while persisting data locally via SwiftData with optional CloudKit sync.

## 🏗 Architecture Style
Local-first monolithic macOS application with background daemon and menu bar UI

## 🎨 Frontend Architecture
- **Framework:** SwiftUI 6 with Observation framework
- **State Management:** Observation framework with @Observable macro for reactive state propagation
- **Routing:** NavigationStack for Settings scene, WindowGroup and MenuBarExtra for primary surfaces
- **Build Tooling:** Xcode 16+ with Swift Package Manager for dependencies

## 🧠 Backend Architecture
- **Approach:** In-process Swift 6 Structured Concurrency with actor-based isolation for thermal monitoring and process management
- **API Style:** Internal Swift async/await APIs with Sendable data transfer objects
- **Services:**
- ThermalIntelligenceEngine: CoreML-powered prediction actor for workload forecasting
- UnifiedMemoryMonitor: Real-time M4 unified memory and neural core metrics collector
- ProcessOffloadManager: SwiftData-backed cold storage actor for process hibernation
- NotificationCoordinator: User Notifications framework integration for predictive alerts
- HistoricalAnalyticsStore: SwiftData repository for performance trend persistence

## 🗄 Data Layer
- **Primary Store:** SwiftData with ModelContainer for local persistence
- **Relationships:** Flat schema with ThermalEvent, OffloadedProcess, and PerformanceSnapshot models linked by timestamps
- **Migrations:** SwiftData automatic lightweight migrations with versioned ModelSchema

## ☁️ Infrastructure
- **Hosting:** Local macOS application distributed via Mac App Store or notarized DMG
- **Scaling Strategy:** Single-user local execution with optional CloudKit sync for multi-device settings
- **CI/CD:** Xcode Cloud or GitHub Actions for automated builds, tests, and notarization

## ⚖️ Key Trade-offs
- App Sandbox constraints limit deep process management; may require privileged helper tool for full offloading capabilities
- CoreML model accuracy depends on representative training data which must be gathered post-launch through opt-in telemetry
- Real-time Metal shader visualizations increase GPU utilization; disabled by default in low-power mode
- SwiftData cold storage approach trades disk I/O for memory savings; SSD performance critical for sub-500ms restore times

## 📐 Non-Functional Requirements
- Maximum 1% CPU overhead during passive monitoring
- Sub-100ms latency for offloading decisions
- Under 50MB memory footprint for background daemon
- Full Swift 6 Sendable conformance for concurrency safety
- Premium visual design with matchedGeometryEffect, PhaseAnimator, and TimelineView animations
- NSWindow customization for distinctive appearance with .ultraThinMaterial