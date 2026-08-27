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
import Testing
import StateManagement
@testable import SMLocalPersistence

@Suite(.serialized)
@MainActor
struct KeychainStrategyTests {

    @Test("Preheat loads with no prior read")
    func preheatLoadsWithNoPriorRead() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\SessionSecrets.token)

        #expect(iso.environment.read(\SessionSecrets.token) == "")
        guard case .settled = iso.environment.read(\SessionSecrets.$token.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("A Sync write persists without a prior read")
    func writeWithoutPriorReadPersists() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.perform(SetToken(value: "secret"))
        let account = "smkc.\(String(describing: \SessionSecrets.$token))"
        try await iso.waitForKeychainPersistOut(account: account)

        #expect(iso.additionalEnvironment().read(\SessionSecrets.token) == "secret")
    }

    @Test("Missing onRead does not create a Keychain item")
    func missingOnReadDoesNotWrite() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.read(\SessionSecrets.token) == "")
        let account = "smkc.\(String(describing: \SessionSecrets.$token))"
        await #expect(throws: PersistOutTimeout.self) {
            try await iso.waitForKeychainPersistOut(account: account)
        }
    }
}
