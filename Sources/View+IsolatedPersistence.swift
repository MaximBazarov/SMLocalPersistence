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

#if canImport(SwiftUI)
import SwiftUI
import StateManagement

#if DEBUG
extension View {
    /// Injects IsolatedPersistence’s Environment and retains IsolatedPersistence for this View.
    public func sharedEnvironment(_ isolatedPersistence: IsolatedPersistence) -> some View {
        IsolatedPersistenceHost(isolatedPersistence: isolatedPersistence, content: self)
    }

    /// DEBUG `.sharedEnvironment(.isolatedPersistence)`. Constructs IsolatedPersistence per View identity.
    public func sharedEnvironment(_ token: IsolatedPersistenceToken) -> some View {
        TokenIsolatedPersistenceHost(content: self)
    }

    /// Seeds IsolatedPersistence then injects it. Retains IsolatedPersistence for this View.
    public func seedEnvironment(
        _ isolatedPersistence: IsolatedPersistence,
        @SeedOperationsBuilder _ operations: () -> [any SyncOperation]
    ) -> some View {
        isolatedPersistence.seed(operations)
        return sharedEnvironment(isolatedPersistence)
    }

    /// DEBUG `.seedEnvironment(.isolatedPersistence) { }`. Constructs IsolatedPersistence per View identity, then seeds.
    public func seedEnvironment(
        _ token: IsolatedPersistenceToken,
        @SeedOperationsBuilder _ operations: () -> [any SyncOperation]
    ) -> some View {
        TokenSeededIsolatedPersistenceHost(operations: operations, content: self)
    }
}

private struct IsolatedPersistenceHost<Content: View>: View {
    let isolatedPersistence: IsolatedPersistence
    let content: Content

    var body: some View {
        content.environment(\.sharedEnvironment, isolatedPersistence.environment)
    }
}

private struct TokenIsolatedPersistenceHost<Content: View>: View {
    @State private var isolatedPersistence = IsolatedPersistence()
    let content: Content

    var body: some View {
        content.environment(\.sharedEnvironment, isolatedPersistence.environment)
    }
}

private struct TokenSeededIsolatedPersistenceHost<Content: View>: View {
    @State private var isolatedPersistence: IsolatedPersistence
    let content: Content

    init(
        @SeedOperationsBuilder operations: () -> [any SyncOperation],
        content: Content
    ) {
        let iso = IsolatedPersistence()
        iso.seed(operations)
        _isolatedPersistence = State(initialValue: iso)
        self.content = content
    }

    var body: some View {
        content.environment(\.sharedEnvironment, isolatedPersistence.environment)
    }
}
#endif
#endif
