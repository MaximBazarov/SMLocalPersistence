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

extension JSONFilePolicy {
    static let otherRoot = JSONFilePolicy(
        root: FileManager.default.temporaryDirectory
            .appendingPathComponent("smlp-json-other-root", isDirectory: true)
    )
}

final class OtherNotes: StateContainer {
    @AsyncState(.otherRoot) var body: String = ""
}

@Suite(.serialized)
@MainActor
struct JSONFileIsolationTests {

    @Test("IsolatedPersistence Sync write does not write the app JSON root")
    func isolatedWriteDoesNotTouchAppRoot() async throws {
        try? FileManager.default.removeItem(at: JSONFileTestRoot.production)
        defer { try? FileManager.default.removeItem(at: JSONFileTestRoot.production) }

        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.read(\DraftNotes.body) == "")
        iso.environment.perform(SetBody(value: "hello"))
        try await iso.waitForJSONPersistOut(location: jsonFileLocation(\DraftNotes.$body))

        #expect(iso.additionalEnvironment().read(\DraftNotes.body) == "hello")

        let production = SharedEnvironment()
        #expect(production.read(\DraftNotes.body) == "")
        #expect(
            !FileManager.default.fileExists(
                atPath: jsonFileURL(
                    root: JSONFileTestRoot.production,
                    location: jsonFileLocation(\DraftNotes.$body)
                ).path
            )
        )
    }

    @Test("Different IsolatedPersistence instances do not share Values")
    func differentIsolatesDoNotShare() async throws {
        let isoA = IsolatedPersistence()
        defer { isoA.clear() }
        let isoB = IsolatedPersistence()
        defer { isoB.clear() }

        #expect(isoA.environment.read(\DraftNotes.body) == "")
        isoA.environment.perform(SetBody(value: "hello"))
        try await isoA.waitForJSONPersistOut(location: jsonFileLocation(\DraftNotes.$body))

        #expect(isoB.environment.read(\DraftNotes.body) == "")
        guard case .settled = isoB.environment.read(\DraftNotes.$body.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Isolation overlays an app Policy static")
    func isolationOverlaysAppStatic() async throws {
        try? FileManager.default.removeItem(at: JSONFileTestRoot.production)
        defer { try? FileManager.default.removeItem(at: JSONFileTestRoot.production) }

        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\DraftNotes.body)
        iso.environment.perform(SetBody(value: "hello"))
        try await iso.waitForJSONPersistOut(location: jsonFileLocation(\DraftNotes.$body))

        let env2 = iso.additionalEnvironment()
        #expect(env2.read(\DraftNotes.body) == "hello")
        guard case .settled = env2.read(\DraftNotes.$body.status) else {
            Issue.record("expected settled")
            return
        }

        let production = SharedEnvironment()
        #expect(production.read(\DraftNotes.body) == "")
    }

    @Test("clear deletes IsolatedPersistence JSON files")
    func clearDeletesJSONFiles() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.read(\DraftNotes.body) == "")
        iso.environment.perform(SetBody(value: "hello"))
        try await iso.waitForJSONPersistOut(location: jsonFileLocation(\DraftNotes.$body))

        iso.clear()
        #expect(iso.additionalEnvironment().read(\DraftNotes.body) == "")
    }

    #if DEBUG
    @Test("IsolatedPersistence.seed persists sourced JSON-file Writes")
    func seedPersistsJSONWrites() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.seed {
            Write(\DraftNotes.body, "hello")
        }
        iso.environment.preheat(\DraftNotes.body)
        try await iso.waitForJSONPersistOut(location: jsonFileLocation(\DraftNotes.$body))

        #expect(iso.additionalEnvironment().read(\DraftNotes.body) == "hello")
    }
    #endif

    #if os(macOS)
    @Test("Empty JSONFilePolicy root traps")
    func emptyRootTraps() async {
        await #expect(processExitsWith: .failure) {
            guard let url = URL(string: "file:") else {
                return
            }
            _ = JSONFilePolicy(root: url)
        }
    }
    #endif
}
