# Changelog

All notable changes to SMLocalPersistence are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Experimental Satellite `0.9.0`. Depends on StateManagement `0.9.4`. In-repo DocC only, no Swift Package Index until Satellite `1.0.0`. Not a freeze.

### Removed

- `IsolatedPersistence`, `IsolatedPersistenceToken`, and the DEBUG `.sharedEnvironment(.isolatedPersistence)` / `.seedEnvironment(.isolatedPersistence) { }` View modifiers. App tests and previews isolate through StateManagement's TestingSupport (I9); the Satellite suite exercises real stores with a unique Persistence identity per test Container through the public Policy initializers. Strategies resolve Persistence identity from Policy alone at `onRead` — no overlay.

### Changed

- StateManagement is a git URL dependency at `0.9.4`, not a path dependency, so any checkout resolves.
- Strategy kicks take the `$` Address. No Value-path `WritableKeyPath` cast in `onRead`. 0.9.x break, no shim.
- Tracks the core's `AsyncState<S, Key, Entry, Value>` reshape: kicks are address-first with the payload last, and each Policy's `convenience init` pins `S` by constraining `Key` and `Entry` rather than `Status`. `preheat` takes the `$` Address, keyed `preheat` takes `keys:`. Call sites change, stored keys do not. 0.9.x break, no shim.

### Added

- In-repo DocC catalog: Policy, UserDefaults, Keychain, JSON file. Persist internals hidden. No SPI.

- JSON-file strategy. App `JSONFilePolicy` static (`root` required). One Address is one file; folders are `String(reflecting:)` of the Container type; filenames encode the Address. `@AsyncState(JSONFileStrategy.self)` does not compile. `JSONFileFailure` is `decoding` or `io`. Persist-out is atomic; optional `nil` `onWrite` deletes the file.

- Keychain Source. App `KeychainPolicy` static (`accessibility`, `accessGroup`, `synchronizable`, `service`). `@AsyncState(KeychainSource.self)` does not compile.

- UserDefaults KVS Satellite on the StateManagement `Source` seam. Source with `@AsyncState(.userDefaults)`.

### Changed

- Package, product, and module are `SMLocalPersistence`.
- `UserDefaultsBind` is `UserDefaultsPolicy`. `@AsyncState(UserDefaultsSource.self)` does not compile.
- Persistence identity lives on `UserDefaultsPolicy` (`.userDefaults` is `.standard`, or `init(suiteName:)`). Dropped `UserDefaultsConfiguration`, `UseUserDefaults`, and public `ClearUserDefaultsSuite`.
