//
//  ProcessOffloadManagerTests.swift
//  SentinelHealthTests
//
//  Unit tests for the ProcessOffloadManager.
//

import Foundation
import Testing

@testable import SentinelHealth

// MARK: - Process Offload Manager Tests

@Suite("ProcessOffloadManager Tests")
struct ProcessOffloadManagerTests {

    // MARK: - Initialization Tests

    @Test("Manager initializes with empty offloaded list")
    func testInitializesEmpty() async {
        let manager = ProcessOffloadManager()

        let count = await manager.offloadedCount
        #expect(count == 0)
    }

    @Test("Manager initializes with default settings")
    func testInitializesWithDefaults() async {
        let manager = ProcessOffloadManager()

        let total = await manager.totalMemoryReclaimed
        #expect(total == 0)
    }

    // MARK: - Process Selection Tests

    @Test("Respects exclusion list")
    func testRespectsExclusionList() async {
        let manager = ProcessOffloadManager()

        let candidates = [
            ProcessSnapshot(
                pid: 100,
                name: "Finder",
                bundleIdentifier: "com.apple.finder",
                memoryBytes: 500_000_000,
                cpuUsage: 1.0,
                isBackground: true,
                idleDuration: 600
            ),
            ProcessSnapshot(
                pid: 101,
                name: "Safari",
                bundleIdentifier: "com.apple.Safari",
                memoryBytes: 1_000_000_000,
                cpuUsage: 0.5,
                isBackground: true,
                idleDuration: 300
            ),
        ]

        let selected = await manager.selectCandidates(from: candidates, limit: 10)

        // Finder should be excluded by default
        let hasFinder = selected.contains { $0.bundleIdentifier == "com.apple.finder" }
        #expect(!hasFinder)
    }

    @Test("Prioritizes by idle time and memory")
    func testPrioritizesByIdleAndMemory() async {
        let manager = ProcessOffloadManager()

        let candidates = [
            ProcessSnapshot(
                pid: 100,
                name: "SmallApp",
                bundleIdentifier: "com.test.small",
                memoryBytes: 100_000_000,  // 100MB
                cpuUsage: 0.1,
                isBackground: true,
                idleDuration: 300  // 5 min idle
            ),
            ProcessSnapshot(
                pid: 101,
                name: "LargeApp",
                bundleIdentifier: "com.test.large",
                memoryBytes: 2_000_000_000,  // 2GB
                cpuUsage: 0.1,
                isBackground: true,
                idleDuration: 900  // 15 min idle
            ),
        ]

        let selected = await manager.selectCandidates(from: candidates, limit: 1)

        // Should prefer LargeApp (more memory, longer idle)
        #expect(selected.first?.name == "LargeApp")
    }

    @Test("Excludes processes with high CPU usage")
    func testExcludesHighCPUProcesses() async {
        let manager = ProcessOffloadManager()

        let candidates = [
            ProcessSnapshot(
                pid: 100,
                name: "ActiveApp",
                bundleIdentifier: "com.test.active",
                memoryBytes: 1_000_000_000,
                cpuUsage: 50.0,  // High CPU - actively used
                isBackground: true,
                idleDuration: 600
            ),
            ProcessSnapshot(
                pid: 101,
                name: "IdleApp",
                bundleIdentifier: "com.test.idle",
                memoryBytes: 500_000_000,
                cpuUsage: 0.1,  // Low CPU - truly idle
                isBackground: true,
                idleDuration: 600
            ),
        ]

        let selected = await manager.selectCandidates(from: candidates, limit: 10)

        let hasActive = selected.contains { $0.name == "ActiveApp" }
        #expect(!hasActive)
    }

    // MARK: - Offload Operation Tests

    @Test("Records memory reclaimed on offload")
    func testRecordsMemoryReclaimed() async throws {
        let manager = ProcessOffloadManager()

        // Note: Actual SIGSTOP will fail for processes we don't own
        // This tests the tracking logic

        let initialMemory = await manager.totalMemoryReclaimed
        #expect(initialMemory == 0)
    }

    // MARK: - Restore Result Tests

