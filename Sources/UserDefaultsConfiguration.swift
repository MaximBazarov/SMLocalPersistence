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
import StateManagement

/// Holds the `UserDefaults` instance this Environment loads from and persists to. Default `.standard`.
public final class UserDefaultsConfiguration: StateContainer {
    public var defaults: UserDefaults = .standard

    public init() {}
}

/// Replaces the `UserDefaults` instance. Perform before first load. Tests and previews use a named suite.
public struct UseUserDefaults: SyncOperation {
    let defaults: UserDefaults

    public init(_ defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func perform(in env: SyncOperationEnvironment) {
        env.write(defaults, keyPath: \UserDefaultsConfiguration.defaults)
    }
}

/// Clears a named suite’s persistent domain. Does not clear `.standard`.
public struct ClearUserDefaultsSuite: SyncOperation {
    let suiteName: String

    public init(suiteName: String) {
        self.suiteName = suiteName
    }

    public func perform(in env: SyncOperationEnvironment) {
        precondition(!suiteName.isEmpty, "ClearUserDefaultsSuite suiteName must not be empty")
        if let bundleID = Bundle.main.bundleIdentifier {
            precondition(
                suiteName != bundleID,
                "ClearUserDefaultsSuite refuses this process’s bundle identifier"
            )
        }
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
    }
}
