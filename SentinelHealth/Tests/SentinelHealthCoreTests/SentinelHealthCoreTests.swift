//
//  SentinelHealthCoreTests.swift
//  SentinelHealthCoreTests
//
//  Unit tests for Sentinel Health Core library.
//

import Testing

@testable import SentinelHealthCore

@Test func coreVersionExists() async throws {
    #expect(!SentinelHealthCore.version.isEmpty)
}
