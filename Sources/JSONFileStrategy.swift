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

private let jsonFileStrategyLog = Logger(subsystem: "SMLocalPersistence", category: "JSONFile")

/// JSON-file strategy. One instance per Environment. The app does not construct it.
@MainActor
public final class JSONFileStrategy: AsyncStrategy {
    public typealias Failure = JSONFileFailure
    public typealias Policy = JSONFilePolicy

    private let env: AsyncStrategyEnvironment

    public init(env: AsyncStrategyEnvironment) {
        self.env = env
    }

    public func onRead<Storage: StateContainer, Value>(
        _ address: KeyPath<Storage, AsyncState<JSONFileStrategy, NoKey, Value, Value>>,
        policy: Policy,
        current: Value
    ) {
        let root = policy.root
        let location = jsonFileLocation(address)
        do {
            if let data = try copyJSONFileData(root: root, location: location) {
                applyEncoded(data, address: address)
            } else {
                env.apply(address, value: current)
            }
        } catch {
            env.fail(address, error: error)
        }
    }

    public func onRead<Storage: StateContainer, Key: Hashable, Value>(
        _ address: KeyPath<Storage, AsyncState<JSONFileStrategy, Key, Value, [Key: Value]>>,
        key: Key,
        policy: Policy,
        current: Value?
    ) {
        let root = policy.root
        let location = jsonFileLocation(address, key: key)
        do {
            if let data = try copyJSONFileData(root: root, location: location) {
                applyEncoded(data, address: address, key: key)
            } else {
                env.apply(address, key: key, value: current)
            }
        } catch {
            env.fail(address, key: key, error: error)
        }
    }

    public func onWrite<Storage: StateContainer, Value>(
        _ address: KeyPath<Storage, AsyncState<JSONFileStrategy, NoKey, Value, Value>>,
        policy: Policy,
        value: Value
    ) {
        persist(value, location: jsonFileLocation(address), policy: policy)
    }

    public func onWrite<Storage: StateContainer, Key: Hashable, Value>(
        _ address: KeyPath<Storage, AsyncState<JSONFileStrategy, Key, Value, [Key: Value]>>,
        key: Key,
        policy: Policy,
        value: Value
    ) {
        persist(value, location: jsonFileLocation(address, key: key), policy: policy)
    }

    private func persist<Value>(_ value: Value, location: JSONFileLocation, policy: Policy) {
        let root = policy.root
        do {
            try env.perform(PersistJSONFile(root: root, location: location, value: value))
        } catch {
            // Persist-out does not fail Source status.
            jsonFileStrategyLog.error("Persist-out failed: \(error.localizedDescription)")
        }
    }

    private func applyEncoded<Storage: StateContainer, Value>(
        _ data: Data,
        address: KeyPath<Storage, AsyncState<JSONFileStrategy, NoKey, Value, Value>>
    ) {
        do {
            let value: Value = try decodeJSONFileValue(Value.self, from: data)
            env.apply(address, value: value)
        } catch let error as DecodingError {
            env.fail(address, error: JSONFileFailure.decoding(error))
        } catch {
            env.fail(
                address,
                error: JSONFileFailure.decoding(
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
        address: KeyPath<Storage, AsyncState<JSONFileStrategy, Key, Value, [Key: Value]>>,
        key: Key
    ) {
        do {
            let value: Value = try decodeJSONFileValue(Value.self, from: data)
            env.apply(address, key: key, value: value)
        } catch let error as DecodingError {
            env.fail(address, key: key, error: JSONFileFailure.decoding(error))
        } catch {
            env.fail(
                address,
                key: key,
                error: JSONFileFailure.decoding(
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
