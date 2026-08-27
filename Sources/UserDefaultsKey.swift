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

func userDefaultsKey<Storage: StateContainer, Value>(
    _ keyPath: KeyPath<Storage, Value>
) -> String {
    "smud.\(dollarAddressDescription(keyPath))"
}

func userDefaultsKey<Storage: StateContainer, Value, Key: Hashable>(
    _ keyPath: KeyPath<Storage, Value>,
    key: Key
) -> String {
    guard let lossless = key as? any LosslessStringConvertible else {
        preconditionFailure("SMLocalPersistence keyed keys must be LosslessStringConvertible")
    }
    return "smud.\(dollarAddressDescription(keyPath))#\(lossless.description)"
}

/// Value-first kicks receive `_property`; `$`-first kicks receive `$property`. Persist keys are the `$` Address.
func dollarAddressDescription<Storage, Value>(_ keyPath: KeyPath<Storage, Value>) -> String {
    String(describing: keyPath).replacingOccurrences(of: "._", with: ".$")
}
