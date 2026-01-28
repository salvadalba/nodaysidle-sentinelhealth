# Tasks Plan — SENTINEL HEALTH

## 📌 Global Assumptions
- Target platform is macOS 15+ (Sequoia) on Apple Silicon M4 Macs only
- User has Xcode 16+ with Swift 6 toolchain installed
- App will be distributed via Mac App Store or Developer ID notarization
- CoreML model will initially be rule-based, with ML training deferred to post-launch
- Process suspension limited to user-level apps, not system processes
- CloudKit sync is optional feature, app is fully functional offline
- Privileged helper is optional for enhanced capabilities

## ⚠️ Risks
- Process suspension may be unreliable for apps with active network connections or file handles
- Apple may restrict SIGSTOP usage in future macOS versions or App Store review
- CoreML prediction accuracy depends on training data that must be collected post-launch
- Menu bar app architecture may conflict with App Nap and system power management
- Privileged helper installation friction may reduce user adoption
- Thermal state APIs may not provide sufficient granularity for reliable predictions

## 🧩 Epics
## Project Foundation
**Goal:** Establish the macOS app structure, build system, and core architecture patterns

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create Xcode project with SwiftPM structure (S)

Initialize a new macOS 15+ Menu Bar application project using Swift Package Manager. Configure for Apple Silicon M4 target with SwiftUI 6 lifecycle.

**Acceptance Criteria**
- Project compiles and runs on macOS 15+
- Menu bar icon displays correctly
- SwiftUI App lifecycle configured with @main
- Swift 6 language mode enabled

**Dependencies**
_None_

### ✅ Define SentinelError enum with typed throws (S)

Create the core error handling type conforming to LocalizedError with recovery suggestions embedded in cases.

**Acceptance Criteria**
- SentinelError enum covers all known failure modes
- Each case has localized description and recovery suggestion
- Typed throws compatible with Swift 6
- Unit tests verify error message formatting

**Dependencies**
_None_

### ✅ Configure OSLog subsystem and categories (S)

Set up logging infrastructure with 'com.sentinel.health' subsystem and per-module categories (ThermalEngine, MemoryMonitor, OffloadManager, etc.).

**Acceptance Criteria**
- Logger instances created for each module category
- Debug builds log at .debug level
- Release builds log at .info and above
- os_signpost helpers available for performance tracing

**Dependencies**
_None_

### ✅ Create Settings scene with basic preferences UI (S)

Implement SwiftUI Settings scene with .ultraThinMaterial styling for app preferences.

**Acceptance Criteria**
- Settings window opens from menu bar
- Uses .ultraThinMaterial background
- Preferences persist via @AppStorage
- Window has premium NSWindow customization

**Dependencies**
_None_

## Unified Memory Monitor
**Goal:** Build real-time monitoring of M4 unified memory and system metrics

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create UnifiedMemoryMonitor actor (M)

Implement actor-isolated monitor using IOKit/sysctl to read unified memory pressure, GPU memory, and neural engine utilization.

**Acceptance Criteria**
- Actor provides async stream of memory metrics
- Polls at configurable interval (default 1 second)
- Captures unified memory total, used, and pressure level
- Low CPU overhead (<1% in steady state)

**Dependencies**
_None_

### ✅ Implement thermal state monitoring (M)

Use ProcessInfo.thermalState and IOKit to monitor current thermal pressure and fan speeds on M4 Macs.

**Acceptance Criteria**
- Async stream of thermal state changes
- Detects nominal, fair, serious, critical states
- Combines with memory metrics into ThermalSnapshot type
- os_signpost marks sampling intervals

**Dependencies**
- Create UnifiedMemoryMonitor actor

### ✅ Create process enumeration service (M)

Build service to enumerate running processes with memory footprint, CPU usage, and idle duration using proc APIs.

**Acceptance Criteria**
- Returns list of ProcessInfo with pid, name, memory, CPU, idle time
- Filters to user-level processes only
- Excludes system-critical processes by default
- Handles permission errors gracefully

**Dependencies**
_None_

### ✅ Add metrics collection aggregator (S)

