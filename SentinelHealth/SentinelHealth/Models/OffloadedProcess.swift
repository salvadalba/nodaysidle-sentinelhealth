//
//  OffloadedProcess.swift
//  SentinelHealth
//
//  SwiftData model for persisting offloaded process state.
//  Also includes Sendable DTO for cross-actor communication.
//

import Foundation
import SwiftData

// MARK: - Offloaded Process DTO (Sendable)

/// Sendable data transfer object for offloaded process state.
/// Use this for passing data across actor boundaries instead of SwiftData models.
public struct OffloadedProcessDTO: Sendable, Equatable, Identifiable {

    // MARK: - Identifiers

    /// Unique identifier for this offload record
    public let id: UUID

    /// Process ID at time of offload
    public let pid: Int32

    /// Process name (executable name)
    public let processName: String

    /// Bundle identifier (if available)
    public let bundleIdentifier: String?

    // MARK: - State Information

    /// Memory footprint at time of offload (bytes)
    public let memoryBytes: Int64

    /// CPU usage at time of offload (percentage)
    public let cpuUsageAtOffload: Double

    /// Idle duration before offload (seconds)
    public let idleDurationBeforeOffload: Double

    /// Path to the executable
    public let executablePath: String?

    // MARK: - Timestamps

    /// When the process was offloaded
    public let offloadedAt: Date

    /// When the process was restored (nil if still offloaded)
    public var restoredAt: Date?

    /// Duration of offload in seconds (computed)
    public var offloadDuration: TimeInterval {
        guard let restored = restoredAt else {
            return Date().timeIntervalSince(offloadedAt)
        }
        return restored.timeIntervalSince(offloadedAt)
    }

    // MARK: - Status

    /// Current status of the offloaded process
    public var status: OffloadStatus

    /// Reason for restoration (if restored)
    public var restorationReason: RestorationReason?

    /// Error message if offload/restore failed
    public var errorMessage: String?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        pid: Int32,
        processName: String,
        bundleIdentifier: String? = nil,
        memoryBytes: Int64,
        cpuUsageAtOffload: Double = 0,
        idleDurationBeforeOffload: Double = 0,
        executablePath: String? = nil,
        offloadedAt: Date = Date(),
        restoredAt: Date? = nil,
        status: OffloadStatus = .suspended,
        restorationReason: RestorationReason? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.pid = pid
        self.processName = processName
        self.bundleIdentifier = bundleIdentifier
        self.memoryBytes = memoryBytes
        self.cpuUsageAtOffload = cpuUsageAtOffload
        self.idleDurationBeforeOffload = idleDurationBeforeOffload
        self.executablePath = executablePath
        self.offloadedAt = offloadedAt
        self.restoredAt = restoredAt
        self.status = status
        self.restorationReason = restorationReason
        self.errorMessage = errorMessage
    }

    // MARK: - Mutation Helpers (returns new instance)

    /// Return a copy marked as restored
    public func markedRestored(reason: RestorationReason) -> OffloadedProcessDTO {
        var copy = self
        copy.restoredAt = Date()
        copy.status = .restored
        copy.restorationReason = reason
        return copy
    }

    /// Return a copy marked as failed
    public func markedFailed(error: String) -> OffloadedProcessDTO {
        var copy = self
        copy.status = .failed
        copy.errorMessage = error
        return copy
    }

    /// Return a copy marked as terminated
    public func markedTerminated() -> OffloadedProcessDTO {
        var copy = self
        copy.status = .terminated
        return copy
    }

    // MARK: - Formatting

    /// Formatted memory string
    public var formattedMemory: String {
        MemoryMetrics.formatBytes(UInt64(memoryBytes))
    }

    /// Formatted offload duration string
    public var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: offloadDuration) ?? "\(Int(offloadDuration))s"
    }
}

// MARK: - Conversion Extension

extension OffloadedProcessDTO {
    /// Create DTO from SwiftData model (call only from data store actor)
    public init(from model: OffloadedProcess) {
        self.id = model.id
        self.pid = model.pid
        self.processName = model.processName
        self.bundleIdentifier = model.bundleIdentifier
        self.memoryBytes = model.memoryBytes
        self.cpuUsageAtOffload = model.cpuUsageAtOffload
        self.idleDurationBeforeOffload = model.idleDurationBeforeOffload
        self.executablePath = model.executablePath
        self.offloadedAt = model.offloadedAt
        self.restoredAt = model.restoredAt
        self.status = model.status
        self.restorationReason = model.restorationReason
        self.errorMessage = model.errorMessage
    }
}

