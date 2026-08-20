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
    /// Atomic sourced Value. Status starts `.pending`. Passes ``UserDefaultsPolicy`` to the Source.
    @_disfavoredOverload
    public convenience init(wrappedValue: Value, _ policy: UserDefaultsPolicy)
        where Status == SourceStatus<UserDefaultsSource.Failure> {
        self.init(wrappedValue: wrappedValue, policy: policy)
    }

    /// Keyed sourced Value. Per-key status starts missing and is seeded `.pending` on first read.
    public convenience init<Key: Hashable, Output>(
        wrappedValue: [Key: Output],
        _ policy: UserDefaultsPolicy
    ) where Value == [Key: Output], Status == [Key: SourceStatus<UserDefaultsSource.Failure>] {
        self.init(wrappedValue: wrappedValue, policy: policy)
    }
}
