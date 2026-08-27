//===----------------------------------------------------------------------===//
//
// This source file is part of the SMLocalPersistence package open source project
//
// Copyright (c) 2025-2035 Maxim Bazarov and the SMLocalPersistence package
// open source project authors
// Licensed under MIT
//
// See LICENSE for license information
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

import Foundation
import OSLog
import Security
import StateManagement

private let isolatedLog = Logger(subsystem: "SMLocalPersistence", category: "IsolatedPersistence")

/// Test and preview overlay of Persistence identity. Owns the Environments it creates.
///
/// Construct, then `defer { clear() }`. Overlay exists before first `onRead`. Locators stay private.
///
/// DEBUG SwiftUI: `.sharedEnvironment(.isolatedPersistence)` and `.seedEnvironment(.isolatedPersistence) { }`
/// construct IsolatedPersistence per View identity. `.sharedEnvironment(iso)` retains a handle you own.
@MainActor
public final class IsolatedPersistence {
    public let environment: SharedEnvironment

    private var additional: [SharedEnvironment] = []
    private let suiteName: String
    private let keychainService: String
    private let jsonRoot: URL
    private let defaults: UserDefaults

    public init() {
        let uuid = UUID().uuidString
        let locator = "smlp.\(uuid)"
        guard let defaults = UserDefaults(suiteName: locator) else {
            preconditionFailure("IsolatedPersistence UserDefaults suite failed")
        }
        defaults.removePersistentDomain(forName: locator)
        suiteName = locator
        keychainService = locator
        let jsonRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("smlp-\(uuid)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: jsonRoot, withIntermediateDirectories: true)
        } catch {
            preconditionFailure("IsolatedPersistence JSON root failed")
        }
        self.jsonRoot = jsonRoot
        self.defaults = defaults
        environment = SharedEnvironment()
        PersistenceOverlay.register(
            environmentID: ObjectIdentifier(environment),
            environment: environment,
            handle: self,
            defaults: defaults,
            keychainService: locator,
            jsonRoot: jsonRoot
        )
    }

    /// A second Environment with the same Persistence identity. Assert persist-out here after notify.
    public func additionalEnvironment() -> SharedEnvironment {
        let env = SharedEnvironment()
        additional.append(env)
        PersistenceOverlay.register(
            environmentID: ObjectIdentifier(env),
            environment: env,
            handle: self,
            defaults: defaults,
            keychainService: keychainService,
            jsonRoot: jsonRoot
        )
        return env
    }

    /// Deletes the UUID UserDefaults suite, Keychain items, and JSON tree IsolatedPersistence allocated.
    public func clear() {
        defaults.removePersistentDomain(forName: suiteName)
        deleteKeychainItems(service: keychainService)
        deleteJSONFileTree(root: jsonRoot)
    }

