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

/// UserDefaults Source. One instance per Environment. `sourceUpdate` is `.write`. The app does not construct it.
@MainActor
public final class UserDefaultsSource: Source {
    public typealias Failure = DecodingError

    public let sourceUpdate = SourceUpdate.write

    public init() {}

    public func provide<Storage: StateContainer, Value>(
        _ keyPath: KeyPath<Storage, Value>,
        in env: SourceEnvironment
    ) {
        guard let writable = keyPath as? WritableKeyPath<Storage, Value> else {
            return
        }
        let defaults = env.read(\UserDefaultsConfiguration.defaults)
        let key = userDefaultsKey(keyPath)
        let loaded: Bool
        if let data = defaults.data(forKey: key) {
            loaded = deliverEncoded(data, keyPath: writable, env: env)
        } else {
            env.deliver(env.read(keyPath), keyPath: writable)
            loaded = true
        }
        registerPersist(keyPath, key: key, defaults: defaults, persistOnNextServe: loaded)
        env.spawnService(UserDefaultsPersist.self)
    }

    public func provide<Storage: StateContainer, Key: Hashable, Value>(
        _ keyPath: KeyPath<Storage, [Key: Value]>,
        key: Key,
        in env: SourceEnvironment
    ) {
        let defaults = env.read(\UserDefaultsConfiguration.defaults)
        let udKey = userDefaultsKey(keyPath, key: key)
        let loaded: Bool
        if let writable = keyPath as? WritableKeyPath<Storage, [Key: Value]> {
            if let data = defaults.data(forKey: udKey) {
                loaded = deliverEncoded(data, keyPath: writable, key: key, env: env)
            } else {
                loaded = false
            }
        } else {
            loaded = false
        }
        registerPersist(keyPath, entry: key, udKey: udKey, defaults: defaults, persistOnNextServe: loaded)
        env.spawnService(UserDefaultsPersist.self)
    }

    private func deliverEncoded<Storage: StateContainer, Value>(
        _ data: Data,
        keyPath: WritableKeyPath<Storage, Value>,
        env: SourceEnvironment
    ) -> Bool {
        do {
            let value: Value = try decodeUserDefaultsValue(Value.self, from: data)
            env.deliver(value, keyPath: keyPath)
            return true
        } catch let error as DecodingError {
            env.fail(error, keyPath: keyPath)
            return false
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
            return false
        }
    }

    private func deliverEncoded<Storage: StateContainer, Key: Hashable, Value>(
        _ data: Data,
        keyPath: WritableKeyPath<Storage, [Key: Value]>,
        key: Key,
        env: SourceEnvironment
    ) -> Bool {
        do {
            let value: Value = try decodeUserDefaultsValue(Value.self, from: data)
            env.deliver(value, keyPath: keyPath, key: key)
            return true
        } catch let error as DecodingError {
            env.fail(error, keyPath: keyPath, key: key)
            return false
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
            return false
        }
    }

    private func registerPersist<Storage: StateContainer, Value>(
        _ keyPath: KeyPath<Storage, Value>,
        key: String,
        defaults: UserDefaults,
        persistOnNextServe: Bool
    ) {
        let item = PersistItem(
            persistOnNextServe: persistOnNextServe,
            wasSourcedUpdated: { service in
                service.wasUpdated(keyPath)
            },
            subscribe: { service in
                _ = service.getValue(keyPath)
            },
            run: { service in
                let store = service.getValue(\UserDefaultsConfiguration.defaults)
                let value = service.getValue(keyPath)
                try service.perform(PersistUserDefaults(defaults: store, key: key, value: value))
            }
        )
        UserDefaultsBindLedger.append(item, defaults: defaults)
    }

    private func registerPersist<Storage: StateContainer, Key: Hashable, Value>(
        _ keyPath: KeyPath<Storage, [Key: Value]>,
        entry: Key,
        udKey: String,
        defaults: UserDefaults,
        persistOnNextServe: Bool
    ) {
        let item = PersistItem(
            persistOnNextServe: persistOnNextServe,
            wasSourcedUpdated: { _ in true },
            subscribe: { service in
                _ = service.getValue(keyPath: keyPath, key: entry)
            },
            run: { service in
                let store = service.getValue(\UserDefaultsConfiguration.defaults)
                guard let value = service.getValue(keyPath: keyPath, key: entry) else {
                    return
                }
                try service.perform(PersistUserDefaults(defaults: store, key: udKey, value: value))
            }
        )
        UserDefaultsBindLedger.append(item, defaults: defaults)
    }
}
