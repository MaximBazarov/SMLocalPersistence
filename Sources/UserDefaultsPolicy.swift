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
public enum UserDefaultsPolicy: Sendable {
    /// Selects ``UserDefaultsSource``.
    case userDefaults
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
