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
import StateManagement

private let keychainStrategyLog = Logger(subsystem: "SMLocalPersistence", category: "Keychain")

/// Keychain strategy. One instance per Environment. The app does not construct it.
@MainActor
public final class KeychainStrategy: AsyncStrategy {
    public typealias Failure = KeychainFailure
    public typealias Policy = KeychainPolicy

    private let env: AsyncStrategyEnvironment

    public init(env: AsyncStrategyEnvironment) {
        self.env = env
    }

    public func onRead<Storage: StateContainer, Value, Status>(
        _ keyPath: KeyPath<Storage, AsyncState<KeychainStrategy, Value, Status>>,
        policy: Policy,
        current: Value
    ) {
        let identity = PersistenceOverlay.keychain(policy: policy, environmentID: env.environmentID)
        let account = keychainAccount(keyPath)
        do {
            if let data = try copyKeychainData(identity: identity, account: account) {
                applyEncoded(data, keyPath: keyPath)
            } else {
                env.apply(current, keyPath: keyPath)
            }
        } catch {
            env.fail(error, keyPath: keyPath)
        }
    }

    public func onRead<Storage: StateContainer, Key: Hashable, Value, Status>(
        _ keyPath: KeyPath<Storage, AsyncState<KeychainStrategy, [Key: Value], Status>>,
        key: Key,
        policy: Policy,
        current: Value?
    ) {
        let identity = PersistenceOverlay.keychain(policy: policy, environmentID: env.environmentID)
        let account = keychainAccount(keyPath, key: key)
        do {
            if let data = try copyKeychainData(identity: identity, account: account) {
                applyEncoded(data, keyPath: keyPath, key: key)
            } else {
                env.apply(current, keyPath: keyPath, key: key)
            }
        } catch {
            env.fail(error, keyPath: keyPath, key: key)
        }
    }

    public func onWrite<Storage: StateContainer, Value, Status>(
        _ value: Value,
        _ keyPath: KeyPath<Storage, AsyncState<KeychainStrategy, Value, Status>>,
        policy: Policy
    ) {
        persist(value, account: keychainAccount(keyPath), policy: policy)
    }

    public func onWrite<Storage: StateContainer, Key: Hashable, Value, Status>(
        _ value: Value,
        _ keyPath: KeyPath<Storage, AsyncState<KeychainStrategy, [Key: Value], Status>>,
        key: Key,
        policy: Policy
    ) {
        persist(value, account: keychainAccount(keyPath, key: key), policy: policy)
    }

    private func persist<Value>(_ value: Value, account: String, policy: Policy) {
        let identity = PersistenceOverlay.keychain(policy: policy, environmentID: env.environmentID)
        do {
            try env.perform(PersistKeychain(identity: identity, account: account, value: value))
        } catch {
            // Persist-out does not fail Source status (ADR 0020).
            keychainStrategyLog.error("Persist-out failed: \(error.localizedDescription)")
        }
    }

    private func applyEncoded<Storage: StateContainer, Value, Status>(
        _ data: Data,
        keyPath: KeyPath<Storage, AsyncState<KeychainStrategy, Value, Status>>
    ) {
        do {
            let value: Value = try decodeUserDefaultsValue(Value.self, from: data)
            env.apply(value, keyPath: keyPath)
        } catch let error as DecodingError {
            env.fail(KeychainFailure.decoding(error), keyPath: keyPath)
        } catch {
            env.fail(
                KeychainFailure.decoding(
                    DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: [],
                            debugDescription: String(describing: error)
                        )
                    )
                ),
                keyPath: keyPath
            )
        }
    }

    private func applyEncoded<Storage: StateContainer, Key: Hashable, Value, Status>(
        _ data: Data,
        keyPath: KeyPath<Storage, AsyncState<KeychainStrategy, [Key: Value], Status>>,
        key: Key
    ) {
        do {
            let value: Value = try decodeUserDefaultsValue(Value.self, from: data)
            env.apply(value, keyPath: keyPath, key: key)
        } catch let error as DecodingError {
            env.fail(KeychainFailure.decoding(error), keyPath: keyPath, key: key)
        } catch {
            env.fail(
                KeychainFailure.decoding(
                    DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: [],
                            debugDescription: String(describing: error)
                        )
                    )
                ),
                keyPath: keyPath,
                key: key
            )
        }
    }
}
