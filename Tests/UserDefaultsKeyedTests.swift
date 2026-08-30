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

final class FlagPrefs: StateContainer {
    @AsyncState(.userDefaults) var flags: [String: Bool] = [:]
}

struct SetFlag: SyncOperation {
    let key: String
    let value: Bool
    func perform(in env: SyncOperationEnvironment) {
        env.write(\FlagPrefs.flags, key: key, value: value)
    }
}

@Suite(.serialized)
@MainActor
struct UserDefaultsKeyedTests {

    @Test("A keyed Sync write persists; a second Environment loads that key")
    func keyedPersistOutLoadsInSecondEnvironment() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\FlagPrefs.flags, key: "a")
        iso.environment.perform(SetFlag(key: "a", value: true))

        let key = "smud.\(String(describing: \FlagPrefs.$flags))#a"
        try await iso.waitForPersistOut(key: key)

        let env2 = iso.additionalEnvironment()
        #expect(env2.read(\FlagPrefs.flags, key: "a") == true)
        guard case .settled = env2.read(\FlagPrefs.$flags.status, key: "a") else {
            Issue.record("expected settled")
            return
        }
    }
}
