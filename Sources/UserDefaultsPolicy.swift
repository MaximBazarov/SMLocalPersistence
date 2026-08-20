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

/// Policy for ``UserDefaultsSource``. Call site `@AsyncState(.userDefaults)`.
///
/// Shipped ``userDefaults`` is `.standard`. A named suite is ``init(suiteName:)``. Empty name is
/// `preconditionFailure`. IsolatedPersistence overlays Persistence identity at `provide`.
public struct UserDefaultsPolicy: Sendable, Equatable {
    enum Identity: Sendable, Equatable {
        case standard
        case suite(String)
    }

    let identity: Identity

    private init(identity: Identity) {
        self.identity = identity
    }

    /// Selects ``UserDefaultsSource``. Persistence identity is `UserDefaults.standard`.
    public static let userDefaults = UserDefaultsPolicy(identity: .standard)

    /// Named UserDefaults suite. Empty name is `preconditionFailure`.
    public init(suiteName: String) {
        guard !suiteName.isEmpty else {
            preconditionFailure("UserDefaultsPolicy suiteName must not be empty")
        }
        identity = .suite(suiteName)
    }

    func makeUserDefaults() -> UserDefaults {
        switch identity {
        case .standard:
            return .standard
        case .suite(let name):
            guard let defaults = UserDefaults(suiteName: name) else {
                preconditionFailure("UserDefaultsPolicy suiteName \(name) failed")
            }
            return defaults
        }
    }
}

extension AsyncState where S == UserDefaultsSource {
    /// Pins `S` to ``UserDefaultsSource``.
    @_disfavoredOverload
    public convenience init(wrappedValue: Value, _ policy: UserDefaultsPolicy)
        where Status == SourceStatus<UserDefaultsSource.Failure> {
        self.init(wrappedValue: wrappedValue, policy: policy)
    }

    /// Pins `S` to ``UserDefaultsSource``.
    public convenience init<Key: Hashable, Output>(
        wrappedValue: [Key: Output],
        _ policy: UserDefaultsPolicy
    ) where Value == [Key: Output], Status == [Key: SourceStatus<UserDefaultsSource.Failure>] {
        self.init(wrappedValue: wrappedValue, policy: policy)
    }
}