Combine memory, thermal, and process metrics into unified MetricsSnapshot published via Observation framework.

**Acceptance Criteria**
- @Observable class provides current metrics
- Updates at 1Hz for UI, 10Hz for ML inference
- Exposes thermal_prediction_latency_ms histogram
- memory_reclaimed_bytes gauge updates on offload

**Dependencies**
- Implement thermal state monitoring
- Create process enumeration service

## SwiftData Persistence Layer
**Goal:** Implement SwiftData models for process state cold storage and historical analytics

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Define OffloadedProcess SwiftData model (S)

Create @Model class to persist offloaded process state including pid, bundle ID, memory snapshot, file handles, and timestamp.

**Acceptance Criteria**
- @Model with all required properties
- Supports serialization of process memory state reference
- Indexed by bundle ID and timestamp
- Unit tests verify round-trip persistence

**Dependencies**
_None_

### ✅ Define ThermalEvent SwiftData model (S)

Create @Model class for historical thermal events including prediction, actual outcome, and offload actions taken.

**Acceptance Criteria**
- Captures prediction timestamp, confidence, and actual thermal state
- Links to OffloadedProcess records via relationship
- Supports CloudKit sync schema requirements
- Cascade delete of related offload records

**Dependencies**
- Define OffloadedProcess SwiftData model

### ✅ Create ModelContainer configuration (S)

Configure SwiftData ModelContainer with both models, CloudKit sync (optional), and migration support.

**Acceptance Criteria**
- ModelContainer initializes on app launch
- Supports in-memory configuration for testing
- CloudKit sync toggle in settings
- Handles schema migration gracefully

**Dependencies**
- Define ThermalEvent SwiftData model

### ✅ Implement HistoricalAnalyticsStore actor (M)

Build actor wrapping SwiftData context for thread-safe CRUD operations on thermal events and offload records.

**Acceptance Criteria**
- Async methods for insert, query, delete
- Query by date range and thermal state
- Aggregation methods for analytics dashboard
- Unit tests with in-memory ModelContainer

**Dependencies**
- Create ModelContainer configuration

## Thermal Intelligence Engine
**Goal:** Build CoreML-based prediction engine for proactive thermal management

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Design ML feature vector from metrics (M)

Define the input feature schema for CoreML model based on memory pressure, CPU load, GPU utilization, recent thermal history, and time-of-day patterns.

**Acceptance Criteria**
- Feature vector documented with 10-20 input dimensions
- Normalization strategy defined for each feature
- Sample data collection script created
- Minimum training dataset size estimated

**Dependencies**
- Add metrics collection aggregator

### ✅ Create placeholder CoreML model (M)

Generate a simple rule-based .mlmodel placeholder that can be swapped for trained model later. Uses CreateML tabular classifier template.

**Acceptance Criteria**
- Compiles to .mlmodelc bundle
- Accepts feature vector input
- Outputs prediction (low/medium/high thermal risk) with confidence
- Inference time <10ms on M4

**Dependencies**
- Design ML feature vector from metrics

### ✅ Implement ThermalIntelligenceEngine actor (M)

Build actor that runs CoreML inference on metrics stream and emits thermal predictions with configurable threshold.

**Acceptance Criteria**
- Async stream of ThermalPrediction events
- Configurable prediction threshold (default 0.7)
- Logs inference latency via os_signpost
- Handles model loading errors with recovery

**Dependencies**
- Create placeholder CoreML model

### ✅ Add prediction feedback loop (M)

Compare predictions to actual thermal outcomes and persist accuracy metrics for model improvement.

**Acceptance Criteria**
- Records prediction vs actual thermal state
- Calculates rolling accuracy over last 100 predictions
- Stores feedback in HistoricalAnalyticsStore
- Exposes accuracy metric for UI display

**Dependencies**
- Implement ThermalIntelligenceEngine actor
- Implement HistoricalAnalyticsStore actor

## Process Offload Manager
**Goal:** Implement intelligent process suspension and restoration with state preservation

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Research process suspension APIs (M)

