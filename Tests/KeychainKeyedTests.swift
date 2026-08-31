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

final class TokenBag: StateContainer {
    @AsyncState(.session) var tokens: [String: String] = [:]
}

struct SetBagToken: SyncOperation {
    let key: String
    let value: String
    func perform(in env: SyncOperationEnvironment) {
        env.write(value, keyPath: \TokenBag.tokens, key: key)
    }
}

@Suite(.serialized)
@MainActor
struct KeychainKeyedTests {

    @Test("A keyed Sync write persists; a second Environment loads that key")
    func keyedPersistOutLoadsInSecondEnvironment() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\TokenBag.tokens, key: "a")
        iso.environment.perform(SetBagToken(key: "a", value: "one"))

        let account = "smkc.\(String(describing: \TokenBag.$tokens))#a"
        try await iso.waitForKeychainPersistOut(account: account)

        let env2 = iso.additionalEnvironment()
        #expect(env2.read(\TokenBag.tokens, key: "a") == "one")
        guard case .settled = env2.read(\TokenBag.$tokens.status, key: "a") else {
            Issue.record("expected settled")
            return
        }
    }
}
