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

private let keyedMissingService = uniqueKeychainService()
private let keyedPersistService = uniqueKeychainService()

extension KeychainPolicy {
    static let kcKeyedMissing = KeychainPolicy.testService(keyedMissingService)
    static let kcKeyedPersist = KeychainPolicy.testService(keyedPersistService)
}

final class KCKeyedMissingBag: StateContainer {
    @AsyncState(.kcKeyedMissing) var tokens: [String: String] = [:]
}

final class KCKeyedPersistBag: StateContainer {
    @AsyncState(.kcKeyedPersist) var tokens: [String: String] = [:]
}

@MainActor
struct KeychainKeyedTests {

    @Test("A missing keyed entry settles nil")
    func missingKeyedEntrySettlesNil() throws {
        defer { removeKeychainItems(service: keyedMissingService) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\KCKeyedMissingBag.tokens, key: "missing") == nil)
        guard case .settled = env.snapshot(\KCKeyedMissingBag.$tokens.status, key: "missing") else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("A keyed Sync write persists; a second Environment loads that key")
    func keyedPersistOutLoadsInSecondEnvironment() async throws {
        defer { removeKeychainItems(service: keyedPersistService) }
        let env = SharedEnvironment()

        env.preheat(\KCKeyedPersistBag.$tokens, keys: ["a"])
        env.perform(WriteEntry(path: \KCKeyedPersistBag.tokens, key: "a", value: "one"))

        let identity = KeychainPolicy.kcKeyedPersist.identity
        let account = keychainAccount(\KCKeyedPersistBag.$tokens, key: "a")
        try await waitFor { keychainData(identity: identity, account: account) != nil }

        let env2 = SharedEnvironment()
        #expect(env2.snapshot(\KCKeyedPersistBag.tokens, key: "a") == "one")
        guard case .settled = env2.snapshot(\KCKeyedPersistBag.$tokens.status, key: "a") else {
            Issue.record("expected settled")
            return
        }
    }
}
