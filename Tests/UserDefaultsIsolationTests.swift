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
struct UserDefaultsIsolationTests {

    @Test("Different suites do not share Values")
    func differentSuitesDoNotShare() async throws {
        let (envA, defaultsA, suiteA) = try isolatedSuite()
        defer { defaultsA.removePersistentDomain(forName: suiteA) }
        let (envB, defaultsB, suiteB) = try isolatedSuite()
        defer { defaultsB.removePersistentDomain(forName: suiteB) }

        #expect(envA.read(\ThemePrefs.theme) == "system")
        envA.perform(SetTheme(value: "dark"))
        try await waitForUserDefaultsData(
            defaultsA,
            key: "smud.\(String(describing: \ThemePrefs.theme))"
        )

        #expect(envB.read(\ThemePrefs.theme) == "system")
        guard case .settled = envB.read(\ThemePrefs.$theme.status) else {
            Issue.record("expected settled")
            return
        }
    }
}