extension OffloadedProcess {
    /// Update SwiftData model from DTO (call only from data store actor)
    public func update(from dto: OffloadedProcessDTO) {
        self.restoredAt = dto.restoredAt
        self.status = dto.status
        self.restorationReason = dto.restorationReason
        self.errorMessage = dto.errorMessage
    }

    /// Create SwiftData model from DTO (call only from data store actor)
    public convenience init(from dto: OffloadedProcessDTO) {
        self.init(
            id: dto.id,
            pid: dto.pid,
            processName: dto.processName,
            bundleIdentifier: dto.bundleIdentifier,
            memoryBytes: dto.memoryBytes,
            cpuUsageAtOffload: dto.cpuUsageAtOffload,
            idleDurationBeforeOffload: dto.idleDurationBeforeOffload,
            executablePath: dto.executablePath,
            offloadedAt: dto.offloadedAt,
            status: dto.status
        )
        self.restoredAt = dto.restoredAt
        self.restorationReason = dto.restorationReason
        self.errorMessage = dto.errorMessage
    }
}

/// SwiftData model representing a process that has been offloaded (suspended).
@Model
public final class OffloadedProcess {

    // MARK: - Identifiers

    /// Unique identifier for this offload record
    @Attribute(.unique)
    public var id: UUID

    /// Process ID at time of offload
    public var pid: Int32

    /// Process name (executable name)
    public var processName: String

    /// Bundle identifier (if available)
    public var bundleIdentifier: String?

    // MARK: - State Information

    /// Memory footprint at time of offload (bytes)
    public var memoryBytes: Int64

    /// CPU usage at time of offload (percentage)
    public var cpuUsageAtOffload: Double

    /// Idle duration before offload (seconds)
    public var idleDurationBeforeOffload: Double

    /// Path to the executable
    public var executablePath: String?

    // MARK: - Timestamps

    /// When the process was offloaded
    public var offloadedAt: Date

    /// When the process was restored (nil if still offloaded)
    public var restoredAt: Date?

    /// Duration of offload in seconds (computed)
    public var offloadDuration: TimeInterval? {
        guard let restored = restoredAt else {
            return Date().timeIntervalSince(offloadedAt)
        }
        return restored.timeIntervalSince(offloadedAt)
    }

    // MARK: - Status

    /// Current status of the offloaded process
    public var status: OffloadStatus

    /// Reason for restoration (if restored)
    public var restorationReason: RestorationReason?

    /// Error message if offload/restore failed
    public var errorMessage: String?

    // MARK: - Relationships

    /// Parent thermal event that triggered this offload
    @Relationship(inverse: \ThermalEvent.offloadedProcesses)
    public var thermalEvent: ThermalEvent?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        pid: Int32,
        processName: String,
        bundleIdentifier: String? = nil,
        memoryBytes: Int64,
        cpuUsageAtOffload: Double = 0,
        idleDurationBeforeOffload: Double = 0,
        executablePath: String? = nil,
        offloadedAt: Date = Date(),
        status: OffloadStatus = .suspended
    ) {
        self.id = id
        self.pid = pid
        self.processName = processName
        self.bundleIdentifier = bundleIdentifier
        self.memoryBytes = memoryBytes
        self.cpuUsageAtOffload = cpuUsageAtOffload
        self.idleDurationBeforeOffload = idleDurationBeforeOffload
        self.executablePath = executablePath
        self.offloadedAt = offloadedAt
        self.status = status
    }

    // MARK: - Helper Methods

    /// Mark this process as restored
    public func markRestored(reason: RestorationReason) {
        self.restoredAt = Date()
        self.status = .restored
        self.restorationReason = reason
    }

    /// Mark this process as failed
    public func markFailed(error: String) {
        self.status = .failed
        self.errorMessage = error
    }

    /// Formatted memory string
    public var formattedMemory: String {
        MemoryMetrics.formatBytes(UInt64(memoryBytes))
    }

    /// Formatted offload duration string
    public var formattedDuration: String {
        guard let duration = offloadDuration else { return "N/A" }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "\(Int(duration))s"
    }
}

// MARK: - Offload Status Enum

/// Status of an offloaded process
public enum OffloadStatus: String, Codable, Sendable {
    /// Process is currently suspended
    case suspended

    /// Process has been restored
    case restored

    /// Process terminated while suspended
    case terminated

    /// Offload or restore operation failed
    case failed
}

// MARK: - Restoration Reason Enum

/// Reason why a process was restored
public enum RestorationReason: String, Codable, Sendable {
    /// User requested restoration
    case userRequested

    /// User switched to the suspended app
    case userActivation

    /// Thermal condition cleared
    case thermalCleared

    /// System requested restoration
    case systemRequested

    /// App shutdown
    case appShutdown

    /// Automatic restoration after timeout
    case timeout
}
