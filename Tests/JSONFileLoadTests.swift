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

enum JSONFileTestRoot {
    static let production = FileManager.default.temporaryDirectory
        .appendingPathComponent("smlp-json-app-root", isDirectory: true)
}

extension JSONFilePolicy {
    static let drafts = JSONFilePolicy(root: JSONFileTestRoot.production)
}

final class DraftNotes: StateContainer {
    @AsyncState(.drafts) var body: String = ""
}

final class OptionalNotes: StateContainer {
    @AsyncState(.drafts) var subtitle: String? = nil
}

struct SetBody: SyncOperation {
    let value: String
    func perform(in env: SyncOperationEnvironment) {
        env.write(value, keyPath: \DraftNotes.body)
    }
}

struct SetSubtitle: SyncOperation {
    let value: String?
    func perform(in env: SyncOperationEnvironment) {
        env.write(value, keyPath: \OptionalNotes.subtitle)
    }
}

@Suite(.serialized)
@MainActor
struct JSONFileLoadTests {

    @Test("Missing JSON file settles the Container default")
    func missingFileSettlesDefault() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.read(\DraftNotes.body) == "")
        guard case .settled = iso.environment.read(\DraftNotes.$body.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Missing optional file settles nil")
    func missingOptionalSettlesNil() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.read(\OptionalNotes.subtitle) == nil)
        guard case .settled = iso.environment.read(\OptionalNotes.$subtitle.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Corrupt JSON data fails Source status and leaves the seed")
    func corruptDataFailsStatus() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        let location = jsonFileLocation(\DraftNotes.body)
        try iso.plantJSON(Data([0x00, 0x01, 0x02]), location: location)

        #expect(iso.environment.read(\DraftNotes.body) == "")
        guard case .error(let failure) = iso.environment.read(\DraftNotes.$body.status) else {
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
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.read(\DraftNotes.body) == "")
        iso.environment.perform(SetBody(value: "hello"))

        try await iso.waitForJSONPersistOut(location: jsonFileLocation(\DraftNotes.body))

        let env2 = iso.additionalEnvironment()
        #expect(env2.read(\DraftNotes.body) == "hello")
        guard case .settled = env2.read(\DraftNotes.$body.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Optional nil deletes the JSON file")
    func optionalNilDeletesFile() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\OptionalNotes.subtitle)
        iso.environment.perform(SetSubtitle(value: "draft"))
        let location = jsonFileLocation(\OptionalNotes.subtitle)
        try await iso.waitForJSONPersistOut(location: location)

        iso.environment.perform(SetSubtitle(value: nil))
        try await iso.waitForJSONRemoval(location: location)

        let env2 = iso.additionalEnvironment()
        #expect(env2.read(\OptionalNotes.subtitle) == nil)
        guard case .settled = env2.read(\OptionalNotes.$subtitle.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Persisted JSON is Foundation encoder defaults, not pretty printed")
    func persistedJSONIsCompact() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.perform(SetBody(value: "hello"))
        let location = jsonFileLocation(\DraftNotes.body)
        try await iso.waitForJSONPersistOut(location: location)

        let data = try #require(iso.jsonFileData(location: location))
        #expect(data == Data("\"hello\"".utf8))
        #expect(!data.contains(UInt8(ascii: "\n")))
    }
}
