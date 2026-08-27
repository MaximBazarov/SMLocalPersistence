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

/// JSON-file strategy. One instance per Environment. The app does not construct it.
@MainActor
public final class JSONFileStrategy: AsyncStrategy {
    public typealias Failure = JSONFileFailure
    public typealias Policy = JSONFilePolicy

    private let env: AsyncStrategyEnvironment

    public init(env: AsyncStrategyEnvironment) {
        self.env = env
    }

    public func onRead<Storage: StateContainer, Value, Status>(
        _ keyPath: KeyPath<Storage, AsyncState<JSONFileStrategy, Value, Status>>,
        policy: Policy,
        current: Value
    ) {
        let root = PersistenceOverlay.jsonRoot(policy: policy, environmentID: env.environmentID)
        let location = jsonFileLocation(keyPath)
        do {
            if let data = try copyJSONFileData(root: root, location: location) {
                applyEncoded(data, keyPath: keyPath)
            } else {
                env.apply(current, keyPath: keyPath)
            }
        } catch {
            env.fail(error, keyPath: keyPath)
        }
    }

    public func onRead<Storage: StateContainer, Key: Hashable, Value, Status>(
        _ keyPath: KeyPath<Storage, AsyncState<JSONFileStrategy, [Key: Value], Status>>,
        key: Key,
        policy: Policy,
        current: Value?
    ) {
        let root = PersistenceOverlay.jsonRoot(policy: policy, environmentID: env.environmentID)
        let location = jsonFileLocation(keyPath, key: key)
        do {
            if let data = try copyJSONFileData(root: root, location: location) {
                applyEncoded(data, keyPath: keyPath, key: key)
            } else if let current {
                env.apply(current, keyPath: keyPath, key: key)
            }
        } catch {
            env.fail(error, keyPath: keyPath, key: key)
        }
    }

    public func onWrite<Storage: StateContainer, Value, Status>(
        _ value: Value,
        _ keyPath: KeyPath<Storage, AsyncState<JSONFileStrategy, Value, Status>>,
        policy: Policy
    ) {
        persist(value, location: jsonFileLocation(keyPath), policy: policy)
    }

    public func onWrite<Storage: StateContainer, Key: Hashable, Value, Status>(
        _ value: Value,
        _ keyPath: KeyPath<Storage, AsyncState<JSONFileStrategy, [Key: Value], Status>>,
        key: Key,
        policy: Policy
    ) {
        persist(value, location: jsonFileLocation(keyPath, key: key), policy: policy)
    }

    private func persist<Value>(_ value: Value, location: JSONFileLocation, policy: Policy) {
        let root = PersistenceOverlay.jsonRoot(policy: policy, environmentID: env.environmentID)
        do {
            try env.perform(PersistJSONFile(root: root, location: location, value: value))
        } catch {
            // Persist-out does not fail Source status.
        }
    }

    private func applyEncoded<Storage: StateContainer, Value, Status>(
        _ data: Data,
        keyPath: KeyPath<Storage, AsyncState<JSONFileStrategy, Value, Status>>
    ) {
        do {
            let value: Value = try decodeJSONFileValue(Value.self, from: data)
            env.apply(value, keyPath: keyPath)
        } catch let error as DecodingError {
            env.fail(JSONFileFailure.decoding(error), keyPath: keyPath)
        } catch {
            env.fail(
                JSONFileFailure.decoding(
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
        keyPath: KeyPath<Storage, AsyncState<JSONFileStrategy, [Key: Value], Status>>,
        key: Key
    ) {
        do {
            let value: Value = try decodeJSONFileValue(Value.self, from: data)
            env.apply(value, keyPath: keyPath, key: key)
        } catch let error as DecodingError {
            env.fail(JSONFileFailure.decoding(error), keyPath: keyPath, key: key)
        } catch {
            env.fail(
                JSONFileFailure.decoding(
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
