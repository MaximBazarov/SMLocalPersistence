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

private let preheatRoot = uniqueJSONRoot()
private let noRowRoot = uniqueJSONRoot()
private let blindWriteRoot = uniqueJSONRoot()

extension JSONFilePolicy {
    static let jfPreheat = JSONFilePolicy(root: preheatRoot)
    static let jfNoRow = JSONFilePolicy(root: noRowRoot)
    static let jfBlindWrite = JSONFilePolicy(root: blindWriteRoot)
}

final class JFPreheatNotes: StateContainer {
    @AsyncState(.jfPreheat) var body: String = ""
}

final class JFNoRowNotes: StateContainer {
    @AsyncState(.jfNoRow) var body: String = ""
}

final class JFBlindWriteNotes: StateContainer {
    @AsyncState(.jfBlindWrite) var body: String = ""
}

@MainActor
struct JSONFileStrategyTests {

    @Test("Preheat loads with no prior read")
    func preheatLoadsWithNoPriorRead() throws {
        defer { removeJSONRoot(preheatRoot) }
        let env = SharedEnvironment()

        env.preheat(\JFPreheatNotes.$body)

        #expect(env.snapshot(\JFPreheatNotes.body) == "")
        guard case .settled = env.snapshot(\JFPreheatNotes.$body.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Missing onRead does not create a JSON file")
    func missingOnReadDoesNotWrite() async throws {
        defer { removeJSONRoot(noRowRoot) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\JFNoRowNotes.body) == "")

        let url = jsonFileURL(root: noRowRoot, location: jsonFileLocation(\JFNoRowNotes.$body))
        await #expect(throws: TimedOut.self) {
            try await waitFor(timeout: .milliseconds(200)) {
                FileManager.default.fileExists(atPath: url.path)
            }
        }
    }

    @Test("A Sync write persists without a prior read")
    func writeWithoutPriorReadPersists() async throws {
        defer { removeJSONRoot(blindWriteRoot) }
        let env = SharedEnvironment()

        env.perform(WriteValue(path: \JFBlindWriteNotes.body, value: "hello"))

        let url = jsonFileURL(root: blindWriteRoot, location: jsonFileLocation(\JFBlindWriteNotes.$body))
        try await waitFor { FileManager.default.fileExists(atPath: url.path) }

        #expect(SharedEnvironment().snapshot(\JFBlindWriteNotes.body) == "hello")
    }
}
