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

private let userDefaultsLog = Logger(subsystem: "SMLocalPersistence", category: "UserDefaults")

/// UserDefaults strategy. One instance per Environment. The app does not construct it.
@MainActor
public final class UserDefaultsStrategy: AsyncStrategy {
    public typealias Failure = DecodingError
    public typealias Policy = UserDefaultsPolicy

    private let env: AsyncStrategyEnvironment

    public init(env: AsyncStrategyEnvironment) {
        self.env = env
    }

    public func onRead<Storage: StateContainer, Value>(
        _ address: KeyPath<Storage, AsyncState<UserDefaultsStrategy, NoKey, Value, Value>>,
        policy: Policy,
        current: Value
    ) {
        let defaults = PersistenceOverlay.userDefaults(policy: policy, environmentID: env.environmentID)
        let key = userDefaultsKey(address)
        if let data = defaults.data(forKey: key) {
            applyEncoded(data, address: address)
        } else {
            env.apply(address, value: current)
        }
    }

    public func onRead<Storage: StateContainer, Key: Hashable, Value>(
        _ address: KeyPath<Storage, AsyncState<UserDefaultsStrategy, Key, Value, [Key: Value]>>,
        key: Key,
        policy: Policy,
        current: Value?
    ) {
        let defaults = PersistenceOverlay.userDefaults(policy: policy, environmentID: env.environmentID)
        let udKey = userDefaultsKey(address, key: key)
        if let data = defaults.data(forKey: udKey) {
            applyEncoded(data, address: address, key: key)
        } else {
            env.apply(address, key: key, value: current)
        }
    }

    public func onWrite<Storage: StateContainer, Value>(
        _ address: KeyPath<Storage, AsyncState<UserDefaultsStrategy, NoKey, Value, Value>>,
        policy: Policy,
        value: Value
    ) {
        persist(value, key: userDefaultsKey(address), policy: policy)
    }

    public func onWrite<Storage: StateContainer, Key: Hashable, Value>(
        _ address: KeyPath<Storage, AsyncState<UserDefaultsStrategy, Key, Value, [Key: Value]>>,
        key: Key,
        policy: Policy,
        value: Value
    ) {
        persist(value, key: userDefaultsKey(address, key: key), policy: policy)
    }

    private func persist<Value>(_ value: Value, key: String, policy: Policy) {
        let defaults = PersistenceOverlay.userDefaults(policy: policy, environmentID: env.environmentID)
        do {
            try env.perform(PersistUserDefaults(defaults: defaults, key: key, value: value))
        } catch {
            // Persist-out does not fail Source status.
            userDefaultsLog.error("Persist-out failed: \(error.localizedDescription)")
        }
    }

    private func applyEncoded<Storage: StateContainer, Value>(
        _ data: Data,
        address: KeyPath<Storage, AsyncState<UserDefaultsStrategy, NoKey, Value, Value>>
    ) {
        do {
            let value: Value = try decodeUserDefaultsValue(Value.self, from: data)
            env.apply(address, value: value)
        } catch let error as DecodingError {
            env.fail(address, error: error)
        } catch {
            env.fail(
                address,
                error: DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: [],
                        debugDescription: String(describing: error)
                    )
                )
            )
        }
    }

    private func applyEncoded<Storage: StateContainer, Key: Hashable, Value>(
        _ data: Data,
        address: KeyPath<Storage, AsyncState<UserDefaultsStrategy, Key, Value, [Key: Value]>>,
        key: Key
    ) {
        do {
            let value: Value = try decodeUserDefaultsValue(Value.self, from: data)
            env.apply(address, key: key, value: value)
        } catch let error as DecodingError {
            env.fail(address, key: key, error: error)
        } catch {
            env.fail(
                address,
                key: key,
                error: DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: [],
                        debugDescription: String(describing: error)
                    )
                )
            )
        }
    }
}
