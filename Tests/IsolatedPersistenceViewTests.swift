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

#if canImport(SwiftUI) && DEBUG && (canImport(AppKit) || canImport(UIKit))
import SwiftUI
import Testing
import StateManagement
@testable import SMLocalPersistence

private struct ThemeLabel: View {
    @Watch(\ThemePrefs.theme) var theme
    var body: some View { Text(theme) }
}

@Suite(.serialized)
@MainActor
struct IsolatedPersistenceViewTests {

    @Test("sharedEnvironment(iso) retains IsolatedPersistence and does not write .standard")
    func sharedEnvironmentHandleDoesNotTouchStandard() async throws {
        let key = "smud.\(String(describing: \ThemePrefs.$theme))"
        let before = UserDefaults.standard.data(forKey: key)
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        let host = HostedView.mount(ThemeLabel().sharedEnvironment(iso))
        defer { host.teardown() }

        iso.environment.perform(SetTheme(value: "dark"))
        try await iso.waitForPersistOut(key: key)

        #expect(iso.additionalEnvironment().snapshot(\ThemePrefs.theme) == "dark")
        #expect(UserDefaults.standard.data(forKey: key) == before)
    }

    @Test("sharedEnvironment(.isolatedPersistence) does not write .standard")
    func sharedEnvironmentTokenDoesNotTouchStandard() {
        let key = "smud.\(String(describing: \ThemePrefs.$theme))"
        let before = UserDefaults.standard.data(forKey: key)

        let host = HostedView.mount(ThemeLabel().sharedEnvironment(.isolatedPersistence))
        defer { host.teardown() }

        #expect(UserDefaults.standard.data(forKey: key) == before)
    }

    @Test("seedEnvironment(iso) seeds IsolatedPersistence then injects")
    func seedEnvironmentHandleDoesNotTouchStandard() async throws {
        let key = "smud.\(String(describing: \ThemePrefs.$theme))"
        let before = UserDefaults.standard.data(forKey: key)
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        let host = HostedView.mount(
            ThemeLabel().seedEnvironment(iso) {
                Write(\ThemePrefs.theme, "dark")
            }
        )
        defer { host.teardown() }

        iso.environment.preheat(\ThemePrefs.theme)
        try await iso.waitForPersistOut(key: key)
        #expect(iso.additionalEnvironment().snapshot(\ThemePrefs.theme) == "dark")
        #expect(UserDefaults.standard.data(forKey: key) == before)
    }

    @Test("seedEnvironment(.isolatedPersistence) seeds then injects without writing .standard")
    func seedEnvironmentTokenDoesNotTouchStandard() {
        let key = "smud.\(String(describing: \ThemePrefs.$theme))"
        let before = UserDefaults.standard.data(forKey: key)

        let host = HostedView.mount(
            ThemeLabel().seedEnvironment(.isolatedPersistence) {
                Write(\ThemePrefs.theme, "dark")
            }
        )
        defer { host.teardown() }

        #expect(UserDefaults.standard.data(forKey: key) == before)
    }
}
#endif