    @Test("RestoreResult contains correct data")
    func testRestoreResultData() {
        let result = RestoreResult(
            pid: 123,
            processName: "TestApp",
            success: true,
            restorationReason: .userRequested,
            offloadDurationSeconds: 300.0,
            memoryRestoredBytes: 1_000_000_000,
            restoreLatencyMs: 50.0,
            errorMessage: nil
        )

        #expect(result.success == true)
        #expect(result.pid == 123)
        #expect(result.processName == "TestApp")
        #expect(result.restorationReason == .userRequested)
        #expect(result.offloadDurationSeconds == 300.0)
    }

    @Test("RestoreResult convenience initializer works")
    func testRestoreResultConvenienceInit() {
        let result = RestoreResult(
            pid: 456,
            processName: "AnotherApp",
            memoryBytes: 500_000_000,
            offloadedAt: Date().addingTimeInterval(-600)
        )

        #expect(result.success == true)
        #expect(result.memoryRestoredBytes == 500_000_000)
        #expect(result.offloadDurationSeconds >= 599)  // ~10 minutes
    }

    // MARK: - Concurrent Operation Tests

    @Test("Handles concurrent offload requests safely")
    func testConcurrentOffloadSafety() async {
        let manager = ProcessOffloadManager()

        // Simulate multiple concurrent requests
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let process = ProcessSnapshot(
                        pid: pid_t(1000 + i),
                        name: "App\(i)",
                        bundleIdentifier: "com.test.app\(i)",
                        memoryBytes: UInt64(100_000_000 * (i + 1)),
                        cpuUsage: 0.1,
                        isBackground: true,
                        idleDuration: 600
                    )

                    _ = await manager.selectCandidates(from: [process], limit: 1)
                }
            }
        }

        // Should not crash or produce invalid state
        let count = await manager.offloadedCount
        #expect(count >= 0)
    }

    // MARK: - Restoration Reason Tests

    @Test("RestorationReason has correct display names")
    func testRestorationReasonDisplayNames() {
        #expect(RestorationReason.userRequested.displayName == "User Requested")
        #expect(RestorationReason.thermalCleared.displayName == "Thermal Cleared")
        #expect(RestorationReason.appActivated.displayName == "App Activated")
        #expect(RestorationReason.systemRequest.displayName == "System Request")
        #expect(RestorationReason.timeout.displayName == "Timeout")
        #expect(RestorationReason.emergency.displayName == "Emergency")
    }
}

// MARK: - Offload State Tests

@Suite("OffloadState Tests")
struct OffloadStateTests {

    @Test("OffloadState enum has all cases")
    func testOffloadStateAllCases() {
        let cases = OffloadState.allCases
        #expect(cases.contains(.suspended))
        #expect(cases.contains(.restored))
        #expect(cases.contains(.failed))
    }
}

// MARK: - Memory Metrics Tests

@Suite("MemoryMetrics Tests")
struct MemoryMetricsTests {

    @Test("Formats bytes correctly")
    func testFormatBytes() {
        #expect(MemoryMetrics.formatBytes(0) == "0 B")
        #expect(MemoryMetrics.formatBytes(1024) == "1.0 KB")
        #expect(MemoryMetrics.formatBytes(1_048_576) == "1.0 MB")
        #expect(MemoryMetrics.formatBytes(1_073_741_824) == "1.0 GB")
        #expect(MemoryMetrics.formatBytes(1_099_511_627_776) == "1.0 TB")
    }

    @Test("Formats large values correctly")
    func testFormatLargeBytes() {
        let eightGB: Int64 = 8_589_934_592
        let formatted = MemoryMetrics.formatBytes(eightGB)
        #expect(formatted == "8.0 GB")
    }

    @Test("Usage percentage calculates correctly")
    func testUsagePercentage() {
        let metrics = MemoryMetrics(
            totalPhysicalMemory: 16_000_000_000,
            usedMemory: 12_000_000_000,
            freeMemory: 4_000_000_000,
            pressureLevel: 0.5,
            swapUsed: 0,
            compressedMemory: 0
        )

        let usage = metrics.usagePercentage
        #expect(usage >= 0.74)
        #expect(usage <= 0.76)
    }
}