Investigate SIGSTOP/SIGCONT, launchd mechanisms, and App Nap APIs for safely suspending user processes on macOS.

**Acceptance Criteria**
- Document available suspension mechanisms
- Identify processes safe to suspend vs system-critical
- Determine privilege requirements for each approach
- List known limitations (file handles, network connections)

**Dependencies**
_None_

### ✅ Implement process suspension via SIGSTOP (M)

Create ProcessSuspender that sends SIGSTOP to targeted processes, requiring appropriate entitlements or privileged helper.

**Acceptance Criteria**
- Suspends process by pid
- Verifies process is in stopped state
- Records suspension timestamp in SwiftData
- Handles permission denied gracefully

**Dependencies**
- Research process suspension APIs
- Define OffloadedProcess SwiftData model

### ✅ Implement process restoration via SIGCONT (S)

Create ProcessRestorer that sends SIGCONT and verifies process resumes correctly, logging restore latency.

**Acceptance Criteria**
- Restores process by pid from stored record
- Verifies process is in running state
- Records restore_latency_ms metric
- Removes OffloadedProcess record on success

**Dependencies**
- Implement process suspension via SIGSTOP

### ✅ Create ProcessOffloadManager actor (M)

Build orchestrating actor that decides which processes to offload based on thermal predictions and process idle time.

**Acceptance Criteria**
- Async method to trigger offload cycle
- Ranks processes by idle time and memory footprint
- Respects user-configured exclusion list
- Emits offload_operation_count metrics

**Dependencies**
- Implement process restoration via SIGCONT
- Implement ThermalIntelligenceEngine actor

### ✅ Add automatic restoration trigger (M)

Monitor for user interaction with suspended processes and trigger automatic restoration before user notices delay.

**Acceptance Criteria**
- Detects app switch to suspended process
- Restores within 100ms of detection
- Logs restoration reason (user-initiated vs thermal-clear)
- Integration test with Safari process (manual)

**Dependencies**
- Create ProcessOffloadManager actor

## Notification Coordinator
**Goal:** Provide user-facing alerts and status updates for thermal events

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Request notification permissions (S)

Implement UNUserNotificationCenter authorization request on first launch with graceful degradation if denied.

**Acceptance Criteria**
- Requests authorization on first launch
- Stores permission state in settings
- Falls back to menu bar alerts if denied
- Unit test with mock UNUserNotificationCenter

**Dependencies**
_None_

### ✅ Implement NotificationCoordinator actor (M)

Build actor that schedules and manages local notifications for thermal predictions and offload events.

**Acceptance Criteria**
- Schedules notification on high thermal prediction
- Notification includes action buttons (Dismiss, View Details)
- Respects user preference for notification frequency
- Handles notification tap to open Settings scene

**Dependencies**
- Request notification permissions

### ✅ Create menu bar status indicators (S)

Add dynamic menu bar icon that changes color/style based on current thermal state (green/yellow/red).

**Acceptance Criteria**
- Icon updates in real-time with thermal state
- Uses SF Symbols with rendering mode for color
- Tooltip shows current thermal summary
- Smooth animation between states

**Dependencies**
- Add metrics collection aggregator

## Menu Bar Controller
**Goal:** Build the primary menu bar UI with status display and quick actions

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create MenuBarController with popover (M)

Implement NSStatusItem with SwiftUI popover showing current thermal status, memory usage, and active offloads.

**Acceptance Criteria**
- Popover opens on menu bar icon click
- Uses .regularMaterial background
- Displays current thermal state prominently
- Shows memory usage gauge with animation

**Dependencies**
- Create menu bar status indicators

### ✅ Add offloaded processes list view (M)

Show list of currently offloaded processes with restore button for each.

**Acceptance Criteria**
- List updates in real-time via Observation
- Each row shows app icon, name, memory saved, duration
- Restore button with confirmation
- Empty state when no processes offloaded

**Dependencies**
- Create MenuBarController with popover
- Create ProcessOffloadManager actor

### ✅ Implement quick actions menu (S)

Add context menu with actions: Force Offload Now, Restore All, Open Settings, Quit.

