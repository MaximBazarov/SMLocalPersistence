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

private let keyedMissingRoot = uniqueJSONRoot()
private let keyedPersistRoot = uniqueJSONRoot()
private let keyedSplitRoot = uniqueJSONRoot()

extension JSONFilePolicy {
    static let jfKeyedMissing = JSONFilePolicy(root: keyedMissingRoot)
    static let jfKeyedPersist = JSONFilePolicy(root: keyedPersistRoot)
    static let jfKeyedSplit = JSONFilePolicy(root: keyedSplitRoot)
}

final class JFKeyedMissingBag: StateContainer {
    @AsyncState(.jfKeyedMissing) var notes: [String: String] = [:]
}

final class JFKeyedPersistBag: StateContainer {
    @AsyncState(.jfKeyedPersist) var notes: [String: String] = [:]
}

final class JFKeyedSplitBag: StateContainer {
    @AsyncState(.jfKeyedSplit) var notes: [String: String] = [:]
}

@MainActor
struct JSONFileKeyedTests {

    @Test("A missing keyed optional file settles nil")
    func missingKeyedFileSettlesNil() throws {
        defer { removeJSONRoot(keyedMissingRoot) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\JFKeyedMissingBag.notes, key: "missing") == nil)
        guard case .settled = env.snapshot(\JFKeyedMissingBag.$notes.status, key: "missing") else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("A keyed Sync write persists; a second Environment loads that key")
    func keyedPersistOutLoadsInSecondEnvironment() async throws {
        defer { removeJSONRoot(keyedPersistRoot) }
        let env = SharedEnvironment()

        env.preheat(\JFKeyedPersistBag.$notes, keys: ["a"])
        env.perform(WriteEntry(path: \JFKeyedPersistBag.notes, key: "a", value: "one"))

        let url = jsonFileURL(
            root: keyedPersistRoot,
            location: jsonFileLocation(\JFKeyedPersistBag.$notes, key: "a")
        )
        try await waitFor { FileManager.default.fileExists(atPath: url.path) }

        let env2 = SharedEnvironment()
        #expect(env2.snapshot(\JFKeyedPersistBag.notes, key: "a") == "one")
        guard case .settled = env2.snapshot(\JFKeyedPersistBag.$notes.status, key: "a") else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Keyed Values are one file per key")
    func keyedValuesDoNotShareAFile() async throws {
        defer { removeJSONRoot(keyedSplitRoot) }
        let env = SharedEnvironment()

        env.preheat(\JFKeyedSplitBag.$notes, keys: ["a"])
        env.preheat(\JFKeyedSplitBag.$notes, keys: ["b"])
        env.perform(WriteEntry(path: \JFKeyedSplitBag.notes, key: "a", value: "one"))
        env.perform(WriteEntry(path: \JFKeyedSplitBag.notes, key: "b", value: "two"))

        let urlA = jsonFileURL(root: keyedSplitRoot, location: jsonFileLocation(\JFKeyedSplitBag.$notes, key: "a"))
        let urlB = jsonFileURL(root: keyedSplitRoot, location: jsonFileLocation(\JFKeyedSplitBag.$notes, key: "b"))
        try await waitFor { FileManager.default.fileExists(atPath: urlA.path) }
        try await waitFor { FileManager.default.fileExists(atPath: urlB.path) }

        let env2 = SharedEnvironment()
        #expect(env2.snapshot(\JFKeyedSplitBag.notes, key: "a") == "one")
        #expect(env2.snapshot(\JFKeyedSplitBag.notes, key: "b") == "two")
        #expect(
            jsonFileLocation(\JFKeyedSplitBag.$notes, key: "a")
                != jsonFileLocation(\JFKeyedSplitBag.$notes, key: "b")
        )
    }
}
