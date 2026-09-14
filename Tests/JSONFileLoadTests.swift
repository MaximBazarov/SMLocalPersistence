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

// One test Container per test; Persistence identity is a unique root through the
// public Policy initializer, declared as a static the way an app would (P2, P16).

private let missingRoot = uniqueJSONRoot()
private let missingOptionalRoot = uniqueJSONRoot()
private let corruptRoot = uniqueJSONRoot()
private let persistRoot = uniqueJSONRoot()
private let deleteRoot = uniqueJSONRoot()
private let compactRoot = uniqueJSONRoot()

extension JSONFilePolicy {
    static let jfMissing = JSONFilePolicy(root: missingRoot)
    static let jfMissingOptional = JSONFilePolicy(root: missingOptionalRoot)
    static let jfCorrupt = JSONFilePolicy(root: corruptRoot)
    static let jfPersist = JSONFilePolicy(root: persistRoot)
    static let jfDelete = JSONFilePolicy(root: deleteRoot)
    static let jfCompact = JSONFilePolicy(root: compactRoot)
}

final class JFMissingNotes: StateContainer {
    @AsyncState(.jfMissing) var body: String = ""
}

final class JFMissingOptionalNotes: StateContainer {
    @AsyncState(.jfMissingOptional) var subtitle: String? = nil
}

final class JFCorruptNotes: StateContainer {
    @AsyncState(.jfCorrupt) var body: String = ""
}

final class JFPersistNotes: StateContainer {
    @AsyncState(.jfPersist) var body: String = ""
}

final class JFDeleteNotes: StateContainer {
    @AsyncState(.jfDelete) var subtitle: String? = nil
}

final class JFCompactNotes: StateContainer {
    @AsyncState(.jfCompact) var body: String = ""
}

@MainActor
struct JSONFileLoadTests {

    @Test("Missing JSON file settles the Container default")
    func missingFileSettlesDefault() throws {
        defer { removeJSONRoot(missingRoot) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\JFMissingNotes.body) == "")
        guard case .settled = env.snapshot(\JFMissingNotes.$body.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Missing optional file settles nil")
    func missingOptionalSettlesNil() throws {
        defer { removeJSONRoot(missingOptionalRoot) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\JFMissingOptionalNotes.subtitle) == nil)
        guard case .settled = env.snapshot(\JFMissingOptionalNotes.$subtitle.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Corrupt JSON data fails Source status and leaves the seed")
    func corruptDataFailsStatus() throws {
        defer { removeJSONRoot(corruptRoot) }
        let location = jsonFileLocation(\JFCorruptNotes.$body)
        try writeJSONFileData(root: corruptRoot, location: location, data: Data([0x00, 0x01, 0x02]))

        let env = SharedEnvironment()
        #expect(env.snapshot(\JFCorruptNotes.body) == "")
        guard case .error(let failure) = env.snapshot(\JFCorruptNotes.$body.status) else {
            Issue.record("expected error")
            return
        }
        guard case .decoding = failure else {
            Issue.record("expected decoding")
            return
        }
    }

    @Test("A Sync write persists; a second Environment loads the Value")
    func persistOutLoadsInSecondEnvironment() async throws {
        defer { removeJSONRoot(persistRoot) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\JFPersistNotes.body) == "")
        env.perform(WriteValue(path: \JFPersistNotes.body, value: "hello"))

        let url = jsonFileURL(root: persistRoot, location: jsonFileLocation(\JFPersistNotes.$body))
        try await waitFor { FileManager.default.fileExists(atPath: url.path) }

        let env2 = SharedEnvironment()
        #expect(env2.snapshot(\JFPersistNotes.body) == "hello")
        guard case .settled = env2.snapshot(\JFPersistNotes.$body.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Optional nil deletes the JSON file")
    func optionalNilDeletesFile() async throws {
        defer { removeJSONRoot(deleteRoot) }
        let env = SharedEnvironment()
        let url = jsonFileURL(root: deleteRoot, location: jsonFileLocation(\JFDeleteNotes.$subtitle))

        env.preheat(\JFDeleteNotes.$subtitle)
        env.perform(WriteValue(path: \JFDeleteNotes.subtitle, value: "draft" as String?))
        try await waitFor { FileManager.default.fileExists(atPath: url.path) }

        env.perform(WriteValue(path: \JFDeleteNotes.subtitle, value: nil as String?))
        try await waitFor { !FileManager.default.fileExists(atPath: url.path) }

        let env2 = SharedEnvironment()
        #expect(env2.snapshot(\JFDeleteNotes.subtitle) == nil)
        guard case .settled = env2.snapshot(\JFDeleteNotes.$subtitle.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Persisted JSON is Foundation encoder defaults, not pretty printed")
    func persistedJSONIsCompact() async throws {
        defer { removeJSONRoot(compactRoot) }
        let env = SharedEnvironment()

        env.perform(WriteValue(path: \JFCompactNotes.body, value: "hello"))
        let url = jsonFileURL(root: compactRoot, location: jsonFileLocation(\JFCompactNotes.$body))
        try await waitFor { FileManager.default.fileExists(atPath: url.path) }

        let data = try Data(contentsOf: url)
        #expect(data == Data("\"hello\"".utf8))
        #expect(!data.contains(UInt8(ascii: "\n")))
    }
}
