//
//  XPCServiceProtocol.swift
//  SentinelHealth
//
//  XPC protocol for communication between main app and privileged helper.
//

import Foundation
import OSLog

// MARK: - XPC Service Protocol Version

/// Protocol version for future compatibility
public let XPCServiceProtocolVersion: UInt = 1

// MARK: - XPC Service Protocol

/// Protocol defining the interface between main app and privileged helper
@objc public protocol SentinelHelperProtocol: NSObjectProtocol {

    /// Suspend a process by PID
    /// - Parameters:
    ///   - pid: Process ID to suspend
    ///   - reply: Callback with success status and optional error message
    func suspendProcess(
        _ pid: pid_t,
        reply: @escaping (_ success: Bool, _ errorMessage: String?) -> Void
    )

    /// Resume a suspended process by PID
    /// - Parameters:
    ///   - pid: Process ID to resume
    ///   - reply: Callback with success status and optional error message
    func resumeProcess(
        _ pid: pid_t,
        reply: @escaping (_ success: Bool, _ errorMessage: String?) -> Void
    )

    /// Validate that a process is safe to suspend
    /// - Parameters:
    ///   - pid: Process ID to validate
    ///   - reply: Callback with validation result and reason if invalid
    func validateProcess(
        _ pid: pid_t,
        reply: @escaping (_ isValid: Bool, _ reason: String?) -> Void
    )

    /// Check if the helper is alive and operational
    /// - Parameter reply: Callback with helper status
    func checkStatus(
        reply: @escaping (_ isOperational: Bool, _ version: UInt, _ uptime: TimeInterval) -> Void
    )

    /// Get the list of currently suspended processes managed by the helper
    /// - Parameter reply: Callback with array of suspended PIDs
    func getSuspendedProcesses(
        reply: @escaping (_ pids: [pid_t]) -> Void
    )

    /// Force resume all suspended processes (emergency recovery)
    /// - Parameter reply: Callback with count of processes resumed
    func emergencyResumeAll(
        reply: @escaping (_ resumedCount: Int, _ errorMessage: String?) -> Void
    )
}

// MARK: - XPC Client Protocol

/// Protocol for callbacks from helper to main app
@objc public protocol SentinelClientProtocol: NSObjectProtocol {

    /// Called when a process state changes unexpectedly
    /// - Parameters:
    ///   - pid: Process ID that changed
    ///   - newState: New state description
    func processStateDidChange(
        _ pid: pid_t,
        newState: String
    )

    /// Called when an error occurs in the helper
    /// - Parameters:
    ///   - code: Error code
    ///   - message: Error message
    func helperDidEncounterError(
        code: Int,
        message: String
    )
}

// MARK: - XPC Connection Manager

