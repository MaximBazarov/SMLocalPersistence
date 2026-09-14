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

// One test Container per test; Persistence identity is a unique suite through the
// public Policy initializer (P16). Real store, no overlay.

private let missingSuite = uniqueSuiteName()
private let missingOptionalSuite = uniqueSuiteName()
private let corruptSuite = uniqueSuiteName()
private let persistSuite = uniqueSuiteName()
private let deleteSuite = uniqueSuiteName()

final class UDMissingPrefs: StateContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: missingSuite)) var theme: String = "system"
}

final class UDMissingOptionalPrefs: StateContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: missingOptionalSuite)) var nickname: String? = nil
}

final class UDCorruptPrefs: StateContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: corruptSuite)) var theme: String = "system"
}

final class UDPersistPrefs: StateContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: persistSuite)) var theme: String = "system"
}

final class UDDeletePrefs: StateContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: deleteSuite)) var nickname: String? = nil
}

@MainActor
struct UserDefaultsLoadTests {

    @Test("Missing UserDefaults key settles the Container default")
    func missingKeySettlesDefault() throws {
        defer { removeUserDefaultsSuite(missingSuite) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\UDMissingPrefs.theme) == "system")
        guard case .settled = env.snapshot(\UDMissingPrefs.$theme.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Missing optional key settles nil")
    func missingOptionalSettlesNil() throws {
        defer { removeUserDefaultsSuite(missingOptionalSuite) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\UDMissingOptionalPrefs.nickname) == nil)
        guard case .settled = env.snapshot(\UDMissingOptionalPrefs.$nickname.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Corrupt UserDefaults data fails async state status and leaves the seed")
    func corruptDataFailsStatus() throws {
        defer { removeUserDefaultsSuite(corruptSuite) }
        let defaults = try #require(UserDefaults(suiteName: corruptSuite))
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: userDefaultsKey(\UDCorruptPrefs.$theme))

        let env = SharedEnvironment()
        #expect(env.snapshot(\UDCorruptPrefs.theme) == "system")
        guard case .error = env.snapshot(\UDCorruptPrefs.$theme.status) else {
            Issue.record("expected error")
            return
        }
    }

    @Test("A Sync write persists; a second Environment loads the Value")
    func persistOutLoadsInSecondEnvironment() async throws {
        defer { removeUserDefaultsSuite(persistSuite) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\UDPersistPrefs.theme) == "system")
        env.perform(WriteValue(path: \UDPersistPrefs.theme, value: "dark"))

        let defaults = try #require(UserDefaults(suiteName: persistSuite))
        let key = userDefaultsKey(\UDPersistPrefs.$theme)
        try await waitFor { defaults.data(forKey: key) != nil }

        let env2 = SharedEnvironment()
        #expect(env2.snapshot(\UDPersistPrefs.theme) == "dark")
        guard case .settled = env2.snapshot(\UDPersistPrefs.$theme.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Optional nil deletes the UserDefaults key")
    func optionalNilDeletesKey() async throws {
        defer { removeUserDefaultsSuite(deleteSuite) }
        let env = SharedEnvironment()
        let defaults = try #require(UserDefaults(suiteName: deleteSuite))
        let key = userDefaultsKey(\UDDeletePrefs.$nickname)

        env.preheat(\UDDeletePrefs.$nickname)
        env.perform(WriteValue(path: \UDDeletePrefs.nickname, value: "ada" as String?))
        try await waitFor { defaults.data(forKey: key) != nil }

        env.perform(WriteValue(path: \UDDeletePrefs.nickname, value: nil as String?))
        try await waitFor { defaults.data(forKey: key) == nil }

        let env2 = SharedEnvironment()
        #expect(env2.snapshot(\UDDeletePrefs.nickname) == nil)
        guard case .settled = env2.snapshot(\UDDeletePrefs.$nickname.status) else {
            Issue.record("expected settled")
            return
        }
    }
}
