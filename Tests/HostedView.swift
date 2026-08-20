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

#if canImport(AppKit) || canImport(UIKit)
import SwiftUI

@MainActor
enum HostedView {
    struct Handle {
        let relayout: () -> Void
        let teardown: () -> Void
    }

    static func mount<V: View>(_ view: V) -> Handle {
        #if canImport(AppKit)
        let host = NSHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        host.view.layoutSubtreeIfNeeded()
        return Handle(
            relayout: { host.view.layoutSubtreeIfNeeded() },
            teardown: { _ = host }
        )
        #elseif canImport(UIKit)
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return Handle(
            relayout: {
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
            },
            teardown: {
                window.isHidden = true
                _ = host
                _ = window
            }
        )
        #endif
    }
}
#endif
