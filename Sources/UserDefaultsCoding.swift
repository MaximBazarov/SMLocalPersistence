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

private struct SMUDEncodableBox<Value: Encodable>: Encodable {
    var value: Value
}

private struct SMUDDecodableBox<Value: Decodable>: Decodable {
    var value: Value
}

func encodeUserDefaultsValue<T>(_ value: T) throws(EncodingError) -> Data {
    guard let encodable = value as? any Encodable else {
        preconditionFailure("SMLocalPersistence Value must be Codable")
    }
    return try encodeBoxed(encodable)
}

func decodeUserDefaultsValue<T>(_ type: T.Type, from data: Data) throws -> T {
    guard let decodableType = T.self as? any Decodable.Type else {
        preconditionFailure("SMLocalPersistence Value must be Codable")
    }
    let decoded = try decodeBoxed(decodableType, from: data)
    guard let typed = decoded as? T else {
        throw DecodingError.typeMismatch(
            T.self,
            DecodingError.Context(codingPath: [], debugDescription: "SMLocalPersistence box")
        )
    }
    return typed
}

private func encodeBoxed(_ value: any Encodable) throws(EncodingError) -> Data {
    func wrap<T: Encodable>(_ value: T) throws(EncodingError) -> Data {
        do {
            return try PropertyListEncoder().encode(SMUDEncodableBox(value: value))
        } catch let error as EncodingError {
            throw error
        } catch {
            preconditionFailure("PropertyListEncoder.encode throws EncodingError")
        }
    }
    return try wrap(value)
}

private func decodeBoxed(_ type: any Decodable.Type, from data: Data) throws -> Any {
    func unwrap<T: Decodable>(_ type: T.Type) throws -> Any {
        try PropertyListDecoder().decode(SMUDDecodableBox<T>.self, from: data).value
    }
    return try unwrap(type)
}
