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
struct UserDefaultsCleanupTests {

    @Test("clear empties that suite so a later Environment loads the seed")
    func clearEmptiesSuite() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.read(\ThemePrefs.theme) == "system")
        iso.environment.perform(SetTheme(value: "dark"))
        let key = "smud.\(String(describing: \ThemePrefs.theme))"
        try await waitForPersistOut(iso, key: key)

        iso.clear()
        #expect(iso.additionalEnvironment().read(\ThemePrefs.theme) == "system")
    }
}