**Acceptance Criteria**
- Right-click on menu bar icon shows menu
- Force Offload triggers immediate offload cycle
- Restore All resumes all suspended processes
- Keyboard shortcuts for common actions

**Dependencies**
- Add offloaded processes list view

### ✅ Add premium visual effects (M)

Implement Metal shader-backed visual effects for thermal state visualization and smooth animations.

**Acceptance Criteria**
- Gradient animation reflects thermal intensity
- matchedGeometryEffect for list item transitions
- PhaseAnimator for pulsing warning states
- TimelineView for smooth gauge updates

**Dependencies**
- Create MenuBarController with popover

## Settings Manager
**Goal:** Build comprehensive settings UI for user preferences and exclusions

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement SettingsManager with @AppStorage (S)

Create observable settings manager persisting user preferences including prediction threshold, notification settings, and exclusion list.

**Acceptance Criteria**
- @Observable class with @AppStorage backing
- Default values for all settings
- Type-safe access to all preferences
- Migration from legacy UserDefaults if needed

**Dependencies**
_None_

### ✅ Create General settings tab (M)

Build settings tab for general preferences: launch at login, prediction sensitivity, notification frequency.

**Acceptance Criteria**
- Launch at login toggle with SMAppService
- Prediction sensitivity slider (0.5-0.9 threshold)
- Notification frequency picker (always/hourly/daily/never)
- Uses .ultraThinMaterial consistent with app style

**Dependencies**
- Implement SettingsManager with @AppStorage

### ✅ Create Exclusions settings tab (M)

Build UI for managing process exclusion list - apps that should never be offloaded.

**Acceptance Criteria**
- List of excluded apps with remove button
- Add button opens file picker for .app bundles
- Common apps (Finder, System Settings) pre-excluded
- Exclusion list syncs via CloudKit if enabled

**Dependencies**
- Implement SettingsManager with @AppStorage

### ✅ Create Advanced settings tab (S)

Build advanced settings for power users: daemon CPU limit, logging level, CloudKit sync toggle.

**Acceptance Criteria**
- Daemon CPU overhead limit slider (1-5%)
- Debug logging toggle for troubleshooting
- CloudKit sync enable/disable
- Reset to defaults button with confirmation

**Dependencies**
- Implement SettingsManager with @AppStorage

## Analytics Dashboard
**Goal:** Provide historical analytics and insights on thermal management effectiveness

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create analytics dashboard view (M)

Build SwiftUI view showing historical thermal events, prediction accuracy, and memory saved over time.

**Acceptance Criteria**
- Accessible from menu bar popover and Settings
- Shows last 7/30/90 days of data
- Swift Charts for visualizations
- Uses .regularMaterial background

**Dependencies**
- Implement HistoricalAnalyticsStore actor

### ✅ Implement thermal events timeline (M)

Show timeline chart of thermal predictions and actual outcomes with accuracy indicators.

**Acceptance Criteria**
- Swift Charts line/scatter plot
- Color-coded by prediction accuracy
- Zoom/pan for date range selection
- Tooltip shows event details on hover

**Dependencies**
- Create analytics dashboard view

### ✅ Add memory savings summary (S)

Display aggregate statistics on memory reclaimed through offloading.

**Acceptance Criteria**
- Total memory saved (GB) over period
- Average offload duration
- Most frequently offloaded apps
- Estimated thermal throttle events prevented

**Dependencies**
- Create analytics dashboard view

## Privileged Helper
**Goal:** Optional privileged helper for enhanced process control capabilities

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Research SMAppService privileged helper (M)

Investigate requirements for installing a privileged helper for process suspension on restricted apps.

**Acceptance Criteria**
- Document entitlement requirements
- Determine App Store vs Developer ID distribution impact
- Design XPC communication protocol
- Assess user trust implications

**Dependencies**
_None_

### ✅ Create XPC service protocol (M)

Define XPC protocol for communication between main app and privileged helper.

**Acceptance Criteria**
- Protocol supports suspend/restore commands
- Includes process validation to prevent abuse
- Versioned for future compatibility
- Unit tests with mock XPC connection

