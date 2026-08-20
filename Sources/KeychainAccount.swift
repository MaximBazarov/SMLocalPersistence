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

func keychainAccount<Storage: StateContainer, Value>(
    _ keyPath: KeyPath<Storage, Value>
) -> String {
    "smkc.\(String(describing: keyPath))"
}

func keychainAccount<Storage: StateContainer, Key: Hashable, Value>(
    _ keyPath: KeyPath<Storage, [Key: Value]>,
    key: Key
) -> String {
    guard let lossless = key as? any LosslessStringConvertible else {
        preconditionFailure("SMLocalPersistence keyed keys must be LosslessStringConvertible")
    }
    return "smkc.\(String(describing: keyPath))#\(lossless.description)"
}
