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

    public func onRead<Storage: StateContainer, Value>(
        _ address: KeyPath<Storage, AsyncState<KeychainStrategy, NoKey, Value, Value>>,
        policy: Policy,
        current: Value
    ) {
        let identity = policy.identity
        let account = keychainAccount(address)
        do {
            if let data = try copyKeychainData(identity: identity, account: account) {
                applyEncoded(data, address: address)
            } else {
                env.apply(address, value: current)
            }
        } catch {
            env.fail(address, error: error)
        }
    }

    public func onRead<Storage: StateContainer, Key: Hashable, Value>(
        _ address: KeyPath<Storage, AsyncState<KeychainStrategy, Key, Value, [Key: Value]>>,
        key: Key,
        policy: Policy,
        current: Value?
    ) {
        let identity = policy.identity
        let account = keychainAccount(address, key: key)
        do {
            if let data = try copyKeychainData(identity: identity, account: account) {
                applyEncoded(data, address: address, key: key)
            } else {
                env.apply(address, key: key, value: current)
            }
        } catch {
            env.fail(address, key: key, error: error)
        }
    }

    public func onWrite<Storage: StateContainer, Value>(
        _ address: KeyPath<Storage, AsyncState<KeychainStrategy, NoKey, Value, Value>>,
        policy: Policy,
        value: Value
    ) {
        persist(value, account: keychainAccount(address), policy: policy)
    }

    public func onWrite<Storage: StateContainer, Key: Hashable, Value>(
        _ address: KeyPath<Storage, AsyncState<KeychainStrategy, Key, Value, [Key: Value]>>,
        key: Key,
        policy: Policy,
        value: Value
    ) {
        persist(value, account: keychainAccount(address, key: key), policy: policy)
    }

    private func persist<Value>(_ value: Value, account: String, policy: Policy) {
        let identity = policy.identity
        do {
            try env.perform(PersistKeychain(identity: identity, account: account, value: value))
        } catch {
            // Persist-out does not fail async state status.
            keychainStrategyLog.error("Persist-out failed: \(error.localizedDescription)")
        }
    }

    private func applyEncoded<Storage: StateContainer, Value>(
        _ data: Data,
        address: KeyPath<Storage, AsyncState<KeychainStrategy, NoKey, Value, Value>>
    ) {
        do {
            let value: Value = try decodeUserDefaultsValue(Value.self, from: data)
            env.apply(address, value: value)
        } catch let error as DecodingError {
            env.fail(address, error: KeychainFailure.decoding(error))
        } catch {
            env.fail(
                address,
                error: KeychainFailure.decoding(
                    DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: [],
                            debugDescription: String(describing: error)
                        )
                    )
                )
            )
        }
    }

    private func applyEncoded<Storage: StateContainer, Key: Hashable, Value>(
        _ data: Data,
        address: KeyPath<Storage, AsyncState<KeychainStrategy, Key, Value, [Key: Value]>>,
        key: Key
    ) {
        do {
            let value: Value = try decodeUserDefaultsValue(Value.self, from: data)
            env.apply(address, key: key, value: value)
        } catch let error as DecodingError {
            env.fail(address, key: key, error: KeychainFailure.decoding(error))
        } catch {
            env.fail(
                address,
                key: key,
                error: KeychainFailure.decoding(
                    DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: [],
                            debugDescription: String(describing: error)
                        )
                    )
                )
            )
        }
    }
}
