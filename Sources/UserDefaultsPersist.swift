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
enum UserDefaultsPersistLedger {
    static var items: [ObjectIdentifier: [PersistItem]] = [:]

    static func append(_ item: PersistItem, defaults: UserDefaults) {
        items[ObjectIdentifier(defaults), default: []].append(item)
    }

    static func items(for defaults: UserDefaults) -> [PersistItem] {
        items[ObjectIdentifier(defaults)] ?? []
    }
}

/// Persist-out Service. Reads sourced Addresses and `try perform`s ``PersistUserDefaults``.
@MainActor
final class UserDefaultsPersist: EnvironmentService {
    override func serve() async {
        let defaults = getValue(\UserDefaultsConfiguration.defaults)
        for item in UserDefaultsPersistLedger.items(for: defaults) {
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
