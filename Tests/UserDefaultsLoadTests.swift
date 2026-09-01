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

final class ThemePrefs: StateContainer {
    @AsyncState(.userDefaults) var theme: String = "system"
}

final class OptionalPrefs: StateContainer {
    @AsyncState(.userDefaults) var nickname: String? = nil
}

struct SetNickname: SyncOperation {
    let value: String?
    func perform(in env: SyncOperationEnvironment) {
        env.write(\OptionalPrefs.nickname, value: value)
    }
}

@Suite(.serialized)
@MainActor
struct UserDefaultsLoadTests {

    @Test("Missing UserDefaults key settles the Container default")
    func missingKeySettlesDefault() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.snapshot(\ThemePrefs.theme) == "system")
        guard case .settled = iso.environment.snapshot(\ThemePrefs.$theme.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Missing optional key settles nil")
    func missingOptionalSettlesNil() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.snapshot(\OptionalPrefs.nickname) == nil)
        guard case .settled = iso.environment.snapshot(\OptionalPrefs.$nickname.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Corrupt UserDefaults data fails Source status and leaves the seed")
    func corruptDataFailsStatus() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        let key = "smud.\(String(describing: \ThemePrefs.$theme))"
        iso.plant(Data([0x00, 0x01, 0x02]), forKey: key)

        #expect(iso.environment.snapshot(\ThemePrefs.theme) == "system")
        guard case .error = iso.environment.snapshot(\ThemePrefs.$theme.status) else {
            Issue.record("expected error")
            return
        }
    }

    @Test("A Sync write persists; a second Environment loads the Value")
    func persistOutLoadsInSecondEnvironment() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.snapshot(\ThemePrefs.theme) == "system")
        iso.environment.perform(SetTheme(value: "dark"))

        let key = "smud.\(String(describing: \ThemePrefs.$theme))"
        try await iso.waitForPersistOut(key: key)

        let env2 = iso.additionalEnvironment()
        #expect(env2.snapshot(\ThemePrefs.theme) == "dark")
        guard case .settled = env2.snapshot(\ThemePrefs.$theme.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Optional nil deletes the UserDefaults key")
    func optionalNilDeletesKey() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\OptionalPrefs.$nickname)
        iso.environment.perform(SetNickname(value: "ada"))
        let key = "smud.\(String(describing: \OptionalPrefs.$nickname))"
        try await iso.waitForPersistOut(key: key)

        iso.environment.perform(SetNickname(value: nil))
        try await iso.waitForRemoval(key: key)

        let env2 = iso.additionalEnvironment()
        #expect(env2.snapshot(\OptionalPrefs.nickname) == nil)
        guard case .settled = env2.snapshot(\OptionalPrefs.$nickname.status) else {
            Issue.record("expected settled")
            return
        }
    }
}
