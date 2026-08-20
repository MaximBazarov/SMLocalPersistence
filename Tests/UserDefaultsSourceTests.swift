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
struct UserDefaultsSourceTests {

    @Test("Preheat loads with no prior read")
    func preheatLoadsWithNoPriorRead() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\ThemePrefs.theme)

        #expect(iso.environment.read(\ThemePrefs.theme) == "system")
        guard case .settled = iso.environment.read(\ThemePrefs.$theme.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Seed before first read does not write the suite")
    func seedBeforeProvideDoesNotWriteSuite() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.perform(SetTheme(value: "dark"))

        let key = "smud.\(String(describing: \ThemePrefs.theme))"
        #expect(iso.defaults.data(forKey: key) == nil)
        #expect(iso.additionalEnvironment().read(\ThemePrefs.theme) == "system")
    }
}
