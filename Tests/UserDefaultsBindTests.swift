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
struct UserDefaultsBindTests {

    @Test("Preheat loads with no prior read")
    func preheatBinds() throws {
        let (env, defaults, suiteName) = try isolatedSuite()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        env.preheat(\ThemePrefs.theme)

        #expect(env.read(\ThemePrefs.theme) == "system")
        guard case .settled = env.read(\ThemePrefs.$theme.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Seed before first read does not write the suite")
    func seedBeforeBindDoesNotWriteSuite() throws {
        let (env, defaults, suiteName) = try isolatedSuite()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        env.perform(SetTheme(value: "dark"))

        let key = "smud.\(String(describing: \ThemePrefs.theme))"
        #expect(defaults.data(forKey: key) == nil)
    }
}
