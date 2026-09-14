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

private let preheatSuite = uniqueSuiteName()
private let noRowSuite = uniqueSuiteName()
private let blindWriteSuite = uniqueSuiteName()

final class UDPreheatPrefs: StateContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: preheatSuite)) var theme: String = "system"
}

final class UDNoRowPrefs: StateContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: noRowSuite)) var theme: String = "system"
}

final class UDBlindWritePrefs: StateContainer {
    @AsyncState(UserDefaultsPolicy(suiteName: blindWriteSuite)) var theme: String = "system"
}

@MainActor
struct UserDefaultsStrategyTests {

    @Test("Preheat loads with no prior read")
    func preheatLoadsWithNoPriorRead() throws {
        defer { removeUserDefaultsSuite(preheatSuite) }
        let env = SharedEnvironment()

        env.preheat(\UDPreheatPrefs.$theme)

        #expect(env.snapshot(\UDPreheatPrefs.theme) == "system")
        guard case .settled = env.snapshot(\UDPreheatPrefs.$theme.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Missing onRead does not write the suite")
    func missingOnReadDoesNotWriteSuite() async throws {
        defer { removeUserDefaultsSuite(noRowSuite) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\UDNoRowPrefs.theme) == "system")

        let defaults = try #require(UserDefaults(suiteName: noRowSuite))
        let key = userDefaultsKey(\UDNoRowPrefs.$theme)
        await #expect(throws: TimedOut.self) {
            try await waitFor(timeout: .milliseconds(200)) { defaults.data(forKey: key) != nil }
        }
    }

    @Test("A Sync write persists without a prior read")
    func writeWithoutPriorReadPersists() async throws {
        defer { removeUserDefaultsSuite(blindWriteSuite) }
        let env = SharedEnvironment()

        env.perform(WriteValue(path: \UDBlindWritePrefs.theme, value: "dark"))

        let defaults = try #require(UserDefaults(suiteName: blindWriteSuite))
        let key = userDefaultsKey(\UDBlindWritePrefs.$theme)
        try await waitFor { defaults.data(forKey: key) != nil }

        #expect(SharedEnvironment().snapshot(\UDBlindWritePrefs.theme) == "dark")
    }
}
