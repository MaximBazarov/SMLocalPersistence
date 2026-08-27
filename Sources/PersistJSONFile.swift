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

/// Writes or deletes one JSON file. Throws on encode or IO. Writes no Values.
@_documentation(visibility: private)
struct PersistJSONFile<Value>: ThrowingSyncOperation {
    let root: URL
    let location: JSONFileLocation
    let value: Value

    func perform(in env: SyncOperationEnvironment) throws(PersistJSONFileError) {
        if isNilOptional(value) {
            do {
                try deleteJSONFile(root: root, location: location)
            } catch {
                throw PersistJSONFileError.io
            }
            return
        }
        let data: Data
        do {
            data = try encodeJSONFileValue(value)
        } catch {
            throw PersistJSONFileError.encoding(error)
        }
        do {
            try writeJSONFileData(root: root, location: location, data: data)
        } catch {
            throw PersistJSONFileError.io
        }
    }
}

@_documentation(visibility: private)
enum PersistJSONFileError: Error {
    case encoding(EncodingError)
    case io
}
