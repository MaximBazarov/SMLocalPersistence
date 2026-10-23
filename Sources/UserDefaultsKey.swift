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

/// Containers with durable data name every persisted address explicitly. Swift's
/// optimized key-path descriptions can contain process-specific getter addresses.
/// Nonconforming containers continue to use those descriptions as their addresses.
public protocol StableUserDefaultsContainer: StateContainer {
    /// Maps both `_property` and `$property` key paths to the same permanent address.
    /// Use a distinct symbolic address for each persisted property, without the
    /// `smud.` prefix or keyed suffix; UserDefaults adds those when forming the key.
    /// A missing entry for a persisted key path is a precondition failure.
    static var userDefaultsAddresses: [AnyKeyPath: String] { get }
}

@MainActor
func userDefaultsKey<Storage: StateContainer, Value>(
    _ address: KeyPath<Storage, Value>
) -> String {
    "smud.\(stableUserDefaultsAddress(address))"
}

@MainActor
func userDefaultsKey<Storage: StateContainer, Value, Key: Hashable>(
    _ address: KeyPath<Storage, Value>,
    key: Key
) -> String {
    guard let lossless = key as? any LosslessStringConvertible else {
        preconditionFailure("SMLocalPersistence keyed keys must be LosslessStringConvertible")
    }
    return "smud.\(stableUserDefaultsAddress(address))#\(lossless.description)"
}

/// Value-first kicks receive `_property`; `$`-first kicks receive `$property`. Persist keys are the `$` Address.
@MainActor
private func stableUserDefaultsAddress<Storage, Value>(_ address: KeyPath<Storage, Value>) -> String {
    if let container = Storage.self as? any StableUserDefaultsContainer.Type {
        guard let stable = container.userDefaultsAddresses[address] else {
            preconditionFailure("Missing stable UserDefaults address in \(Storage.self)")
        }
        return stable
    }
    return String(describing: address).replacingOccurrences(of: "._", with: ".$")
}

func dollarAddressDescription<Storage, Value>(_ address: KeyPath<Storage, Value>) -> String {
    String(describing: address).replacingOccurrences(of: "._", with: ".$")
}
