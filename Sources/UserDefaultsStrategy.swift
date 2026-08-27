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

    public func onRead<Storage: StateContainer, Value, Status>(
        _ keyPath: KeyPath<Storage, AsyncState<UserDefaultsStrategy, Value, Status>>,
        policy: Policy,
        current: Value
    ) {
        let defaults = PersistenceOverlay.userDefaults(policy: policy, environmentID: env.environmentID)
        let key = userDefaultsKey(keyPath)
        if let data = defaults.data(forKey: key) {
            applyEncoded(data, keyPath: keyPath)
        } else {
            env.apply(current, keyPath: keyPath)
        }
    }

    public func onRead<Storage: StateContainer, Key: Hashable, Value, Status>(
        _ keyPath: KeyPath<Storage, AsyncState<UserDefaultsStrategy, [Key: Value], Status>>,
        key: Key,
        policy: Policy,
        current: Value?
    ) {
        let defaults = PersistenceOverlay.userDefaults(policy: policy, environmentID: env.environmentID)
        let udKey = userDefaultsKey(keyPath, key: key)
        if let data = defaults.data(forKey: udKey) {
            applyEncoded(data, keyPath: keyPath, key: key)
        } else {
            env.apply(current, keyPath: keyPath, key: key)
        }
    }

    public func onWrite<Storage: StateContainer, Value, Status>(
        _ value: Value,
        _ keyPath: KeyPath<Storage, AsyncState<UserDefaultsStrategy, Value, Status>>,
        policy: Policy
    ) {
        persist(value, key: userDefaultsKey(keyPath), policy: policy)
    }

    public func onWrite<Storage: StateContainer, Key: Hashable, Value, Status>(
        _ value: Value,
        _ keyPath: KeyPath<Storage, AsyncState<UserDefaultsStrategy, [Key: Value], Status>>,
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
            // Persist-out does not fail Source status (ADR 0020).
            userDefaultsLog.error("Persist-out failed: \(error.localizedDescription)")
        }
    }

    private func applyEncoded<Storage: StateContainer, Value, Status>(
        _ data: Data,
        keyPath: KeyPath<Storage, AsyncState<UserDefaultsStrategy, Value, Status>>
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

    private func applyEncoded<Storage: StateContainer, Key: Hashable, Value, Status>(
        _ data: Data,
        keyPath: KeyPath<Storage, AsyncState<UserDefaultsStrategy, [Key: Value], Status>>,
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
