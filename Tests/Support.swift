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

struct SetTheme: SyncOperation {
    let value: String
    func perform(in env: SyncOperationEnvironment) {
        env.write(value, keyPath: \ThemePrefs.theme)
    }
}

struct ResetAll: SyncOperation {
    func perform(in env: SyncOperationEnvironment) {
        env.reset()
    }
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
