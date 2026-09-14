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

private let keyedMissingSuite = uniqueSuiteName()
private let keyedPersistSuite = uniqueSuiteName()

final class UDKeyedMissingFlags: StateContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: keyedMissingSuite)) var flags: [String: Bool] = [:]
}

final class UDKeyedPersistFlags: StateContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: keyedPersistSuite)) var flags: [String: Bool] = [:]
}

@MainActor
struct UserDefaultsKeyedTests {

    @Test("A missing keyed entry settles nil")
    func missingKeyedEntrySettlesNil() throws {
        defer { removeUserDefaultsSuite(keyedMissingSuite) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\UDKeyedMissingFlags.flags, key: "missing") == nil)
        guard case .settled = env.snapshot(\UDKeyedMissingFlags.$flags.status, key: "missing") else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("A keyed Sync write persists; a second Environment loads that key")
    func keyedPersistOutLoadsInSecondEnvironment() async throws {
        defer { removeUserDefaultsSuite(keyedPersistSuite) }
        let env = SharedEnvironment()

        env.preheat(\UDKeyedPersistFlags.$flags, keys: ["a"])
        env.perform(WriteEntry(path: \UDKeyedPersistFlags.flags, key: "a", value: true))

        let defaults = try #require(UserDefaults(suiteName: keyedPersistSuite))
        let key = userDefaultsKey(\UDKeyedPersistFlags.$flags, key: "a")
        try await waitFor { defaults.data(forKey: key) != nil }

        let env2 = SharedEnvironment()
        #expect(env2.snapshot(\UDKeyedPersistFlags.flags, key: "a") == true)
        guard case .settled = env2.snapshot(\UDKeyedPersistFlags.$flags.status, key: "a") else {
            Issue.record("expected settled")
            return
        }
    }
}
