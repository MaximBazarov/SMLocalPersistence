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
import Testing
import StateManagement
import StateManagementTestingSupport
@testable import SMLocalPersistence

// MARK: - Snapshots

@MainActor
extension SharedEnvironment {

    /// Snapshots a Value for an assertion, through `StateReader`.
    ///
    /// A read is public only where the caller is known, so `SharedEnvironment` has none and a
    /// Satellite does not reach the core with `@testable`. `StateReader` is the sanctioned reader
    /// because it is an `EnvironmentService`, and therefore a Restricted Environment.
    ///
    /// Deliberately not named `read`: that would shadow the core's internal one and read like
    /// public API. A fresh reader per call keeps the subscription from outliving the assertion —
    /// the receiver holds the reader weakly, so it goes quiet as soon as this returns.
    func snapshot<S: StateContainer, V>(_ keyPath: KeyPath<S, V>) -> V {
        StateReader(env: self).read(keyPath)
    }

    /// Snapshots one key of a Keyed value. Same reasoning as ``snapshot(_:)``.
    func snapshot<S: StateContainer, K: Hashable, V>(
        _ keyPath: KeyPath<S, [K: V]>,
        key: K
    ) -> V? {
        StateReader(env: self).read(keyPath, key: key)
    }
}

// MARK: - Writes

/// Writes one atomic Value. Persist-out is the strategy's `onWrite`.
struct WriteValue<Storage: StateContainer, Value>: SyncOperation {
    let path: WritableKeyPath<Storage, Value>
    let value: Value
    func perform(in env: SyncOperationEnvironment) {
        env.write(path, value: value)
    }
}

/// Writes one entry of a Keyed Value. Persist-out is the strategy's keyed `onWrite`.
struct WriteEntry<Storage: StateContainer, Key: Hashable, Value>: SyncOperation {
    let path: WritableKeyPath<Storage, [Key: Value]>
    let key: Key
    let value: Value
    func perform(in env: SyncOperationEnvironment) {
        env.write(path, key: key, value: value)
    }
}

// MARK: - Unique Persistence identity (P16)

/// A UserDefaults suite name no other test shares.
func uniqueSuiteName() -> String {
    "smlp.tests.\(UUID().uuidString)"
}

/// A Keychain service no other test shares.
func uniqueKeychainService() -> String {
    "smlp.tests.\(UUID().uuidString)"
}

extension KeychainPolicy {
    /// A test Policy through the public initializer; only the service varies per test (P16).
    static func testService(_ service: String) -> KeychainPolicy {
        KeychainPolicy(
            accessibility: kSecAttrAccessibleAfterFirstUnlock,
            accessGroup: nil,
            synchronizable: false,
            service: service
        )
    }
}

/// A JSON root under the temporary directory no other test shares.
func uniqueJSONRoot() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("smlp-tests-\(UUID().uuidString)", isDirectory: true)
}

// MARK: - Store cleanup

func removeUserDefaultsSuite(_ name: String) {
    UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
}

func removeKeychainItems(service: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
    ]
    _ = SecItemDelete(query as CFDictionary)
}

func removeJSONRoot(_ root: URL) {
    try? FileManager.default.removeItem(at: root)
}

// MARK: - Store polling

struct TimedOut: Error {}

/// Polls the store until `condition` holds. Throws ``TimedOut`` at the deadline, so an
/// absence assertion is `#expect(throws: TimedOut.self)` around a short wait.
@MainActor
func waitFor(
    timeout: Duration = .seconds(1),
    _ condition: () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    throw TimedOut()
}

/// Reads one Keychain item's data; any error reads as missing. Assertion helper only.
@MainActor
func keychainData(identity: KeychainIdentity, account: String) -> Data? {
    (try? copyKeychainData(identity: identity, account: account)) ?? nil
}
