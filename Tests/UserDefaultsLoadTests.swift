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
import SMLocalPersistence

final class ThemePrefs: StateContainer {
    @AsyncState(.userDefaults) var theme: String = "system"
}

final class OptionalPrefs: StateContainer {
    @AsyncState(.userDefaults) var nickname: String? = nil
}

@Suite(.serialized)
@MainActor
struct UserDefaultsLoadTests {

    @Test("Missing UserDefaults key settles the Container default")
    func missingKeySettlesDefault() throws {
        let (env, defaults, suiteName) = try isolatedSuite()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(env.read(\ThemePrefs.theme) == "system")
        guard case .settled = env.read(\ThemePrefs.$theme.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Missing optional key settles nil")
    func missingOptionalSettlesNil() throws {
        let (env, defaults, suiteName) = try isolatedSuite()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(env.read(\OptionalPrefs.nickname) == nil)
        guard case .settled = env.read(\OptionalPrefs.$nickname.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Corrupt UserDefaults data fails Source status and leaves the seed")
    func corruptDataFailsStatus() throws {
        let (env, defaults, suiteName) = try isolatedSuite()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let key = "smud.\(String(describing: \ThemePrefs.theme))"
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: key)

        #expect(env.read(\ThemePrefs.theme) == "system")
        guard case .error = env.read(\ThemePrefs.$theme.status) else {
            Issue.record("expected error")
            return
        }
    }

    @Test("A Sync write persists; a second Environment loads the Value")
    func persistOutLoadsInSecondEnvironment() async throws {
        let (env, defaults, suiteName) = try isolatedSuite()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(env.read(\ThemePrefs.theme) == "system")
        env.perform(SetTheme(value: "dark"))

        let key = "smud.\(String(describing: \ThemePrefs.theme))"
        try await waitForUserDefaultsData(defaults, key: key)

        let env2 = SharedEnvironment()
        env2.perform(UseUserDefaults(defaults))
        #expect(env2.read(\ThemePrefs.theme) == "dark")
        guard case .settled = env2.read(\ThemePrefs.$theme.status) else {
            Issue.record("expected settled")
            return
        }
    }
}
