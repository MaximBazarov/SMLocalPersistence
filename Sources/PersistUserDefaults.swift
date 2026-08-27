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

/// Writes one UserDefaults key. Throws on encode. Writes no Values.
struct PersistUserDefaults<Value>: ThrowingSyncOperation {
    let defaults: UserDefaults
    let key: String
    let value: Value

    func perform(in env: SyncOperationEnvironment) throws(EncodingError) {
        if isNilOptional(value) {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(try encodeUserDefaultsValue(value), forKey: key)
    }
}
