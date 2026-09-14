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

// Pure path derivation: these Containers are never read in an Environment, so no store
// is touched and the shared root stays untouched.

private let pathRoot = uniqueJSONRoot()

extension JSONFilePolicy {
    static let jfPath = JSONFilePolicy(root: pathRoot)
}

final class PathDraftNotes: StateContainer {
    @AsyncState(.jfPath) var body: String = ""
    @AsyncState(.jfPath) var subtitle: String? = nil
}

final class PathNoteBag: StateContainer {
    @AsyncState(.jfPath) var notes: [String: String] = [:]
}

final class PathOtherNotes: StateContainer {
    @AsyncState(.jfPath) var body: String = ""
}

@Suite
@MainActor
struct JSONFilePathTests {

    @Test("Folder name is the module-qualified Container type")
    func folderIsReflectingType() {
        #expect(jsonFileLocation(\PathDraftNotes.$body).folder == String(reflecting: PathDraftNotes.self))
    }

    @Test("Encoded filenames contain no backslash or path separator")
    func encodedFilenameHasNoIllegalCharacters() {
        let name = jsonFileLocation(\PathDraftNotes.$body).file
        #expect(!name.contains("\\"))
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
    }

    @Test("Distinct Addresses produce distinct filenames")
    func distinctAddressesStayDistinct() {
        #expect(
            jsonFileLocation(\PathDraftNotes.$body).file
                != jsonFileLocation(\PathDraftNotes.$subtitle).file
        )
        #expect(
            jsonFileLocation(\PathNoteBag.$notes, key: "a")
                != jsonFileLocation(\PathNoteBag.$notes, key: "b")
        )
    }

    @Test("Two Containers do not share a folder")
    func containersGetOwnFolders() {
        #expect(
            jsonFileLocation(\PathDraftNotes.$body).folder
                != jsonFileLocation(\PathOtherNotes.$body).folder
        )
    }
}
