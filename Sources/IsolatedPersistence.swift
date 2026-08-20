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
import Security
import StateManagement

/// Test and preview overlay of Persistence identity. Owns the Environments it creates.
///
/// Construct, then `defer { clear() }`. Overlay exists before first `provide`. Locators stay private.
@MainActor
public final class IsolatedPersistence {
    public let environment: SharedEnvironment

    private var additional: [SharedEnvironment] = []
    private let suiteName: String
    private let keychainService: String
    private let defaults: UserDefaults

    public init() {
        let locator = "smlp.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: locator) else {
            preconditionFailure("IsolatedPersistence UserDefaults suite failed")
        }
        defaults.removePersistentDomain(forName: locator)
        suiteName = locator
        keychainService = locator
        self.defaults = defaults
        environment = SharedEnvironment()
        PersistenceOverlay.register(
            environmentID: ObjectIdentifier(environment),
            environment: environment,
            handle: self,
            defaults: defaults,
            keychainService: locator
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
            keychainService: keychainService
        )
        return env
    }

    /// Deletes the UUID UserDefaults suite and Keychain items IsolatedPersistence allocated.
    public func clear() {
        defaults.removePersistentDomain(forName: suiteName)
        deleteKeychainItems(service: keychainService)
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
        UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
        deleteKeychainItems(service: service)
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
/// Token for `.sharedEnvironment(.isolatedPersistence)`. The modifier holds IsolatedPersistence per View identity.
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

    init(
        environmentID: ObjectIdentifier,
        environment: SharedEnvironment,
        handle: IsolatedPersistence,
        defaults: UserDefaults,
        keychainService: String
    ) {
        self.environmentID = environmentID
        self.environment = environment
        self.handle = handle
        self.defaults = defaults
        self.keychainService = keychainService
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
        keychainService: String
    ) {
        prune()
        boxes.append(
            PersistenceOverlayBox(
                environmentID: environmentID,
                environment: environment,
                handle: handle,
                defaults: defaults,
                keychainService: keychainService
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
                leftoverProvideTrap()
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
                leftoverProvideTrap()
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

    private static func leftoverProvideTrap() -> Never {
        preconditionFailure(
            "IsolatedPersistence is gone; leftover provide cannot use production Persistence identity"
        )
    }

    private static func prune() {
        boxes.removeAll { $0.environment == nil && $0.handle == nil }
    }
}
