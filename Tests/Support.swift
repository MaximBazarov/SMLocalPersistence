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
import StateManagementTestingSupport

struct SetTheme: SyncOperation {
    let value: String
    func perform(in env: SyncOperationEnvironment) {
        env.write(\ThemePrefs.theme, value: value)
    }
}

@MainActor
extension SharedEnvironment {

    /// Snapshots a Value for an assertion, through `StateReader`.
    ///
    /// A read is public only where the caller is known, so `SharedEnvironment` has none and a
    /// Satellite does not reach the core with `@testable`. `StateReader` is the sanctioned reader
    /// because it is an `EnvironmentService`, and therefore a Restricted Environment.
    ///
    /// Deliberately not named `read`: that would shadow the core's internal one and read like
    /// public API. A fresh reader per call keeps the subscription from outliving the assertion —
    /// the receiver holds the reader weakly, so it goes quiet as soon as this returns.
    func snapshot<S: StateContainer, V>(_ keyPath: KeyPath<S, V>) -> V {
        StateReader(env: self).read(keyPath)
    }

    /// Snapshots one key of a Keyed value. Same reasoning as ``snapshot(_:)``.
    func snapshot<S: StateContainer, K: Hashable, V>(
        _ keyPath: KeyPath<S, [K: V]>,
        key: K
    ) -> V? {
        StateReader(env: self).read(keyPath, key: key)
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
