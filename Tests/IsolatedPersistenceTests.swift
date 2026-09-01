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
struct IsolatedPersistenceTests {

    @Test("IsolatedPersistence Sync write does not write UserDefaults.standard")
    func isolatedWriteDoesNotTouchStandard() async throws {
        let key = "smud.\(String(describing: \ThemePrefs.$theme))"
        let before = UserDefaults.standard.data(forKey: key)
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.snapshot(\ThemePrefs.theme) == "system")
        iso.environment.perform(SetTheme(value: "dark"))
        try await iso.waitForPersistOut(key: key)

        #expect(iso.additionalEnvironment().snapshot(\ThemePrefs.theme) == "dark")
        #expect(UserDefaults.standard.data(forKey: key) == before)
        #expect(iso.environment.snapshot(\ThemePrefs.theme) == "dark")
    }

    @Test("additionalEnvironment reads persisted Values after notify")
    func additionalEnvironmentSeesPersistOut() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }
        let key = "smud.\(String(describing: \ThemePrefs.$theme))"

        iso.environment.preheat(\ThemePrefs.$theme)
        iso.environment.perform(SetTheme(value: "dark"))
        try await iso.waitForPersistOut(key: key)

        let env2 = iso.additionalEnvironment()
        #expect(env2.snapshot(\ThemePrefs.theme) == "dark")
        guard case .settled = env2.snapshot(\ThemePrefs.$theme.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("clear deletes that UUID suite")
    func clearDeletesSuite() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }
        let key = "smud.\(String(describing: \ThemePrefs.$theme))"

        #expect(iso.environment.snapshot(\ThemePrefs.theme) == "system")
        iso.environment.perform(SetTheme(value: "dark"))
        try await iso.waitForPersistOut(key: key)

        iso.clear()
        #expect(iso.additionalEnvironment().snapshot(\ThemePrefs.theme) == "system")
    }

    @Test("SharedEnvironment() stays production")
    func sharedEnvironmentStaysProduction() async throws {
        let key = "smud.\(String(describing: \ThemePrefs.$theme))"
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\ThemePrefs.$theme)
        iso.environment.perform(SetTheme(value: "dark"))
        try await iso.waitForPersistOut(key: key)

        let production = SharedEnvironment()
        #expect(production.snapshot(\ThemePrefs.theme) == "system")
    }

    #if DEBUG
    @Test("IsolatedPersistence.seed persists sourced Writes on that Environment")
    func seedPersistsOnIsolatedEnvironment() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }
        let key = "smud.\(String(describing: \ThemePrefs.$theme))"

        iso.seed {
            Write(\ThemePrefs.theme, "dark")
        }
        iso.environment.preheat(\ThemePrefs.$theme)
        try await iso.waitForPersistOut(key: key)

        #expect(iso.additionalEnvironment().snapshot(\ThemePrefs.theme) == "dark")
    }
    #endif

    @Test("Overlay survives reset")
    func overlaySurvivesReset() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }
        let key = "smud.\(String(describing: \ThemePrefs.$theme))"

        iso.environment.preheat(\ThemePrefs.$theme)
        iso.environment.perform(SetTheme(value: "dark"))
        try await iso.waitForPersistOut(key: key)

        iso.environment.perform(ResetAll())
        #expect(iso.environment.snapshot(\ThemePrefs.theme) == "dark")
    }

    @Test("IsolatedPersistence overlays a named-suite Policy")
    func overlayReplacesNamedSuitePolicy() async throws {
        let named = try #require(UserDefaults(suiteName: NamedSuitePrefs.suiteName))
        named.removePersistentDomain(forName: NamedSuitePrefs.suiteName)
        defer { named.removePersistentDomain(forName: NamedSuitePrefs.suiteName) }

        let iso = IsolatedPersistence()
        defer { iso.clear() }
        let key = "smud.\(String(describing: \NamedSuitePrefs.$theme))"

        iso.environment.preheat(\NamedSuitePrefs.$theme)
        iso.environment.perform(SetNamedSuiteTheme(value: "dark"))
        try await iso.waitForPersistOut(key: key)

        #expect(named.data(forKey: key) == nil)
        #expect(iso.additionalEnvironment().snapshot(\NamedSuitePrefs.theme) == "dark")
    }

    @Test("Production named-suite Policy writes that suite")
    func namedSuitePolicyWritesThatSuite() async throws {
        let suiteName = NamedSuitePrefs.suiteName
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let env = SharedEnvironment()
        #expect(env.snapshot(\NamedSuitePrefs.theme) == "system")
        env.perform(SetNamedSuiteTheme(value: "dark"))
        let key = "smud.\(String(describing: \NamedSuitePrefs.$theme))"
        try await waitForUserDefaultsData(defaults, key: key)

        let env2 = SharedEnvironment()
        #expect(env2.snapshot(\NamedSuitePrefs.theme) == "dark")
    }

    #if os(macOS)
    @Test("Leftover onRead after IsolatedPersistence is gone traps")
    func leftoverOnReadTraps() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let env: SharedEnvironment
                do {
                    let iso = IsolatedPersistence()
                    env = iso.environment
                }
                _ = env.snapshot(\ThemePrefs.theme)
            }
        }
    }

    @Test("Empty UserDefaultsPolicy suiteName traps")
    func emptySuiteNameTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = UserDefaultsPolicy(suiteName: "")
        }
    }
    #endif
}

final class NamedSuitePrefs: StateContainer {
    static let suiteName = "smlp.policy-identity-test"
    @AsyncState(UserDefaultsPolicy(suiteName: "smlp.policy-identity-test")) var theme: String = "system"
}

struct SetNamedSuiteTheme: SyncOperation {
    let value: String
    func perform(in env: SyncOperationEnvironment) {
        env.write(\NamedSuitePrefs.theme, value: value)
    }
}
