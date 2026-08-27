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

@Suite
@MainActor
struct JSONFilePathTests {

    @Test("Folder name is the module-qualified Container type")
    func folderIsReflectingType() {
        #expect(jsonFileLocation(\DraftNotes.body).folder == String(reflecting: DraftNotes.self))
    }

    @Test("Encoded filenames contain no backslash or path separator")
    func encodedFilenameHasNoIllegalCharacters() {
        let name = jsonFileLocation(\DraftNotes.body).file
        #expect(!name.contains("\\"))
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
    }

    @Test("Distinct Addresses produce distinct filenames")
    func distinctAddressesStayDistinct() {
        #expect(
            jsonFileLocation(\DraftNotes.body).file
                != jsonFileLocation(\OptionalNotes.subtitle).file
        )
        #expect(
            jsonFileLocation(\NoteBag.notes, key: "a")
                != jsonFileLocation(\NoteBag.notes, key: "b")
        )
    }

    @Test("Two Containers do not share a folder")
    func containersGetOwnFolders() {
        #expect(
            jsonFileLocation(\DraftNotes.body).folder
                != jsonFileLocation(\OtherNotes.body).folder
        )
    }
}
