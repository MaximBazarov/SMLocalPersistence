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

@Suite(.serialized)
@MainActor
struct UserDefaultsCleanupTests {

    @Test("ClearUserDefaultsSuite empties that suite")
    func clearEmptiesNamedSuite() async throws {
        let (env, defaults, suiteName) = try isolatedSuite()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(env.read(\ThemePrefs.theme) == "system")
        env.perform(SetTheme(value: "dark"))
        let key = "smud.\(String(describing: \ThemePrefs.theme))"
        try await waitForUserDefaultsData(defaults, key: key)

        env.perform(ClearUserDefaultsSuite(suiteName: suiteName))
        #expect(defaults.data(forKey: key) == nil)

        let env2 = SharedEnvironment()
        env2.perform(UseUserDefaults(defaults))
        #expect(env2.read(\ThemePrefs.theme) == "system")
    }
}
