# Technical Requirements Document

## 🧭 System Context
Sentinel Health is a native macOS 15+ application providing proactive thermal management for Apple Silicon M4 Macs. The system uses CoreML for on-device ML inference to predict high-intensity workloads and intelligently offload inactive processes to SwiftData-backed cold storage before thermal throttling occurs. Architecture consists of a background daemon with menu bar companion UI built entirely in SwiftUI 6 with Swift 6 Structured Concurrency.

## 🔌 API Contracts
### ThermalIntelligenceEngine
- **Method:** async
- **Description:** _Not specified_

### UnifiedMemoryMonitor
- **Method:** async
- **Description:** _Not specified_

### ProcessOffloadManager
- **Method:** async
- **Description:** _Not specified_

### ProcessOffloadManager
- **Method:** async
- **Description:** _Not specified_

### NotificationCoordinator
- **Method:** async
- **Description:** _Not specified_

### HistoricalAnalyticsStore
- **Method:** async
- **Description:** _Not specified_

### HistoricalAnalyticsStore
- **Method:** async
- **Description:** _Not specified_

## 🧱 Modules
### ThermalIntelligenceEngine
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### UnifiedMemoryMonitor
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### ProcessOffloadManager
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### NotificationCoordinator
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### HistoricalAnalyticsStore
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### MenuBarController
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### SettingsManager
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

## 🗃 Data Model Notes
### Unknown Entity
_None_

### Unknown Entity
_None_

### Unknown Entity
_None_

### Unknown Entity
_None_

### Unknown Entity
_None_

### Unknown Entity
_None_

## 🔐 Validation & Security
- **Rule:** _Not specified_
- **Rule:** _Not specified_
- **Rule:** _Not specified_
- **Rule:** _Not specified_
- **Rule:** _Not specified_
- **Rule:** _Not specified_

## 🧯 Error Handling Strategy
Swift 6 typed throws with custom SentinelError enum conforming to LocalizedError. Actors catch and transform low-level errors into domain-specific cases. UI layer displays user-friendly alerts via NotificationCoordinator for critical failures. Non-critical errors logged locally and optionally reported via opt-in telemetry. Recovery actions embedded in error cases where applicable (e.g., SentinelError.modelNotLoaded(recoverySuggestion: .downloadModel)).

## 🔭 Observability
- **Logging:** OSLog with subsystem 'com.sentinel.health' and categories per module (ThermalEngine, MemoryMonitor, OffloadManager). Debug builds log at .debug level, release builds at .info and above. Signposts for performance-critical paths.
- **Tracing:** os_signpost intervals for prediction cycle, offload operation, and restore operation. Instruments template provided for debugging thermal behavior.
- **Metrics:**
- thermal_prediction_latency_ms: Histogram of CoreML inference time
- offload_operation_count: Counter of successful/failed offloads
- memory_reclaimed_bytes: Gauge of total memory saved
- restore_latency_ms: Histogram of process restore times
- cpu_overhead_percent: Gauge of daemon CPU usage

## ⚡ Performance Notes
- **Metric:** _Not specified_
- **Metric:** _Not specified_
- **Metric:** _Not specified_
- **Metric:** _Not specified_
- **Metric:** _Not specified_
- **Metric:** _Not specified_
- **Metric:** _Not specified_

## 🧪 Testing Strategy
### Unit
- ThermalIntelligenceEngine prediction accuracy with mock metrics
- ProcessOffloadManager serialization/deserialization round-trip
- HistoricalAnalyticsStore CRUD operations with in-memory ModelContainer
- NotificationCoordinator alert scheduling with mock UNUserNotificationCenter
### Integration
- Full prediction cycle from metric collection through offload decision
- SwiftData persistence across app relaunch with seeded test data
- CloudKit sync conflict resolution with simulated multi-device scenario
- Privileged helper communication via XPC with sandboxed test harness
### E2E
- Menu bar app launch and thermal state display on simulated workload
- Settings scene navigation and preference persistence
- Notification delivery and action handling on prediction trigger
- Process offload and restore cycle with real Safari process (manual test)

## 🚀 Rollout Plan
### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

## ❓ Open Questions
- What specific process state must be captured for reliable restoration beyond memory footprint?
- How to handle offload requests for processes with open file handles or network connections?
- Should the privileged helper be required for App Store distribution or offer reduced functionality?
- What is the minimum training dataset size for acceptable CoreML prediction accuracy?
- How to validate thermal predictions without user-reported ground truth on throttling events?