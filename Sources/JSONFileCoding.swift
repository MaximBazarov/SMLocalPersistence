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

@_documentation(visibility: private)
func encodeJSONFileValue<T>(_ value: T) throws(EncodingError) -> Data {
    guard let encodable = value as? any Encodable else {
        preconditionFailure("SMLocalPersistence Value must be Codable")
    }
    return try encodeJSON(encodable)
}

@_documentation(visibility: private)
func decodeJSONFileValue<T>(_ type: T.Type, from data: Data) throws -> T {
    guard let decodableType = T.self as? any Decodable.Type else {
        preconditionFailure("SMLocalPersistence Value must be Codable")
    }
    let decoded = try decodeJSON(decodableType, from: data)
    guard let typed = decoded as? T else {
        throw DecodingError.typeMismatch(
            T.self,
            DecodingError.Context(codingPath: [], debugDescription: "JSON-file Value")
        )
    }
    return typed
}

private func encodeJSON(_ value: any Encodable) throws(EncodingError) -> Data {
    func wrap<T: Encodable>(_ value: T) throws(EncodingError) -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch let error as EncodingError {
            throw error
        } catch {
            preconditionFailure("JSONEncoder.encode throws EncodingError")
        }
    }
    return try wrap(value)
}

private func decodeJSON(_ type: any Decodable.Type, from data: Data) throws -> Any {
    func unwrap<T: Decodable>(_ type: T.Type) throws -> Any {
        try JSONDecoder().decode(type, from: data)
    }
    return try unwrap(type)
}
