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

/// Bind token for `@AsyncState(.userDefaults)`. The Source is ``UserDefaultsSource``.
public enum UserDefaultsBind: Sendable {
    case userDefaults
}

extension AsyncState where S == UserDefaultsSource {
    /// Atomic sourced Value bound to UserDefaults. Status starts `.pending`.
    @_disfavoredOverload
    public convenience init(wrappedValue: Value, _: UserDefaultsBind)
        where Status == SourceStatus<UserDefaultsSource.Failure> {
        self.init(wrappedValue: wrappedValue, UserDefaultsSource.self)
    }

    /// Keyed sourced Value bound to UserDefaults. Per-key status starts missing and is seeded `.pending` on Bind.
    public convenience init<Key: Hashable, Output>(
        wrappedValue: [Key: Output],
        _: UserDefaultsBind
    ) where Value == [Key: Output], Status == [Key: SourceStatus<UserDefaultsSource.Failure>] {
        self.init(wrappedValue: wrappedValue, UserDefaultsSource.self)
    }
}
