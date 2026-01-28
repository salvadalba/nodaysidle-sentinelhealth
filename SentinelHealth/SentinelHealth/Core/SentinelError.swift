//
//  SentinelError.swift
//  SentinelHealth
//
//  Core error handling with typed throws for Swift 6 concurrency safety.
//

import Foundation

/// Recovery suggestions for error cases
public enum RecoverySuggestion: String, Sendable {
    case downloadModel = "The CoreML model needs to be downloaded. Please check your installation."
    case grantPermissions = "Sentinel Health requires additional permissions to monitor processes."
    case retryOperation = "Please try the operation again."
    case restartApp = "Please restart Sentinel Health."
    case contactSupport = "If this issue persists, please contact support."
    case checkDiskSpace = "Please ensure you have sufficient disk space available."
    case updateMacOS = "Please ensure you are running macOS 15 or later."
}

/// Core error enum for Sentinel Health with typed throws support.
/// Conforms to LocalizedError for user-friendly messages and Sendable for concurrency safety.
public enum SentinelError: Error, LocalizedError, Sendable {

    // MARK: - Model Errors

    /// CoreML model failed to load
    case modelNotLoaded(recoverySuggestion: RecoverySuggestion = .downloadModel)

    /// CoreML inference failed
    case inferenceFailure(reason: String)

    // MARK: - Process Errors

    /// Target process could not be found
    case processNotFound(pid: Int32)

    /// Permission denied for process operation
    case permissionDenied(operation: String)

    /// Process suspension failed
    case offloadFailed(processName: String, reason: String)

    /// Process restoration failed
    case restoreFailed(processName: String, reason: String)

    /// Process is not safe to suspend (system-critical)
    case unsafeProcess(processName: String)

    // MARK: - Thermal Errors

    /// Thermal sensor data unavailable
    case thermalDataUnavailable

    /// Memory metrics collection failed
    case memoryMetricsUnavailable(reason: String)

    // MARK: - Persistence Errors

    /// SwiftData operation failed
    case persistenceError(operation: String, underlyingError: String)

    /// CloudKit sync failed
    case syncError(reason: String)

    // MARK: - Configuration Errors

    /// Invalid configuration value
    case invalidConfiguration(key: String, value: String)

    /// Required entitlement missing
    case entitlementMissing(entitlement: String)

    // MARK: - LocalizedError Conformance

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Thermal Intelligence model could not be loaded"
        case .inferenceFailure(let reason):
            return "Prediction failed: \(reason)"
        case .processNotFound(let pid):
            return "Process with ID \(pid) not found"
        case .permissionDenied(let operation):
            return "Permission denied for \(operation)"
        case .offloadFailed(let processName, let reason):
            return "Failed to offload \(processName): \(reason)"
        case .restoreFailed(let processName, let reason):
            return "Failed to restore \(processName): \(reason)"
        case .unsafeProcess(let processName):
            return "\(processName) is a system-critical process and cannot be suspended"
        case .thermalDataUnavailable:
            return "Thermal sensor data is currently unavailable"
        case .memoryMetricsUnavailable(let reason):
            return "Memory metrics unavailable: \(reason)"
        case .persistenceError(let operation, let underlyingError):
            return "Data \(operation) failed: \(underlyingError)"
        case .syncError(let reason):
            return "CloudKit sync failed: \(reason)"
        case .invalidConfiguration(let key, let value):
            return "Invalid configuration: \(key) = \(value)"
        case .entitlementMissing(let entitlement):
            return "Required entitlement missing: \(entitlement)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .modelNotLoaded(let suggestion):
            return suggestion.rawValue
        case .inferenceFailure:
            return RecoverySuggestion.retryOperation.rawValue
        case .processNotFound:
            return "The process may have already terminated."
        case .permissionDenied:
            return RecoverySuggestion.grantPermissions.rawValue
        case .offloadFailed:
            return RecoverySuggestion.retryOperation.rawValue
        case .restoreFailed:
            return RecoverySuggestion.restartApp.rawValue
        case .unsafeProcess:
            return "This process is protected and cannot be managed by Sentinel Health."
        case .thermalDataUnavailable:
            return RecoverySuggestion.updateMacOS.rawValue
        case .memoryMetricsUnavailable:
            return RecoverySuggestion.retryOperation.rawValue
        case .persistenceError:
            return RecoverySuggestion.checkDiskSpace.rawValue
        case .syncError:
            return "Please check your internet connection and iCloud settings."
        case .invalidConfiguration:
            return "Please reset to default settings."
        case .entitlementMissing:
            return RecoverySuggestion.contactSupport.rawValue
        }
    }

    public var failureReason: String? {
        switch self {
        case .modelNotLoaded:
            return "The CoreML model file is missing or corrupted."
        case .inferenceFailure(let reason):
            return reason
        case .processNotFound:
            return "The target process is not running."
        case .permissionDenied(let operation):
            return "Insufficient privileges for \(operation)."
        case .offloadFailed(_, let reason):
            return reason
        case .restoreFailed(_, let reason):
            return reason
        case .unsafeProcess:
            return "System integrity requires this process to remain active."
        case .thermalDataUnavailable:
            return "Thermal sensors may not be accessible on this hardware."
        case .memoryMetricsUnavailable(let reason):
            return reason
        case .persistenceError(_, let underlyingError):
            return underlyingError
        case .syncError(let reason):
            return reason
        case .invalidConfiguration(_, let value):
            return "'\(value)' is not a valid value."
        case .entitlementMissing(let entitlement):
            return "The \(entitlement) entitlement was not found."
        }
    }
}

// MARK: - Typed Throws Helpers

/// Result type alias for operations that can throw SentinelError
public typealias SentinelResult<T> = Result<T, SentinelError>

/// Extension to easily convert throwing functions to Result
extension SentinelError {
    /// Wraps a throwing closure into a Result
    public static func catching<T>(_ body: () throws -> T) -> SentinelResult<T> {
        do {
            return .success(try body())
        } catch let error as SentinelError {
            return .failure(error)
        } catch {
            return .failure(
                .persistenceError(operation: "unknown", underlyingError: error.localizedDescription)
            )
        }
    }

    /// Wraps an async throwing closure into a Result
    public static func catchingAsync<T>(_ body: () async throws -> T) async -> SentinelResult<T> {
        do {
            return .success(try await body())
        } catch let error as SentinelError {
            return .failure(error)
        } catch {
            return .failure(
                .persistenceError(operation: "unknown", underlyingError: error.localizedDescription)
            )
        }
    }
}
