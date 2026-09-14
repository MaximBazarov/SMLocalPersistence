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

private let preheatService = uniqueKeychainService()
private let noRowService = uniqueKeychainService()
private let blindWriteService = uniqueKeychainService()

extension KeychainPolicy {
    static let kcPreheat = KeychainPolicy.testService(preheatService)
    static let kcNoRow = KeychainPolicy.testService(noRowService)
    static let kcBlindWrite = KeychainPolicy.testService(blindWriteService)
}

final class KCPreheatSecrets: StateContainer {
    @AsyncState(.kcPreheat) var token: String = ""
}

final class KCNoRowSecrets: StateContainer {
    @AsyncState(.kcNoRow) var token: String = ""
}

final class KCBlindWriteSecrets: StateContainer {
    @AsyncState(.kcBlindWrite) var token: String = ""
}

@Suite(.enabled(if: keychainStoreAvailable, "this runner has no keychain entitlement"))
@MainActor
struct KeychainStrategyTests {

    @Test("Preheat loads with no prior read")
    func preheatLoadsWithNoPriorRead() throws {
        defer { removeKeychainItems(service: preheatService) }
        let env = SharedEnvironment()

        env.preheat(\KCPreheatSecrets.$token)

        #expect(env.snapshot(\KCPreheatSecrets.token) == "")
        guard case .settled = env.snapshot(\KCPreheatSecrets.$token.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Missing onRead does not create a Keychain item")
    func missingOnReadDoesNotWrite() async throws {
        defer { removeKeychainItems(service: noRowService) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\KCNoRowSecrets.token) == "")

        let identity = KeychainPolicy.kcNoRow.identity
        let account = keychainAccount(\KCNoRowSecrets.$token)
        await #expect(throws: TimedOut.self) {
            try await waitFor(timeout: .milliseconds(200)) {
                keychainData(identity: identity, account: account) != nil
            }
        }
    }

    @Test("A Sync write persists without a prior read")
    func writeWithoutPriorReadPersists() async throws {
        defer { removeKeychainItems(service: blindWriteService) }
        let env = SharedEnvironment()

        env.perform(WriteValue(path: \KCBlindWriteSecrets.token, value: "secret"))

        let identity = KeychainPolicy.kcBlindWrite.identity
        let account = keychainAccount(\KCBlindWriteSecrets.$token)
        try await waitFor { keychainData(identity: identity, account: account) != nil }

        #expect(SharedEnvironment().snapshot(\KCBlindWriteSecrets.token) == "secret")
    }
}
