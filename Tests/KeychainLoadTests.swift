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
import Security
import Testing
import StateManagement
@testable import SMLocalPersistence

// One test Container per test; Persistence identity is a unique service through the
// public Policy initializer, declared as a static the way an app would (P2, P16).

private let missingService = uniqueKeychainService()
private let missingOptionalService = uniqueKeychainService()
private let corruptService = uniqueKeychainService()
private let persistService = uniqueKeychainService()
private let deleteService = uniqueKeychainService()

extension KeychainPolicy {
    static let kcMissing = KeychainPolicy.testService(missingService)
    static let kcMissingOptional = KeychainPolicy.testService(missingOptionalService)
    static let kcCorrupt = KeychainPolicy.testService(corruptService)
    static let kcPersist = KeychainPolicy.testService(persistService)
    static let kcDelete = KeychainPolicy.testService(deleteService)
}

final class KCMissingSecrets: StateContainer {
    @AsyncState(.kcMissing) var token: String = ""
}

final class KCMissingOptionalSecrets: StateContainer {
    @AsyncState(.kcMissingOptional) var pin: String? = nil
}

final class KCCorruptSecrets: StateContainer {
    @AsyncState(.kcCorrupt) var token: String = ""
}

final class KCPersistSecrets: StateContainer {
    @AsyncState(.kcPersist) var token: String = ""
}

final class KCDeleteSecrets: StateContainer {
    @AsyncState(.kcDelete) var pin: String? = nil
}

@Suite(.enabled(if: keychainStoreAvailable, "this runner has no keychain entitlement"))
@MainActor
struct KeychainLoadTests {

    @Test("Missing Keychain item settles the Container default")
    func missingItemSettlesDefault() throws {
        defer { removeKeychainItems(service: missingService) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\KCMissingSecrets.token) == "")
        guard case .settled = env.snapshot(\KCMissingSecrets.$token.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Missing optional item settles nil")
    func missingOptionalSettlesNil() throws {
        defer { removeKeychainItems(service: missingOptionalService) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\KCMissingOptionalSecrets.pin) == nil)
        guard case .settled = env.snapshot(\KCMissingOptionalSecrets.$pin.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Corrupt Keychain data fails Source status and leaves the seed")
    func corruptDataFailsStatus() throws {
        defer { removeKeychainItems(service: corruptService) }
        let account = keychainAccount(\KCCorruptSecrets.$token)
        try upsertKeychainData(
            identity: KeychainPolicy.kcCorrupt.identity,
            account: account,
            data: Data([0x00, 0x01, 0x02])
        )

        let env = SharedEnvironment()
        #expect(env.snapshot(\KCCorruptSecrets.token) == "")
        guard case .error(let failure) = env.snapshot(\KCCorruptSecrets.$token.status) else {
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
        defer { removeKeychainItems(service: persistService) }
        let env = SharedEnvironment()

        #expect(env.snapshot(\KCPersistSecrets.token) == "")
        env.perform(WriteValue(path: \KCPersistSecrets.token, value: "secret"))

        let identity = KeychainPolicy.kcPersist.identity
        let account = keychainAccount(\KCPersistSecrets.$token)
        try await waitFor { keychainData(identity: identity, account: account) != nil }

        let env2 = SharedEnvironment()
        #expect(env2.snapshot(\KCPersistSecrets.token) == "secret")
        guard case .settled = env2.snapshot(\KCPersistSecrets.$token.status) else {
            Issue.record("expected settled")
            return
        }
    }

    @Test("Optional nil deletes the Keychain item")
    func optionalNilDeletesItem() async throws {
        defer { removeKeychainItems(service: deleteService) }
        let env = SharedEnvironment()
        let identity = KeychainPolicy.kcDelete.identity
        let account = keychainAccount(\KCDeleteSecrets.$pin)

        env.preheat(\KCDeleteSecrets.$pin)
        env.perform(WriteValue(path: \KCDeleteSecrets.pin, value: "1234" as String?))
        try await waitFor { keychainData(identity: identity, account: account) != nil }

        env.perform(WriteValue(path: \KCDeleteSecrets.pin, value: nil as String?))
        try await waitFor { keychainData(identity: identity, account: account) == nil }

        let env2 = SharedEnvironment()
        #expect(env2.snapshot(\KCDeleteSecrets.pin) == nil)
        guard case .settled = env2.snapshot(\KCDeleteSecrets.$pin.status) else {
            Issue.record("expected settled")
            return
        }
    }
}
