# SMLocalPersistence

Experimental. Satellite v0.9.0. Depends on StateManagement 0.9.4. The public API will break until 1.0.0. In-repo DocC only, no Swift Package Index until 1.0.0. Not a freeze.

Local persistence for [StateManagement](https://github.com/MaximBazarov/StateManagement). A Satellite: it owns the store. Core owns the AsyncStrategy seam.

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

Values are `Codable`. For UserDefaults keys, see [Durable UserDefaults addresses](#durable-userdefaults-addresses). Keychain accounts use the Address. JSON-file is one file per Address, folders per Container type. Load on first read or `preheat`. A Sync write persists through `onWrite`.

App tests and previews isolate stores with a unique Persistence identity per Container through the public Policy initializers. Production Containers stay `@AsyncState(.userDefaults)` or an app Policy static. `SharedEnvironment()` stays production.

## Durable UserDefaults addresses

For data that must survive optimized app launches, conform the Container to
`StableUserDefaultsContainer`. Map both the backing `_property` and projected
`$property` key paths to the same permanent name:

```swift
final class DurablePrefs: StableUserDefaultsContainer {
    @AsyncState(.userDefaults) var theme: String = "system"

    static var userDefaultsAddresses: [AnyKeyPath: String] {
        [\DurablePrefs._theme: "prefs.theme", \DurablePrefs.$theme: "prefs.theme"]
    }
}
```

The stored key is `smud.prefs.theme`. Keyed values append `#{key}`. Reads, writes,
and optional-value deletion use the same key. Names must be unique within the
UserDefaults suite and remain unchanged across releases.
A missing mapping in a conforming Container is a precondition failure.

Containers without this conformance retain their existing key format. Swift can
include process-specific getter addresses in optimized key-path descriptions,
so that format is not a durable identity guarantee. When adopting permanent
names for existing data, use the exact previous symbolic address to preserve
its key. The library does not guess or migrate keys containing getter addresses.
Keychain accounts and JSON filenames retain their existing address behavior.

The package bundles a privacy manifest declaring its UserDefaults access.

## Requirements

- Swift 6.2+
- macOS 12+, iOS 17+
- StateManagement 0.9.4
