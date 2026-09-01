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

struct JSONFileLocation: Equatable, Sendable {
    let folder: String
    let file: String
}

func jsonFileLocation<Storage: StateContainer, Value>(
    _ address: KeyPath<Storage, Value>
) -> JSONFileLocation {
    JSONFileLocation(
        folder: String(reflecting: Storage.self),
        file: jsonFileName(dollarAddressDescription(address))
    )
}

func jsonFileLocation<Storage: StateContainer, Value, Key: Hashable>(
    _ address: KeyPath<Storage, Value>,
    key: Key
) -> JSONFileLocation {
    guard let lossless = key as? any LosslessStringConvertible else {
        preconditionFailure("SMLocalPersistence keyed keys must be LosslessStringConvertible")
    }
    return JSONFileLocation(
        folder: String(reflecting: Storage.self),
        file: jsonFileName("\(dollarAddressDescription(address))#\(lossless.description)")
    )
}

func jsonFileName(_ address: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
    guard let encoded = address.addingPercentEncoding(withAllowedCharacters: allowed) else {
        preconditionFailure("JSON-file Address encoding failed")
    }
    return encoded
}

func jsonFileURL(root: URL, location: JSONFileLocation) -> URL {
    root.appendingPathComponent(location.folder, isDirectory: true)
        .appendingPathComponent(location.file, isDirectory: false)
}
