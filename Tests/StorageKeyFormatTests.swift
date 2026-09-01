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

final class KeyFormatPrefs: StateContainer {
    @AsyncState(.userDefaults) var theme: String = "system"
    @AsyncState(.userDefaults) var flags: [String: Bool] = [:]
}

/// The storage key is what a store already holds, so its shape is a compatibility promise, not an
/// implementation detail. Every key is derived from the `$` Address; that a Value-first kick,
/// which arrives spelled `_theme`, still names the same item is pinned by the persist-out suites.
@Suite @MainActor
struct StorageKeyFormatTests {

    @Test("UserDefaults keys are smud plus the $ Address")
    func userDefaultsKeyFormat() {
        #expect(userDefaultsKey(\KeyFormatPrefs.$theme) == "smud.\\KeyFormatPrefs.$theme")
        #expect(userDefaultsKey(\KeyFormatPrefs.$flags, key: "a") == "smud.\\KeyFormatPrefs.$flags#a")
    }

    @Test("Keychain accounts are smkc plus the $ Address")
    func keychainAccountFormat() {
        #expect(keychainAccount(\KeyFormatPrefs.$theme) == "smkc.\\KeyFormatPrefs.$theme")
        #expect(keychainAccount(\KeyFormatPrefs.$flags, key: "a") == "smkc.\\KeyFormatPrefs.$flags#a")
    }

    @Test("JSON files are the Container folder and the percent-encoded $ Address")
    func jsonFileLocationFormat() {
        let atomic = jsonFileLocation(\KeyFormatPrefs.$theme)
        #expect(atomic.folder == "SMLocalPersistenceTests.KeyFormatPrefs")
        #expect(atomic.file == "%5CKeyFormatPrefs.%24theme")

        let keyed = jsonFileLocation(\KeyFormatPrefs.$flags, key: "a")
        #expect(keyed.file == "%5CKeyFormatPrefs.%24flags%23a")
    }
}
