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

/// Writes or deletes one Keychain item. Throws on encode or SecItem. Writes no Values.
struct PersistKeychain<Value>: ThrowingSyncOperation {
    let identity: KeychainIdentity
    let account: String
    let value: Value

    func perform(in env: SyncOperationEnvironment) throws(PersistKeychainError) {
        if isNilOptional(value) {
            do {
                try deleteKeychainItem(identity: identity, account: account)
            } catch {
                throw PersistKeychainError.keychain(error)
            }
            return
        }
        let data: Data
        do {
            data = try encodeUserDefaultsValue(value)
        } catch {
            throw PersistKeychainError.encoding(error)
        }
        do {
            try upsertKeychainData(identity: identity, account: account, data: data)
        } catch {
            throw PersistKeychainError.keychain(error)
        }
    }
}

enum PersistKeychainError: Error {
    case encoding(EncodingError)
    case keychain(KeychainFailure)
}

private protocol NilOptional {
    var isNil: Bool { get }
}

extension Optional: NilOptional {
    var isNil: Bool { self == nil }
}

private func isNilOptional(_ value: Any) -> Bool {
    (value as? any NilOptional)?.isNil == true
}
