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

/// Test and preview overlay of Persistence identity. Owns the Environments it creates.
///
/// Construct, then `defer { clear() }`. Overlay exists before first `provide`. Locators stay private.
@MainActor
public final class IsolatedPersistence {
    public let environment: SharedEnvironment

    private var additional: [SharedEnvironment] = []
    private let suiteName: String
    let defaults: UserDefaults

    public init() {
        let suiteName = "smlp.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("IsolatedPersistence UserDefaults suite failed")
        }
        defaults.removePersistentDomain(forName: suiteName)
        self.suiteName = suiteName
        self.defaults = defaults
        environment = SharedEnvironment()
        PersistenceOverlay.register(
            environmentID: ObjectIdentifier(environment),
            environment: environment,
            handle: self,
            defaults: defaults
        )
    }

    /// A second Environment with the same Persistence identity. Assert persist-out here after notify.
    public func additionalEnvironment() -> SharedEnvironment {
        let env = SharedEnvironment()
        additional.append(env)
        PersistenceOverlay.register(
            environmentID: ObjectIdentifier(env),
            environment: env,
            handle: self,
            defaults: defaults
        )
        return env
    }

    /// Deletes the UUID UserDefaults suite IsolatedPersistence allocated.
    public func clear() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        let name = suiteName
        UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
    }

    #if DEBUG
    /// Applies the Seed batch to ``environment`` in one notify. Forwards to ``SharedEnvironment/seed(_:)``.
    public func seed(
        @SeedOperationsBuilder _ operations: () -> [any SyncOperation]
    ) {
        environment.seed(operations)
    }
    #endif
}

#if DEBUG
/// Token for `.sharedEnvironment(.isolatedPersistence)`. The modifier holds IsolatedPersistence per View identity.
public enum IsolatedPersistenceToken: Sendable {
    case isolatedPersistence
}
#endif

@MainActor
final class PersistenceOverlayBox {
    let environmentID: ObjectIdentifier
    weak var environment: SharedEnvironment?
    weak var handle: IsolatedPersistence?
    let defaults: UserDefaults

    init(
        environmentID: ObjectIdentifier,
        environment: SharedEnvironment,
        handle: IsolatedPersistence,
        defaults: UserDefaults
    ) {
        self.environmentID = environmentID
        self.environment = environment
        self.handle = handle
        self.defaults = defaults
    }
}

@MainActor
enum PersistenceOverlay {
    static var boxes: [PersistenceOverlayBox] = []

    static func register(
        environmentID: ObjectIdentifier,
        environment: SharedEnvironment,
        handle: IsolatedPersistence,
        defaults: UserDefaults
    ) {
        prune()
        boxes.append(
            PersistenceOverlayBox(
                environmentID: environmentID,
                environment: environment,
                handle: handle,
                defaults: defaults
            )
        )
    }

    static func userDefaults(
        policy: UserDefaultsPolicy,
        environmentID: ObjectIdentifier
    ) -> UserDefaults {
        prune()
        if let box = boxes.first(where: { $0.environmentID == environmentID }) {
            guard box.handle != nil else {
                preconditionFailure(
                    "IsolatedPersistence is gone; leftover provide cannot use production Persistence identity"
                )
            }
            return box.defaults
        }
        return policy.makeUserDefaults()
    }

    private static func prune() {
        boxes.removeAll { $0.environment == nil && $0.handle == nil }
    }
}
