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
struct UserDefaultsStrategyTests {

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

    @Test("Missing onRead does not write the suite")
    func missingOnReadDoesNotWriteSuite() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.read(\ThemePrefs.theme) == "system")
        let key = "smud.\(String(describing: \ThemePrefs.theme))"
        await #expect(throws: PersistOutTimeout.self) {
            try await iso.waitForPersistOut(key: key)
        }
    }

    @Test("A Sync write persists without a prior read")
    func writeWithoutPriorReadPersists() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.perform(SetTheme(value: "dark"))
        let key = "smud.\(String(describing: \ThemePrefs.theme))"
        try await iso.waitForPersistOut(key: key)

        #expect(iso.additionalEnvironment().read(\ThemePrefs.theme) == "dark")
    }
}
