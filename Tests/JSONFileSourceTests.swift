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

@Suite(.serialized)
@MainActor
struct JSONFileStrategyTests {

    @Test("Preheat loads with no prior read")
    func preheatLoadsWithNoPriorRead() throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.preheat(\DraftNotes.$body)

        #expect(iso.environment.snapshot(\DraftNotes.body) == "")
        guard case .settled = iso.environment.snapshot(\DraftNotes.$body.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("A Sync write persists without a prior read")
    func writeWithoutPriorReadPersists() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        iso.environment.perform(SetBody(value: "hello"))
        try await iso.waitForJSONPersistOut(location: jsonFileLocation(\DraftNotes.$body))

        #expect(iso.additionalEnvironment().snapshot(\DraftNotes.body) == "hello")
    }

    @Test("Missing onRead does not create a JSON file")
    func missingOnReadDoesNotWrite() async throws {
        let iso = IsolatedPersistence()
        defer { iso.clear() }

        #expect(iso.environment.snapshot(\DraftNotes.body) == "")
        await #expect(throws: PersistOutTimeout.self) {
            try await iso.waitForJSONPersistOut(location: jsonFileLocation(\DraftNotes.$body))
        }
    }
}
