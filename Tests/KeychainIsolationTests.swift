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
    static let iCloud = KeychainPolicy(
        accessibility: kSecAttrAccessibleAfterFirstUnlock,
        accessGroup: "group.com.statemanagement.fake",
        synchronizable: true,
        service: "smlp.tests.icloud"
    )
}

final class iCloudSecrets: StateContainer {
    @AsyncState(.iCloud) var token: String = ""
}

struct SetiCloudToken: SyncOperation {
    let value: String
    func perform(in env: SyncOperationEnvironment) {
        env.write(value, keyPath: \iCloudSecrets.token)
    }
}

@Suite(.serialized)
@MainActor
struct KeychainIsolationTests {

    @Test("IsolatedPersistence Sync write does not write the app Keychain service")
    func isolatedWriteDoesNotTouchAppService() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.read(\SessionSecrets.token) == "")
        iso.environment.perform(SetToken(value: "secret"))
        let account = "smkc.\(String(describing: \SessionSecrets.token))"
        try await iso.waitForKeychainPersistOut(account: account)

        #expect(iso.additionalEnvironment().read(\SessionSecrets.token) == "secret")

        let production = SharedEnvironment()
        #expect(production.read(\SessionSecrets.token) == "")
    }

    @Test("Different IsolatedPersistence instances do not share Values")
    func differentIsolatesDoNotShare() async throws {
        let isoA = IsolatedPersistence()
        defer { isoA.clear() }
        let isoB = IsolatedPersistence()
        defer { isoB.clear() }

        #expect(isoA.environment.read(\SessionSecrets.token) == "")
        isoA.environment.perform(SetToken(value: "secret"))
        try await isoA.waitForKeychainPersistOut(
            account: "smkc.\(String(describing: \SessionSecrets.token))"
        )

        #expect(isoB.environment.read(\SessionSecrets.token) == "")
        guard case .settled = isoB.environment.read(\SessionSecrets.$token.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Isolation overlays an app static and forces synchronizable false and no access group")
    func isolationClampsSyncAndAccessGroup() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\iCloudSecrets.token)
        iso.environment.perform(SetiCloudToken(value: "secret"))
        let account = "smkc.\(String(describing: \iCloudSecrets.token))"
        try await iso.waitForKeychainPersistOut(account: account)

        let env2 = iso.additionalEnvironment()
        #expect(env2.read(\iCloudSecrets.token) == "secret")
        guard case .settled = env2.read(\iCloudSecrets.$token.status) else {
            Issue.record("expected settled")
            return
        }

        let production = SharedEnvironment()
        #expect(production.read(\iCloudSecrets.token) == "")
    }

    @Test("clear deletes IsolatedPersistence Keychain items")
    func clearDeletesKeychainItems() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }
        let account = "smkc.\(String(describing: \SessionSecrets.token))"

        #expect(iso.environment.read(\SessionSecrets.token) == "")
        iso.environment.perform(SetToken(value: "secret"))
        try await iso.waitForKeychainPersistOut(account: account)

        iso.clear()
        #expect(iso.additionalEnvironment().read(\SessionSecrets.token) == "")
    }

    #if DEBUG
    @Test("IsolatedPersistence.seed persists sourced Keychain Writes")
    func seedPersistsKeychainWrites() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }
        let account = "smkc.\(String(describing: \SessionSecrets.token))"

        iso.seed {
            Write(\SessionSecrets.token, "secret")
        }
        iso.environment.preheat(\SessionSecrets.token)
        try await iso.waitForKeychainPersistOut(account: account)

        #expect(iso.additionalEnvironment().read(\SessionSecrets.token) == "secret")
    }
    #endif

    #if os(macOS)
    @Test("Empty KeychainPolicy service traps")
    func emptyServiceTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = KeychainPolicy(
                accessibility: kSecAttrAccessibleAfterFirstUnlock,
                accessGroup: nil,
                synchronizable: false,
                service: ""
            )
        }
    }
    #endif
}