/// Manager for XPC connection to privileged helper
public actor XPCConnectionManager {

    // MARK: - Properties

    private let logger = SentinelLogger.helper
    private var connection: NSXPCConnection?
    private var isConnected = false

    /// Mach service name for the helper
    public static let helperMachServiceName = "com.sentinel.health.helper"

    // MARK: - Singleton

    public static let shared = XPCConnectionManager()

    private init() {}

    // MARK: - Connection Management

    /// Establish connection to the privileged helper
    public func connect() throws {
        guard connection == nil else { return }

        let newConnection = NSXPCConnection(
            machServiceName: Self.helperMachServiceName,
            options: .privileged
        )

        // Set up the remote object interface
        newConnection.remoteObjectInterface = NSXPCInterface(with: SentinelHelperProtocol.self)

        // Set up the exported object interface for callbacks
        newConnection.exportedInterface = NSXPCInterface(with: SentinelClientProtocol.self)
        newConnection.exportedObject = XPCClientHandler()

        // Handle interruption - keep state tracking simple
        newConnection.interruptionHandler = {
            // Note: Can't access actor state here, just log
            Logger(subsystem: "com.sentinel.health", category: "XPC")
                .warning("XPC connection interrupted")
        }

        // Handle invalidation
        newConnection.invalidationHandler = {
            Logger(subsystem: "com.sentinel.health", category: "XPC")
                .warning("XPC connection invalidated")
        }

        newConnection.resume()
        connection = newConnection
        isConnected = true
        logger.info("XPC connection established to helper")
    }

    /// Disconnect from the privileged helper
    public func disconnect() {
        connection?.invalidate()
        connection = nil
        isConnected = false
        logger.info("XPC connection disconnected")
    }

    /// Get the remote proxy object
    public func getHelper() throws -> SentinelHelperProtocol {
        guard let connection = connection else {
            throw SentinelError.permissionDenied(operation: "XPC connection - helper not installed")
        }

        guard
            let helper = connection.remoteObjectProxyWithErrorHandler({ error in
                Logger(subsystem: "com.sentinel.health", category: "XPC")
                    .error("XPC remote error: \(error.localizedDescription)")
            }) as? SentinelHelperProtocol
        else {
            throw SentinelError.permissionDenied(
                operation: "XPC connection - failed to get helper proxy")
        }

        return helper
    }

    // MARK: - Error Handling

    private func handleInterruption() {
        logger.warning("XPC connection interrupted, will attempt reconnection")
        isConnected = false
    }

    private func handleInvalidation() {
        logger.warning("XPC connection invalidated")
        connection = nil
        isConnected = false
    }

    private func handleRemoteError(_ error: Error) {
        logger.error("XPC remote error: \(error.localizedDescription)")
    }

    // MARK: - Status

    /// Check if helper is installed and reachable
    public func isHelperInstalled() async -> Bool {
        guard let connection = connection else { return false }

        return await withCheckedContinuation { continuation in
            guard
                let helper = connection.remoteObjectProxyWithErrorHandler({ _ in
                    continuation.resume(returning: false)
                }) as? SentinelHelperProtocol
            else {
                continuation.resume(returning: false)
                return
            }

            helper.checkStatus { isOperational, _, _ in
                continuation.resume(returning: isOperational)
            }
        }
    }
}

// MARK: - XPC Client Handler

/// Handles callbacks from the helper
final class XPCClientHandler: NSObject, SentinelClientProtocol {

    private let logger = SentinelLogger.helper

    func processStateDidChange(_ pid: pid_t, newState: String) {
        logger.info("Process \(pid) state changed to: \(newState)")
        // Notify the ProcessOffloadManager about the state change
    }

    func helperDidEncounterError(code: Int, message: String) {
        logger.error("Helper error [\(code)]: \(message)")
        // Handle error appropriately
    }
}

// MARK: - Helper Installation

/// Utilities for installing the privileged helper
public enum HelperInstallation {

    private static let logger = SentinelLogger.helper

    /// Check if the helper needs to be installed or updated
    public static func needsInstallation() async -> Bool {
        let isInstalled = await XPCConnectionManager.shared.isHelperInstalled()
        return !isInstalled
    }

    /// Request installation of the privileged helper
    /// - Parameter completion: Callback with success status
    public static func requestInstallation(completion: @escaping (Bool, Error?) -> Void) {
        // This would use Authorization Services to request admin privileges
        // and install the helper using SMJobBless or launchd

        logger.info("Requesting helper installation")

        // Placeholder for actual implementation
        // In production, this would:
        // 1. Create an AuthorizationRef
        // 2. Request admin rights
        // 3. Use SMJobBless to install the helper
        // 4. Verify installation

        completion(
            false, SentinelError.helperInstallationFailed(reason: "Manual installation required"))
    }

    /// Remove the privileged helper
    public static func removeHelper(completion: @escaping (Bool, Error?) -> Void) {
        logger.info("Requesting helper removal")

        // Placeholder for uninstallation
        completion(false, nil)
    }
}

// MARK: - SentinelError Extension

extension SentinelError {
    /// XPC connection failed
    static func xpcConnectionFailed(reason: String) -> SentinelError {
        .permissionDenied(operation: "XPC connection: \(reason)")
    }

    /// Helper installation failed
    static func helperInstallationFailed(reason: String) -> SentinelError {
        .permissionDenied(operation: "Helper installation: \(reason)")
    }
}
