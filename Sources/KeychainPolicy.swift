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
import Security
import StateManagement

/// Load failure for ``KeychainStrategy``. Missing is not a case.
public enum KeychainFailure: Error {
    case osStatus(OSStatus)
    case decoding(DecodingError)
}

/// Policy for ``KeychainStrategy``. The app declares a static. No shipped `.keychain`.
///
/// Persistence identity is the `service`, resolved at `onRead`.
public struct KeychainPolicy: Sendable, Equatable {
    public let accessibility: String
    public let accessGroup: String?
    public let synchronizable: Bool
    public let service: String

    /// Every field is required. `accessGroup: nil` means no group. Empty `service` is `preconditionFailure`.
    public init(
        accessibility: CFString,
        accessGroup: String?,
        synchronizable: Bool,
        service: String
    ) {
        guard !service.isEmpty else {
            preconditionFailure("KeychainPolicy service must not be empty")
        }
        self.accessibility = accessibility as String
        self.accessGroup = accessGroup
        self.synchronizable = synchronizable
        self.service = service
    }

    /// The Keychain item identity every store call uses. Resolved from this Policy alone.
    var identity: KeychainIdentity {
        KeychainIdentity(
            service: service,
            accessibility: accessibility,
            accessGroup: accessGroup,
            synchronizable: synchronizable
        )
    }
}

extension AsyncState where S == KeychainStrategy {
    /// Pins `S` to ``KeychainStrategy``.
    @_disfavoredOverload
    public convenience init(wrappedValue: Value, _ policy: KeychainPolicy)
        where Key == NoKey, Entry == Value {
        self.init(wrappedValue: wrappedValue, policy: policy)
    }

    /// Pins `S` to ``KeychainStrategy``.
    public convenience init(wrappedValue: [Key: Entry], _ policy: KeychainPolicy)
        where Value == [Key: Entry] {
        self.init(wrappedValue: wrappedValue, policy: policy)
    }
}
