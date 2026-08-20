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
final class PersistItem {
    var persistOnNextServe: Bool
    let wasSourcedUpdated: (EnvironmentService) -> Bool
    let subscribe: (EnvironmentService) -> Void
    let run: (EnvironmentService) throws -> Void

    init(
        persistOnNextServe: Bool,
        wasSourcedUpdated: @escaping (EnvironmentService) -> Bool,
        subscribe: @escaping (EnvironmentService) -> Void,
        run: @escaping (EnvironmentService) throws -> Void
    ) {
        self.persistOnNextServe = persistOnNextServe
        self.wasSourcedUpdated = wasSourcedUpdated
        self.subscribe = subscribe
        self.run = run
    }
}

@MainActor
final class WeakUserDefaultsSource {
    weak var source: UserDefaultsSource?

    init(_ source: UserDefaultsSource) {
        self.source = source
    }
}

@MainActor
enum UserDefaultsPersistLedger {
    static var sources: [ObjectIdentifier: WeakUserDefaultsSource] = [:]

    static func register(_ source: UserDefaultsSource, environmentID: ObjectIdentifier) {
        sources[environmentID] = WeakUserDefaultsSource(source)
    }

    static func source(for environmentID: ObjectIdentifier) -> UserDefaultsSource? {
        sources[environmentID]?.source
    }
}

/// Persist-out Service. Reads sourced Addresses and `try perform`s ``PersistUserDefaults``.
@MainActor
final class UserDefaultsPersist: EnvironmentService {
    private let environmentID: ObjectIdentifier

    required init(env: SharedEnvironment) {
        environmentID = ObjectIdentifier(env)
        super.init(env: env)
    }

    override func serve() async {
        guard let source = UserDefaultsPersistLedger.source(for: environmentID) else {
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
