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
import StateManagement

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
        _ keyPath: KeyPath<Storage, Value>,
        policy: Policy,
        current: Value
    ) {
        guard let writable = keyPath as? WritableKeyPath<Storage, Value> else {
            return
        }
        let defaults = PersistenceOverlay.userDefaults(policy: policy, environmentID: env.environmentID)
        let key = userDefaultsKey(keyPath)
        if let data = defaults.data(forKey: key) {
            applyEncoded(data, keyPath: writable)
        } else {
            env.apply(current, keyPath: writable)
        }
    }

    public func onRead<Storage: StateContainer, Key: Hashable, Value>(
        _ keyPath: KeyPath<Storage, [Key: Value]>,
        key: Key,
        policy: Policy,
        current: Value?
    ) {
        guard let writable = keyPath as? WritableKeyPath<Storage, [Key: Value]> else {
            return
        }
        let defaults = PersistenceOverlay.userDefaults(policy: policy, environmentID: env.environmentID)
        let udKey = userDefaultsKey(keyPath, key: key)
        if let data = defaults.data(forKey: udKey) {
            applyEncoded(data, keyPath: writable, key: key)
        } else if let current {
            env.apply(current, keyPath: writable, key: key)
        }
    }

    public func onWrite<Storage: StateContainer, Value>(
        _ value: Value,
        _ keyPath: KeyPath<Storage, Value>,
        policy: Policy
    ) {
        persist(value, key: userDefaultsKey(keyPath), policy: policy)
    }

    public func onWrite<Storage: StateContainer, Key: Hashable, Value>(
        _ value: Value,
        _ keyPath: KeyPath<Storage, [Key: Value]>,
        key: Key,
        policy: Policy
    ) {
        persist(value, key: userDefaultsKey(keyPath, key: key), policy: policy)
    }

    private func persist<Value>(_ value: Value, key: String, policy: Policy) {
        let defaults = PersistenceOverlay.userDefaults(policy: policy, environmentID: env.environmentID)
        do {
            try env.perform(PersistUserDefaults(defaults: defaults, key: key, value: value))
        } catch {
            // Persist-out does not fail Source status.
        }
    }

    private func applyEncoded<Storage: StateContainer, Value>(
        _ data: Data,
        keyPath: WritableKeyPath<Storage, Value>
    ) {
        do {
            let value: Value = try decodeUserDefaultsValue(Value.self, from: data)
            env.apply(value, keyPath: keyPath)
        } catch let error as DecodingError {
            env.fail(error, keyPath: keyPath)
        } catch {
            env.fail(
                DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: [],
                        debugDescription: String(describing: error)
                    )
                ),
                keyPath: keyPath
            )
        }
    }

    private func applyEncoded<Storage: StateContainer, Key: Hashable, Value>(
        _ data: Data,
        keyPath: WritableKeyPath<Storage, [Key: Value]>,
        key: Key
    ) {
        do {
            let value: Value = try decodeUserDefaultsValue(Value.self, from: data)
            env.apply(value, keyPath: keyPath, key: key)
        } catch let error as DecodingError {
            env.fail(error, keyPath: keyPath, key: key)
        } catch {
            env.fail(
                DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: [],
                        debugDescription: String(describing: error)
                    )
                ),
                keyPath: keyPath,
                key: key
            )
        }
    }
}
