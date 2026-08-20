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

/// Keychain Source. One instance per Environment. `sourceUpdate` is `.write`. The app does not construct it.
@MainActor
public final class KeychainSource: Source {
    public typealias Failure = KeychainFailure
    public typealias Policy = KeychainPolicy

    public let sourceUpdate = SourceUpdate.write

    var persistItems: [PersistItem] = []

    public init() {}

    public func provide<Storage: StateContainer, Value>(
        _ keyPath: KeyPath<Storage, Value>,
        policy: Policy,
        in env: SourceEnvironment
    ) {
        guard let writable = keyPath as? WritableKeyPath<Storage, Value> else {
            return
        }
        let identity = PersistenceOverlay.keychain(policy: policy, environmentID: env.environmentID)
        KeychainPersistLedger.register(self, environmentID: env.environmentID)
        let account = keychainAccount(keyPath)
        let loaded: Bool
        do {
            if let data = try copyKeychainData(identity: identity, account: account) {
                loaded = deliverEncoded(data, keyPath: writable, env: env)
            } else {
                env.deliver(env.read(keyPath), keyPath: writable)
                loaded = false
            }
        } catch {
            env.fail(error, keyPath: keyPath)
            loaded = false
        }
        registerPersist(keyPath, account: account, identity: identity, persistOnNextServe: loaded)
        env.spawnService(KeychainPersist.self)
    }

    public func provide<Storage: StateContainer, Key: Hashable, Value>(
        _ keyPath: KeyPath<Storage, [Key: Value]>,
        key: Key,
        policy: Policy,
        in env: SourceEnvironment
    ) {
        let identity = PersistenceOverlay.keychain(policy: policy, environmentID: env.environmentID)
        KeychainPersistLedger.register(self, environmentID: env.environmentID)
        let account = keychainAccount(keyPath, key: key)
        let loaded: Bool
        if let writable = keyPath as? WritableKeyPath<Storage, [Key: Value]> {
            do {
                if let data = try copyKeychainData(identity: identity, account: account) {
                    loaded = deliverEncoded(data, keyPath: writable, key: key, env: env)
                } else {
                    loaded = false
                }
            } catch {
                env.fail(error, keyPath: keyPath, key: key)
                loaded = false
            }
        } else {
            loaded = false
        }
        registerPersist(keyPath, entry: key, account: account, identity: identity, persistOnNextServe: loaded)
        env.spawnService(KeychainPersist.self)
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
            env.fail(KeychainFailure.decoding(error), keyPath: keyPath)
            return false
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
            env.fail(KeychainFailure.decoding(error), keyPath: keyPath, key: key)
            return false
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
            return false
        }
    }

    private func registerPersist<Storage: StateContainer, Value>(
        _ keyPath: KeyPath<Storage, Value>,
        account: String,
        identity: KeychainIdentity,
        persistOnNextServe: Bool
    ) {
        let item = PersistItem(
            persistOnNextServe: persistOnNextServe,
            wasSourcedUpdated: { [weak self] service in
                if service.wasUpdated(keyPath) {
                    return true
                }
                guard let self else {
                    return false
                }
                // A Sync write or Seed can land before first serve subscribes; persist current if it is not the seed.
                return self.differsFromContainerSeed(service.getValue(keyPath), keyPath: keyPath)
            },
            subscribe: { service in
                _ = service.getValue(keyPath)
            },
            run: { service in
                let value = service.getValue(keyPath)
                try service.perform(PersistKeychain(identity: identity, account: account, value: value))
            }
        )
        persistItems.append(item)
    }

    private func registerPersist<Storage: StateContainer, Key: Hashable, Value>(
        _ keyPath: KeyPath<Storage, [Key: Value]>,
        entry: Key,
        account: String,
        identity: KeychainIdentity,
        persistOnNextServe: Bool
    ) {
        let item = PersistItem(
            persistOnNextServe: persistOnNextServe,
            wasSourcedUpdated: { _ in true },
            subscribe: { service in
                _ = service.getValue(keyPath: keyPath, key: entry)
            },
            run: { service in
                guard let value = service.getValue(keyPath: keyPath, key: entry) else {
                    return
                }
                try service.perform(PersistKeychain(identity: identity, account: account, value: value))
            }
        )
        persistItems.append(item)
    }

    private func differsFromContainerSeed<Storage: StateContainer, Value>(
        _ value: Value,
        keyPath: KeyPath<Storage, Value>
    ) -> Bool {
        guard value is any Equatable else {
            return false
        }
        return !isEqual(value, Storage()[keyPath: keyPath])
    }
}

extension Equatable {
    fileprivate func isEqual(to other: Any) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self == other
    }
}

private func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    guard let lhs = lhs as? any Equatable else {
        return false
    }
    return lhs.isEqual(to: rhs)
}
