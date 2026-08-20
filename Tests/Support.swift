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

struct SetTheme: SyncOperation {
    let value: String
    func perform(in env: SyncOperationEnvironment) {
        env.write(value, keyPath: \ThemePrefs.theme)
    }
}

@MainActor
func isolatedSuite() throws -> (env: SharedEnvironment, defaults: UserDefaults, suiteName: String) {
    let suiteName = "smud.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let env = SharedEnvironment()
    env.perform(UseUserDefaults(defaults))
    return (env, defaults, suiteName)
}

@MainActor
func waitForUserDefaultsData(_ defaults: UserDefaults, key: String) async throws {
    let deadline = ContinuousClock.now + .seconds(1)
    while ContinuousClock.now < deadline {
        if defaults.data(forKey: key) != nil {
            return
        }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("timed out waiting for UserDefaults key \(key)")
}
