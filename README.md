# SMLocalPersistence

Experimental. Satellite v0.9.0. Depends on StateManagement 0.9.4. The public API will break until 1.0.0. In-repo DocC only, no Swift Package Index until 1.0.0. Not a freeze.

Local persistence for [StateManagement](https://github.com). A Satellite: it owns the store. Core owns the AsyncStrategy seam.

## AsyncStrategy

```swift
final class Prefs: StateContainer {
    @AsyncState(.userDefaults) var theme: String = "system"
}

extension JSONFilePolicy {
    static let drafts = JSONFilePolicy(root: appSupportDrafts)
}

final class Notes: StateContainer {
    @AsyncState(.drafts) var body: String = ""
}
```

Values are `Codable`. UserDefaults keys and Keychain accounts are the Address. JSON-file is one file per Address, folders per Container type. Load on first read or `preheat`. A Sync write persists through `onWrite`.

App tests and previews isolate through StateManagement's TestingSupport (I9): silence the strategy, no store is touched. Production Containers stay `@AsyncState(.userDefaults)` or an app Policy static. `SharedEnvironment()` stays production.

## Requirements

- Swift 6.2+
- macOS 12+, iOS 17+
- StateManagement 0.9.4
