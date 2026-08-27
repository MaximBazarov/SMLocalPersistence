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
import Testing
import StateManagement
@testable import SMLocalPersistence

final class NoteBag: StateContainer {
    @AsyncState(.drafts) var notes: [String: String] = [:]
}

struct SetBagNote: SyncOperation {
    let key: String
    let value: String
    func perform(in env: SyncOperationEnvironment) {
        env.write(value, keyPath: \NoteBag.notes, key: key)
    }
}

@Suite(.serialized)
@MainActor
struct JSONFileKeyedTests {

    @Test("A keyed Sync write persists; a second Environment loads that key")
    func keyedPersistOutLoadsInSecondEnvironment() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\NoteBag.notes, key: "a")
        iso.environment.perform(SetBagNote(key: "a", value: "one"))

        try await iso.waitForJSONPersistOut(location: jsonFileLocation(\NoteBag.$notes, key: "a"))

        let env2 = iso.additionalEnvironment()
        #expect(env2.read(\NoteBag.notes, key: "a") == "one")
        guard case .settled = env2.read(\NoteBag.$notes.status, key: "a") else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Keyed Values are one file per key")
    func keyedValuesDoNotShareAFile() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\NoteBag.notes, key: "a")
        iso.environment.preheat(\NoteBag.notes, key: "b")
        iso.environment.perform(SetBagNote(key: "a", value: "one"))
        iso.environment.perform(SetBagNote(key: "b", value: "two"))

        try await iso.waitForJSONPersistOut(location: jsonFileLocation(\NoteBag.$notes, key: "a"))
        try await iso.waitForJSONPersistOut(location: jsonFileLocation(\NoteBag.$notes, key: "b"))

        let env2 = iso.additionalEnvironment()
        #expect(env2.read(\NoteBag.notes, key: "a") == "one")
        #expect(env2.read(\NoteBag.notes, key: "b") == "two")
        #expect(
            jsonFileLocation(\NoteBag.$notes, key: "a")
                != jsonFileLocation(\NoteBag.$notes, key: "b")
        )
    }
}
