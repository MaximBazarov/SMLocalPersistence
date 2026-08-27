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
import OSLog

private let jsonLog = Logger(subsystem: "SMLocalPersistence", category: "JSONFile")

func copyJSONFileData(root: URL, location: JSONFileLocation) throws(JSONFileFailure) -> Data? {
    let url = jsonFileURL(root: root, location: location)
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
        return nil
    }
    if isDir.boolValue {
        throw JSONFileFailure.io
    }
    do {
        return try Data(contentsOf: url)
    } catch {
        throw JSONFileFailure.io
    }
}

func writeJSONFileData(root: URL, location: JSONFileLocation, data: Data) throws(JSONFileFailure) {
    let url = jsonFileURL(root: root, location: location)
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    } catch {
        throw JSONFileFailure.io
    }
}

func deleteJSONFile(root: URL, location: JSONFileLocation) throws(JSONFileFailure) {
    let url = jsonFileURL(root: root, location: location)
    do {
        try FileManager.default.removeItem(at: url)
    } catch {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
            return
        }
        throw JSONFileFailure.io
    }
}

func deleteJSONFileTree(root: URL) {
    do {
        try FileManager.default.removeItem(at: root)
    } catch {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
            return
        }
        jsonLog.error("IsolatedPersistence JSON root clear failed: \(error.localizedDescription)")
    }
}
