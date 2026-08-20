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

@MainActor
final class WeakKeychainSource {
    weak var source: KeychainSource?

    init(_ source: KeychainSource) {
        self.source = source
    }
}

@MainActor
enum KeychainPersistLedger {
    static var sources: [ObjectIdentifier: WeakKeychainSource] = [:]

    static func register(_ source: KeychainSource, environmentID: ObjectIdentifier) {
        sources[environmentID] = WeakKeychainSource(source)
    }

    static func source(for environmentID: ObjectIdentifier) -> KeychainSource? {
        sources[environmentID]?.source
    }
}

/// Persist-out Service. Reads sourced Addresses and `try perform`s ``PersistKeychain``.
@MainActor
final class KeychainPersist: EnvironmentService {
    private let environmentID: ObjectIdentifier

    required init(env: SharedEnvironment) {
        environmentID = ObjectIdentifier(env)
        super.init(env: env)
    }

    override func serve() async {
        guard let source = KeychainPersistLedger.source(for: environmentID) else {
            return
        }
        for item in source.persistItems {
            item.subscribe(self)
            let shouldPersist = item.persistOnNextServe || item.wasSourcedUpdated(self)
            item.persistOnNextServe = false
            guard shouldPersist else { continue }
            do {
                try item.run(self)
            } catch {
                // Span already logged "failed". Persist-out does not fail Source status.
            }
        }
    }
}
