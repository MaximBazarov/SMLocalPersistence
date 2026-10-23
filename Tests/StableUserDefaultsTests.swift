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

private let stableWriteSuite = uniqueSuiteName()
private let stableLoadSuite = uniqueSuiteName()
private let stableDeleteSuite = uniqueSuiteName()

final class StableWritePrefs: StableUserDefaultsContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: stableWriteSuite)) var theme = "system"
    @AsyncState(UserDefaultsPolicy(suiteName: stableWriteSuite)) var flags: [String: Bool] = [:]

    static var userDefaultsAddresses: [AnyKeyPath: String] {
        [\StableWritePrefs._theme: "prefs.theme", \StableWritePrefs.$theme: "prefs.theme",
         \StableWritePrefs._flags: "prefs.flags", \StableWritePrefs.$flags: "prefs.flags"]
    }
}

final class StableLoadPrefs: StableUserDefaultsContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: stableLoadSuite)) var theme = "system"
    @AsyncState(UserDefaultsPolicy(suiteName: stableLoadSuite)) var flags: [String: Bool] = [:]

    static var userDefaultsAddresses: [AnyKeyPath: String] {
        [\StableLoadPrefs._theme: "prefs.theme", \StableLoadPrefs.$theme: "prefs.theme",
         \StableLoadPrefs._flags: "prefs.flags", \StableLoadPrefs.$flags: "prefs.flags"]
    }
}

final class StableDeletePrefs: StableUserDefaultsContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: stableDeleteSuite)) var nickname: String? = nil

    static var userDefaultsAddresses: [AnyKeyPath: String] {
        [\StableDeletePrefs._nickname: "prefs.nickname", \StableDeletePrefs.$nickname: "prefs.nickname"]
    }
}

@MainActor
struct StableUserDefaultsTests {
    @Test("Atomic and keyed writes use permanent addresses and load in a fresh Environment")
    func writesUsePermanentAddresses() async throws {
        defer { removeUserDefaultsSuite(stableWriteSuite) }
        let defaults = try #require(UserDefaults(suiteName: stableWriteSuite))
        let env = SharedEnvironment()
        env.perform(WriteValue(path: \StableWritePrefs.theme, value: "dark"))
        env.perform(WriteEntry(path: \StableWritePrefs.flags, key: "あ", value: true))
        try await waitFor {
            defaults.data(forKey: "smud.prefs.theme") != nil &&
            defaults.data(forKey: "smud.prefs.flags#あ") != nil
        }
        #expect(try decodeUserDefaultsValue(String.self, from: #require(defaults.data(forKey: "smud.prefs.theme"))) == "dark")
        #expect(try decodeUserDefaultsValue(Bool.self, from: #require(defaults.data(forKey: "smud.prefs.flags#あ"))) == true)
        let fresh = SharedEnvironment()
        #expect(fresh.snapshot(\StableWritePrefs.theme) == "dark")
        #expect(fresh.snapshot(\StableWritePrefs.flags, key: "あ") == true)
    }

    @Test("Previously stored permanent addresses load without reading unstable legacy keys")
    func loadsExistingPermanentAddresses() throws {
        defer { removeUserDefaultsSuite(stableLoadSuite) }
        let defaults = try #require(UserDefaults(suiteName: stableLoadSuite))
        let theme = try encodeUserDefaultsValue("dark")
        let flag = try encodeUserDefaultsValue(true)
        let legacyKey = "smud.\\StableLoadPrefs.<computed 0x100123456 (String)>"
        let legacy = try encodeUserDefaultsValue("legacy")
        defaults.set(theme, forKey: "smud.prefs.theme")
        defaults.set(flag, forKey: "smud.prefs.flags#あ")
        defaults.set(legacy, forKey: legacyKey)
        let env = SharedEnvironment()
        #expect(env.snapshot(\StableLoadPrefs.theme) == "dark")
        #expect(env.snapshot(\StableLoadPrefs.flags, key: "あ") == true)
        #expect(defaults.data(forKey: "smud.prefs.theme") == theme)
        #expect(defaults.data(forKey: legacyKey) == legacy)
    }

    @Test("Deleting an optional removes its permanent key and stays deleted")
    func deletionUsesPermanentAddress() async throws {
        defer { removeUserDefaultsSuite(stableDeleteSuite) }
        let defaults = try #require(UserDefaults(suiteName: stableDeleteSuite))
        defaults.set(try encodeUserDefaultsValue("ada"), forKey: "smud.prefs.nickname")
        let env = SharedEnvironment()
        #expect(env.snapshot(\StableDeletePrefs.nickname) == "ada")
        env.perform(WriteValue(path: \StableDeletePrefs.nickname, value: nil as String?))
        try await waitFor { defaults.data(forKey: "smud.prefs.nickname") == nil }
        #expect(SharedEnvironment().snapshot(\StableDeletePrefs.nickname) == nil)
    }
}
