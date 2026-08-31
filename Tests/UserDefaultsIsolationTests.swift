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
struct UserDefaultsIsolationTests {

    @Test("Different IsolatedPersistence instances do not share Values")
    func differentIsolatesDoNotShare() async throws {
        let isoA = IsolatedPersistence()
        defer { isoA.clear() }
        let isoB = IsolatedPersistence()
        defer { isoB.clear() }

        #expect(isoA.environment.snapshot(\ThemePrefs.theme) == "system")
        isoA.environment.perform(SetTheme(value: "dark"))
        try await isoA.waitForPersistOut(
            key: "smud.\(String(describing: \ThemePrefs.$theme))"
        )

        #expect(isoB.environment.snapshot(\ThemePrefs.theme) == "system")
        guard case .settled = isoB.environment.snapshot(\ThemePrefs.$theme.status) else {
            Issue.record("expected settled")
            return
        }
    }
}
