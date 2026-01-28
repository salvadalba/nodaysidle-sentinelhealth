//
//  SharedTypes.swift
//  SentinelHealth
//
//  Shared types used across multiple files.
//

import Foundation

// MARK: - Offloaded Process Info

/// Lightweight Sendable struct for displaying offloaded process info in UI.
public struct OffloadedProcessInfo: Sendable, Identifiable {
    public var id: pid_t { pid }

    public let pid: pid_t
    public let name: String
    public let memorySaved: UInt64
    public let duration: TimeInterval
    public let offloadedAt: Date

    public init(pid: pid_t, name: String, memorySaved: UInt64, offloadedAt: Date) {
        self.pid = pid
        self.name = name
        self.memorySaved = memorySaved
        self.offloadedAt = offloadedAt
        self.duration = Date().timeIntervalSince(offloadedAt)
    }
}