    /// Callers assert persist-out with `additionalEnvironment()` after this returns. Creating that Environment before the write lands persists the seed.
    func waitForPersistOut(key: String) async throws {
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if defaults.data(forKey: key) != nil {
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        throw PersistOutTimeout(key: key)
    }

    /// Callers assert removal with `additionalEnvironment()` after this returns.
    func waitForRemoval(key: String) async throws {
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if defaults.data(forKey: key) == nil {
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        throw PersistOutTimeout(key: key)
    }

    /// PersistUserDefaults only encodes Codable. Corrupt-load tests need raw bytes.
    func plant(_ data: Data, forKey key: String) {
        defaults.set(data, forKey: key)
    }

    /// Callers assert persist-out with `additionalEnvironment()` after this returns.
    func waitForKeychainPersistOut(account: String) async throws {
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if try copyKeychainData(identity: isolatedKeychainIdentity, account: account) != nil {
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        throw PersistOutTimeout(key: account)
    }

    /// Callers assert removal with `additionalEnvironment()` after this returns.
    func waitForKeychainRemoval(account: String) async throws {
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if try copyKeychainData(identity: isolatedKeychainIdentity, account: account) == nil {
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        throw PersistOutTimeout(key: account)
    }

    /// PersistKeychain only encodes Codable. Corrupt-load tests need raw bytes.
    func plantKeychain(_ data: Data, account: String) throws {
        try upsertKeychainData(identity: isolatedKeychainIdentity, account: account, data: data)
    }

    /// Callers assert persist-out with `additionalEnvironment()` after this returns.
    func waitForJSONPersistOut(location: JSONFileLocation) async throws {
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: jsonFileURL(root: jsonRoot, location: location).path) {
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        throw PersistOutTimeout(key: location.file)
    }

    /// Callers assert removal with `additionalEnvironment()` after this returns.
    func waitForJSONRemoval(location: JSONFileLocation) async throws {
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if !FileManager.default.fileExists(atPath: jsonFileURL(root: jsonRoot, location: location).path) {
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        throw PersistOutTimeout(key: location.file)
    }

    /// PersistJSONFile only encodes Codable. Corrupt-load tests need raw bytes.
    func plantJSON(_ data: Data, location: JSONFileLocation) throws {
        try writeJSONFileData(root: jsonRoot, location: location, data: data)
    }

    func jsonFileData(location: JSONFileLocation) -> Data? {
        do {
            return try copyJSONFileData(root: jsonRoot, location: location)
        } catch {
            isolatedLog.error("IsolatedPersistence JSON copy failed: \(error.localizedDescription)")
            return nil
        }
    }

    private var isolatedKeychainIdentity: KeychainIdentity {
        KeychainIdentity(
            service: keychainService,
            accessibility: kSecAttrAccessibleAfterFirstUnlock as String,
            accessGroup: nil,
            synchronizable: false
        )
    }

    deinit {
        let name = suiteName
        let service = keychainService
        let root = jsonRoot
        UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
        deleteKeychainItems(service: service)
        deleteJSONFileTree(root: root)
    }

    #if DEBUG
    /// Applies the Seed batch to ``environment`` in one notify. Forwards to ``SharedEnvironment/seed(_:)``.
    public func seed(
        @SeedOperationsBuilder _ operations: () -> [any SyncOperation]
    ) {
        environment.seed(operations)
    }
    #endif
}

struct PersistOutTimeout: Error {
    let key: String
}

#if DEBUG
/// Token for DEBUG `.sharedEnvironment(.isolatedPersistence)` and `.seedEnvironment(.isolatedPersistence) { }`.
/// The modifier holds IsolatedPersistence per View identity.
public enum IsolatedPersistenceToken: Sendable {
    case isolatedPersistence
}
#endif

@MainActor
final class PersistenceOverlayBox {
    let environmentID: ObjectIdentifier
    weak var environment: SharedEnvironment?
    weak var handle: IsolatedPersistence?
    let defaults: UserDefaults
    let keychainService: String
    let jsonRoot: URL

    init(
        environmentID: ObjectIdentifier,
        environment: SharedEnvironment,
        handle: IsolatedPersistence,
        defaults: UserDefaults,
        keychainService: String,
        jsonRoot: URL
    ) {
        self.environmentID = environmentID
        self.environment = environment
        self.handle = handle
        self.defaults = defaults
        self.keychainService = keychainService
        self.jsonRoot = jsonRoot
    }
}

@MainActor
enum PersistenceOverlay {
    static var boxes: [PersistenceOverlayBox] = []

    static func register(
        environmentID: ObjectIdentifier,
        environment: SharedEnvironment,
        handle: IsolatedPersistence,
        defaults: UserDefaults,
        keychainService: String,
        jsonRoot: URL
    ) {
        prune()
        boxes.append(
            PersistenceOverlayBox(
                environmentID: environmentID,
                environment: environment,
                handle: handle,
                defaults: defaults,
                keychainService: keychainService,
                jsonRoot: jsonRoot
            )
        )
    }

    static func userDefaults(
        policy: UserDefaultsPolicy,
        environmentID: ObjectIdentifier
    ) -> UserDefaults {
        prune()
        if let box = boxes.first(where: { $0.environmentID == environmentID }) {
            guard box.handle != nil else {
                leftoverOnReadTrap()
            }
            return box.defaults
        }
        return policy.makeUserDefaults()
    }

    static func keychain(
        policy: KeychainPolicy,
        environmentID: ObjectIdentifier
    ) -> KeychainIdentity {
        prune()
        if let box = boxes.first(where: { $0.environmentID == environmentID }) {
            guard box.handle != nil else {
                leftoverOnReadTrap()
            }
            return KeychainIdentity(
                service: box.keychainService,
                accessibility: policy.accessibility,
                accessGroup: nil,
                synchronizable: false
            )
        }
        return KeychainIdentity(
            service: policy.service,
            accessibility: policy.accessibility,
            accessGroup: policy.accessGroup,
            synchronizable: policy.synchronizable
        )
    }

    static func jsonRoot(
        policy: JSONFilePolicy,
        environmentID: ObjectIdentifier
    ) -> URL {
        prune()
        if let box = boxes.first(where: { $0.environmentID == environmentID }) {
            guard box.handle != nil else {
                leftoverOnReadTrap()
            }
            return box.jsonRoot
        }
        return policy.root
    }

    private static func leftoverOnReadTrap() -> Never {
        preconditionFailure(
            "IsolatedPersistence is gone; leftover onRead cannot use production Persistence identity"
        )
    }

    private static func prune() {
        boxes.removeAll { $0.environment == nil && $0.handle == nil }
    }
}
