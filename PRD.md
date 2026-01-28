# Sentinel Health

## 🎯 Product Vision
A proactive, ML-driven system maintenance application for macOS that uses Thermal Intelligence to predict and prevent performance degradation before it occurs, ensuring Apple Silicon Macs never experience thermal throttling during intensive workloads.

## ❓ Problem Statement
Current system maintenance tools like CleanMyMac X rely on reactive, manual scanning approaches that only address problems after they occur. Users experience unexpected thermal throttling during high-intensity tasks like 4K rendering because existing tools cannot predict workload patterns or proactively manage system resources. This results in interrupted workflows, reduced performance, and shortened hardware lifespan.

## 🎯 Goals
- Eliminate thermal throttling on M4 Macs through predictive resource management
- Provide real-time monitoring of unified memory and neural core utilization
- Intelligently offload inactive processes to cold storage before high-intensity tasks begin
- Deliver a premium, native macOS experience with minimal user intervention required
- Operate entirely on-device with no cloud dependency for core functionality

## 🚫 Non-Goals
- Replacing Apple's built-in Activity Monitor for detailed process inspection
- Providing antivirus or malware detection capabilities
- Supporting Intel-based Macs or macOS versions prior to Sequoia
- Offering cross-platform compatibility with iOS or iPadOS
- Building a subscription-based cloud service backend

## 👥 Target Users
- Creative professionals using M4 Macs for video editing, 3D rendering, and music production
- Software developers running resource-intensive build processes and virtual machines
- Power users who want their Mac to maintain peak performance without manual intervention
- Professionals who cannot afford workflow interruptions due to thermal throttling

## 🧩 Core Features
- Thermal Intelligence Engine: CoreML-powered predictive model that analyzes usage patterns to anticipate high-intensity workloads
- Real-time Unified Memory Monitor: Live visualization of M4 unified memory and neural core utilization using Metal shaders
- Intelligent Process Offloading: SwiftData-backed cold storage system that hibernates inactive background processes preemptively
- Menu Bar Companion: Always-accessible thermal status indicator with quick actions using .ultraThinMaterial design
- Predictive Alerts: Notification system that warns users before thermal events occur with suggested actions
- Historical Analytics: SwiftData-persisted performance history with trend analysis and optimization recommendations
- Settings Scene: Native macOS Settings integration for configuring thresholds, automation rules, and offloading preferences

## ⚙️ Non-Functional Requirements
- Maximum 1% CPU overhead during passive monitoring mode
- Sub-100ms latency for process offloading decisions
- Local-first architecture with all ML inference performed on-device via CoreML
- Premium visual design using matchedGeometryEffect, PhaseAnimator, and TimelineView for fluid animations
- NSWindow customization for distinctive, professional appearance
- Full Swift 6 concurrency compliance with Sendable conformance throughout
- Optional CloudKit sync for settings and historical data across user devices

## 📊 Success Metrics
- 95% reduction in thermal throttling events during monitored high-intensity workloads
- Less than 50MB memory footprint for the background monitoring daemon
- 90% prediction accuracy for high-intensity workload detection within 30-second window
- Average process offload/restore cycle under 500ms
- User satisfaction rating of 4.5+ stars on the Mac App Store

## 📌 Assumptions
- Users are running macOS 15 Sequoia or later on Apple Silicon M4 hardware
- The M4 thermal sensors and performance counters are accessible via system APIs
- Users will grant necessary permissions for process monitoring and management
- CoreML models can be trained on representative workload patterns for accurate predictions
- SwiftData provides sufficient performance for real-time cold storage operations

## ❓ Open Questions
- What system APIs are available for accessing M4 neural core utilization metrics?
- How will the app handle processes that cannot be safely offloaded without data loss?
- What is the optimal training data strategy for the Thermal Intelligence CoreML model?
- Should the app require elevated privileges or operate within App Sandbox constraints?
- How will users customize which applications are exempt from automatic offloading?