**Dependencies**
- Research SMAppService privileged helper

### ✅ Implement privileged helper target (L)

Create separate target for privileged helper daemon with minimal attack surface.

**Acceptance Criteria**
- Separate Xcode target for helper
- Runs as root with minimal permissions
- Validates all XPC requests against allowlist
- Logs all operations for audit

**Dependencies**
- Create XPC service protocol

### ✅ Add helper installation flow (M)

Implement UI flow for installing privileged helper with admin authentication.

**Acceptance Criteria**
- Explains why helper is needed
- Uses Authorization Services for admin prompt
- Graceful fallback if user declines
- Shows helper status in Settings

**Dependencies**
- Implement privileged helper target

## Testing and Quality
**Goal:** Comprehensive test coverage and quality assurance

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Write unit tests for ThermalIntelligenceEngine (M)

Create unit tests verifying prediction logic with mock metrics inputs.

**Acceptance Criteria**
- Tests cover all prediction threshold scenarios
- Mock CoreML model for deterministic results
- Verifies error handling for model load failures
- 80%+ code coverage for engine module

**Dependencies**
- Implement ThermalIntelligenceEngine actor

### ✅ Write unit tests for ProcessOffloadManager (M)

Test offload serialization, restoration, and decision logic with mock processes.

**Acceptance Criteria**
- Tests round-trip of process state
- Verifies exclusion list is respected
- Tests concurrent offload requests
- 80%+ code coverage for offload module

**Dependencies**
- Create ProcessOffloadManager actor

### ✅ Write integration tests for prediction cycle (M)

Test full flow from metric collection through offload decision with real SwiftData.

**Acceptance Criteria**
- End-to-end test with seeded metrics
- Verifies SwiftData persistence
- Tests CloudKit sync conflict resolution
- Uses XCTest async/await patterns

**Dependencies**
- Add prediction feedback loop

### ✅ Create Instruments template (M)

Build custom Instruments template for profiling thermal behavior and daemon overhead.

**Acceptance Criteria**
- Template tracks os_signpost intervals
- Visualizes prediction cycle timing
- Shows memory and CPU impact of daemon
- Documentation for developer use

**Dependencies**
- Configure OSLog subsystem and categories

## Distribution and Polish
**Goal:** Prepare app for distribution with final polish and documentation

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Design app icon and assets (M)

Create app icon, menu bar icons, and marketing assets following macOS design guidelines.

**Acceptance Criteria**
- 1024x1024 app icon with all sizes
- Menu bar icon set for light/dark/tinted
- SF Symbols usage where appropriate
- Assets catalog properly configured

**Dependencies**
_None_

### ✅ Write onboarding flow (M)

Create first-launch onboarding explaining app capabilities and requesting permissions.

**Acceptance Criteria**
- 3-4 step onboarding wizard
- Explains thermal management concept
- Requests notification permissions
- Offers to enable launch at login

**Dependencies**
- Request notification permissions

### ✅ Configure code signing and notarization (M)

Set up Developer ID or App Store signing with notarization for distribution.

**Acceptance Criteria**
- Hardened runtime enabled
- All entitlements properly configured
- Notarization passes without errors
- Gatekeeper allows app execution

**Dependencies**
_None_

### ✅ Create App Store metadata (S)

Write App Store description, screenshots, and privacy policy for submission.

**Acceptance Criteria**
- Compelling app description
- 5 screenshots showing key features
- Privacy policy documenting data handling
- Keywords optimized for discoverability

**Dependencies**
- Design app icon and assets

## ❓ Open Questions
- What specific process state must be captured for reliable restoration beyond memory footprint?
- How to handle offload requests for processes with open file handles or network connections?
- Should the privileged helper be required for App Store distribution or offer reduced functionality?
- What is the minimum training dataset size for acceptable CoreML prediction accuracy?
- How to validate thermal predictions without user-reported ground truth on throttling events?
- Is SIGSTOP/SIGCONT approach acceptable for App Store review or is alternative needed?