//
//  DataStore.swift
//  SentinelHealth
//
//  SwiftData ModelContainer configuration and data store management.
//

import Foundation
import OSLog
import SwiftData

// MARK: - Data Store Configuration

/// Configuration options for the data store
public struct DataStoreConfiguration: Sendable {
    /// Whether to use in-memory storage (for testing)
    public var isInMemory: Bool

    /// Whether CloudKit sync is enabled
    public var cloudKitEnabled: Bool

    /// CloudKit container identifier
    public var cloudKitContainerIdentifier: String?

    /// Whether to enable auto-save
    public var autoSaveEnabled: Bool

    public init(
        isInMemory: Bool = false,
        cloudKitEnabled: Bool = false,
        cloudKitContainerIdentifier: String? = nil,
        autoSaveEnabled: Bool = true
    ) {
        self.isInMemory = isInMemory
        self.cloudKitEnabled = cloudKitEnabled
        self.cloudKitContainerIdentifier = cloudKitContainerIdentifier
        self.autoSaveEnabled = autoSaveEnabled
    }

    /// Default configuration for production
    public static var production: DataStoreConfiguration {
        DataStoreConfiguration(
            isInMemory: false,
            cloudKitEnabled: false,
            autoSaveEnabled: true
        )
    }

    /// Configuration for testing
    public static var testing: DataStoreConfiguration {
        DataStoreConfiguration(
            isInMemory: true,
            cloudKitEnabled: false,
            autoSaveEnabled: false
        )
    }

    /// Configuration with CloudKit sync
    public static func withCloudKit(containerID: String) -> DataStoreConfiguration {
        DataStoreConfiguration(
            isInMemory: false,
            cloudKitEnabled: true,
            cloudKitContainerIdentifier: containerID,
            autoSaveEnabled: true
        )
    }
}

// MARK: - Data Store Manager

/// Manages SwiftData ModelContainer creation and configuration.
public enum DataStore {

    private static let logger = SentinelLogger.persistence

    /// Schema containing all Sentinel Health models
    public static let schema = Schema([
        OffloadedProcess.self,
        ThermalEvent.self,
        PerformanceSnapshot.self,
    ])

    /// Create a ModelContainer with the specified configuration.
    /// - Parameter configuration: Data store configuration options
    /// - Returns: Configured ModelContainer
    /// - Throws: SentinelError if container creation fails
    public static func createContainer(
        configuration: DataStoreConfiguration = .production
    ) throws -> ModelContainer {
        logger.info(
            "Creating ModelContainer (inMemory: \(configuration.isInMemory), cloudKit: \(configuration.cloudKitEnabled))"
        )

        do {
            let modelConfiguration: ModelConfiguration

            if configuration.isInMemory {
                modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
            } else if configuration.cloudKitEnabled,
                let containerID = configuration.cloudKitContainerIdentifier
            {
                modelConfiguration = ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .private(containerID)
                )
            } else {
                modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false
                )
            }

            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            logger.info("ModelContainer created successfully")
            return container

        } catch {
            logger.error("Failed to create ModelContainer: \(error.localizedDescription)")
            throw SentinelError.persistenceError(
                operation: "createContainer",
                underlyingError: error.localizedDescription
            )
        }
    }

    /// Create an in-memory container for testing.
    /// - Returns: In-memory ModelContainer
    public static func createTestContainer() throws -> ModelContainer {
        try createContainer(configuration: .testing)
    }
}

// MARK: - Model Context Extension

extension ModelContext {

    /// Save changes with error transformation
    public func saveWithErrorHandling() throws {
        do {
            try save()
        } catch {
            throw SentinelError.persistenceError(
                operation: "save",
                underlyingError: error.localizedDescription
            )
        }
    }

    /// Delete all instances of a model type
    public func deleteAll<T: PersistentModel>(_ modelType: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let instances = try fetch(descriptor)

        for instance in instances {
            delete(instance)
        }

        try saveWithErrorHandling()
    }
}

// MARK: - Schema Version

/// Schema version for migration tracking
public enum SentinelSchemaVersion: Int, Sendable {
    case v1 = 1

    public static var current: SentinelSchemaVersion { .v1 }
}
