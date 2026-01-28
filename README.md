# Sentinel Health

**Proactive Thermal Intelligence for Apple Silicon Macs**

Sentinel Health is a native macOS menu bar application that uses predictive thermal management to prevent performance degradation before it occurs. Built specifically for Apple Silicon M4 Macs, it ensures your system never experiences thermal throttling during intensive workloads.

---

## Features

### Thermal Intelligence Engine
- ML-based prediction system that anticipates thermal escalation
- Real-time monitoring of thermal state transitions
- 10Hz inference rate with <100ms latency
- Configurable prediction thresholds

### Intelligent Process Offloading
- Automatic suspension of idle background processes via SIGSTOP/SIGCONT
- Smart candidate selection based on idle time and memory footprint
- Instant restoration when user switches to suspended app (<100ms)
- Respects user-defined exclusion lists

### Unified Memory Monitor
- Real-time tracking of M4 unified memory metrics
- Memory pressure level monitoring
- Wired, compressed, and available memory stats
- Low overhead (<1% CPU)

### Premium Menu Bar UI
- Dynamic thermal state indicator with SF Symbols
- Quick access popover with current status
- List of offloaded processes with restore controls
- SwiftUI with material effects and smooth animations

### Analytics Dashboard
- Historical thermal events timeline
- Prediction accuracy tracking
- Memory savings summary
- Most frequently offloaded apps

---

## Requirements

- **macOS 15 Sequoia** or later
- **Apple Silicon M4** Mac
- Xcode 16+ (for building from source)

---

## Installation

### From Release
1. Download the latest release from [Releases](https://github.com/salvadalba/nodaysidle-sentinelhealth/releases)
2. Drag `SentinelHealth.app` to `/Applications`
3. Launch from Applications or Spotlight

### Build from Source
```bash
# Clone the repository
git clone https://github.com/salvadalba/nodaysidle-sentinelhealth.git
cd nodaysidle-sentinelhealth/SentinelHealth

# Build with Xcode
xcodebuild -scheme SentinelHealth -configuration Release build

# Or open in Xcode
open SentinelHealth.xcodeproj
```

---

## Architecture

```
SentinelHealth/
├── Core/
│   ├── ApplicationController.swift   # Main app orchestration
│   ├── SettingsManager.swift          # User preferences
│   ├── SentinelError.swift            # Error handling
│   ├── Logging.swift                  # OSLog infrastructure
│   └── Constants.swift                # App-wide constants
├── Services/
│   ├── ThermalIntelligenceEngine.swift    # ML prediction
│   ├── ProcessOffloadManager.swift         # SIGSTOP/SIGCONT management
│   ├── UnifiedMemoryMonitor.swift          # Memory metrics
│   ├── ThermalStateMonitor.swift           # Thermal state tracking
│   ├── ProcessEnumerator.swift             # Process listing
│   ├── MetricsAggregator.swift             # Metrics coordination
│   ├── NotificationCoordinator.swift       # User alerts
│   └── HistoricalAnalyticsStore.swift      # SwiftData persistence
├── Models/
│   ├── ThermalPrediction.swift        # ML types & feature vectors
│   ├── OffloadedProcess.swift         # SwiftData model + DTO
│   ├── ThermalEvent.swift             # Historical events
│   └── DataStore.swift                # Data management
└── Views/
    ├── MenuBarView.swift              # Main popover UI
    ├── SettingsView.swift             # Preferences UI
    ├── AnalyticsDashboardView.swift   # Analytics charts
    ├── OnboardingView.swift           # First-launch experience
    └── Components/                    # Reusable UI components
```

---

## How It Works

1. **Monitor**: Continuously samples thermal state and memory pressure at 1Hz
2. **Predict**: ML engine analyzes metrics to predict thermal escalation (10Hz)
3. **Offload**: When high thermal risk detected, suspends idle background processes
4. **Restore**: Automatically resumes processes when user switches to them or thermal condition clears

### Thermal States

| State | Description | Action |
|-------|-------------|--------|
| Nominal | System running cool | No action |
| Fair | Slight thermal activity | Monitor closely |
| Serious | Thermal mitigation active | Conservative offloading |
| Critical | Throttling imminent | Aggressive offloading |

---

## Configuration

Access settings via the menu bar icon → Settings:

- **Prediction Sensitivity**: Adjust thermal prediction threshold (0.5-0.9)
- **Notification Frequency**: Control alert frequency
- **Exclusion List**: Apps that should never be offloaded
- **Launch at Login**: Start automatically with macOS
- **CloudKit Sync**: Sync settings across devices (optional)

---

## Tech Stack

- **Swift 6** with full concurrency compliance
- **SwiftUI** for native macOS UI
- **SwiftData** for persistence
- **OSLog** for structured logging
- **Swift Charts** for analytics visualization
- **Observation** framework for reactive state

---

## Privacy

Sentinel Health is a **local-first** application:
- All ML inference runs on-device
- No data leaves your Mac (unless CloudKit sync enabled)
- No telemetry or analytics collection
- Process monitoring is read-only

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Contributing

Contributions welcome! Please read the PRD.md and TASKS.md for project context.

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

---

## Acknowledgments

- Built with Claude Code
- Designed for the Apple Silicon ecosystem
- Inspired by the need for proactive system maintenance

---

**Made with care for Mac power users who demand peak performance.**
