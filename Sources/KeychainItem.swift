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
import Security

struct KeychainIdentity: Sendable, Equatable {
    let service: String
    let accessibility: String
    let accessGroup: String?
    let synchronizable: Bool
}

private let keychainLog = Logger(subsystem: "SMLocalPersistence", category: "Keychain")

func copyKeychainData(identity: KeychainIdentity, account: String) throws(KeychainFailure) -> Data? {
    var query = baseKeychainQuery(identity: identity, account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
        return nil
    }
    guard status == errSecSuccess else {
        throw KeychainFailure.osStatus(status)
    }
    guard let data = result as? Data else {
        throw KeychainFailure.osStatus(errSecInternalError)
    }
    return data
}

func upsertKeychainData(identity: KeychainIdentity, account: String, data: Data) throws(KeychainFailure) {
    let query = baseKeychainQuery(identity: identity, account: account)
    let attributes: [String: Any] = [
        kSecValueData as String: data,
        kSecAttrAccessible as String: identity.accessibility,
    ]
    let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess {
        return
    }
    if updateStatus != errSecItemNotFound {
        throw KeychainFailure.osStatus(updateStatus)
    }
    var add = query
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = identity.accessibility
    let addStatus = SecItemAdd(add as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
        throw KeychainFailure.osStatus(addStatus)
    }
}

func deleteKeychainItem(identity: KeychainIdentity, account: String) throws(KeychainFailure) {
    let query = baseKeychainQuery(identity: identity, account: account)
    let status = SecItemDelete(query as CFDictionary)
    if status == errSecSuccess || status == errSecItemNotFound {
        return
    }
    throw KeychainFailure.osStatus(status)
}

func deleteKeychainItems(service: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
        keychainLog.error("IsolatedPersistence Keychain clear failed: \(status)")
    }
}

func baseKeychainQuery(identity: KeychainIdentity, account: String) -> [String: Any] {
    var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: identity.service,
        kSecAttrAccount as String: account,
        kSecAttrSynchronizable as String: identity.synchronizable ? kCFBooleanTrue as Any : kCFBooleanFalse as Any,
    ]
    if let accessGroup = identity.accessGroup {
        query[kSecAttrAccessGroup as String] = accessGroup
    }
    return query
}
