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

/// Load failure for ``JSONFileStrategy``. Missing is not a case.
public enum JSONFileFailure: Error {
    case decoding(DecodingError)
    case io
}

/// Policy for ``JSONFileStrategy``. The app declares a static. No shipped `.jsonFile`.
///
/// Persistence identity is the `root`, resolved at `onRead`.
public struct JSONFilePolicy: Sendable, Equatable {
    public let root: URL

    /// `root` is required. Empty path is `preconditionFailure`.
    public init(root: URL) {
        guard !root.path.isEmpty else {
            preconditionFailure("JSONFilePolicy root must not be empty")
        }
        self.root = root
    }
}

extension AsyncState where S == JSONFileStrategy {
    /// Pins `S` to ``JSONFileStrategy``.
    @_disfavoredOverload
    public convenience init(wrappedValue: Value, _ policy: JSONFilePolicy)
        where Key == NoKey, Entry == Value {
        self.init(wrappedValue: wrappedValue, policy: policy)
    }

    /// Pins `S` to ``JSONFileStrategy``.
    public convenience init(wrappedValue: [Key: Entry], _ policy: JSONFilePolicy)
        where Value == [Key: Entry] {
        self.init(wrappedValue: wrappedValue, policy: policy)
    }
}
