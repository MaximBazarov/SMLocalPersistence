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
import Security
import Testing
import StateManagement
@testable import SMLocalPersistence

extension KeychainPolicy {
    static let session = KeychainPolicy(
        accessibility: kSecAttrAccessibleAfterFirstUnlock,
        accessGroup: nil,
        synchronizable: false,
        service: "smlp.tests.session"
    )
}

final class SessionSecrets: StateContainer {
    @AsyncState(.session) var token: String = ""
}

final class OptionalSecrets: StateContainer {
    @AsyncState(.session) var pin: String? = nil
}

struct SetToken: SyncOperation {
    let value: String
    func perform(in env: SyncOperationEnvironment) {
        env.write(value, keyPath: \SessionSecrets.token)
    }
}

struct SetPin: SyncOperation {
    let value: String?
    func perform(in env: SyncOperationEnvironment) {
        env.write(value, keyPath: \OptionalSecrets.pin)
    }
}

@Suite(.serialized)
@MainActor
struct KeychainLoadTests {

    @Test("Missing Keychain item settles the Container default")
    func missingItemSettlesDefault() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.read(\SessionSecrets.token) == "")
        guard case .settled = iso.environment.read(\SessionSecrets.$token.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Missing optional item settles nil")
    func missingOptionalSettlesNil() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.read(\OptionalSecrets.pin) == nil)
        guard case .settled = iso.environment.read(\OptionalSecrets.$pin.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Corrupt Keychain data fails Source status and leaves the seed")
    func corruptDataFailsStatus() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        let account = "smkc.\(String(describing: \SessionSecrets.$token))"
        try iso.plantKeychain(Data([0x00, 0x01, 0x02]), account: account)

        #expect(iso.environment.read(\SessionSecrets.token) == "")
        guard case .error(let failure) = iso.environment.read(\SessionSecrets.$token.status) else {
            Issue.record("expected error")
            return
        }
        guard case .decoding = failure else {
            Issue.record("expected decoding")
            return
        }
    }

    @Test("A Sync write persists; a second Environment loads the Value")
    func persistOutLoadsInSecondEnvironment() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.read(\SessionSecrets.token) == "")
        iso.environment.perform(SetToken(value: "secret"))

        let account = "smkc.\(String(describing: \SessionSecrets.$token))"
        try await iso.waitForKeychainPersistOut(account: account)

        let env2 = iso.additionalEnvironment()
        #expect(env2.read(\SessionSecrets.token) == "secret")
        guard case .settled = env2.read(\SessionSecrets.$token.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Optional nil deletes the Keychain item")
    func optionalNilDeletesItem() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\OptionalSecrets.pin)
        iso.environment.perform(SetPin(value: "1234"))
        let account = "smkc.\(String(describing: \OptionalSecrets.$pin))"
        try await iso.waitForKeychainPersistOut(account: account)

        iso.environment.perform(SetPin(value: nil))
        try await iso.waitForKeychainRemoval(account: account)

        let env2 = iso.additionalEnvironment()
        #expect(env2.read(\OptionalSecrets.pin) == nil)
        guard case .settled = env2.read(\OptionalSecrets.$pin.status) else {
            Issue.record("expected settled")
            return
        }
    }
}
