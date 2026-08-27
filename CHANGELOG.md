# Changelog

All notable changes to SMLocalPersistence are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Experimental Satellite `0.9.0`. Depends on StateManagement `0.9.2`. In-repo DocC only, no Swift Package Index until Satellite `1.0.0`. Not a freeze.

### Changed

- Strategy kicks take the `$` Address. No Value-path `WritableKeyPath` cast in `onRead`. 0.9.x break, no shim.

### Added

- In-repo DocC catalog: Policy, UserDefaults, Keychain, JSON file, Tests and previews. Persist internals hidden. No SPI.

- JSON-file strategy. App `JSONFilePolicy` static (`root` required). One Address is one file; folders are `String(reflecting:)` of the Container type; filenames encode the Address. `@AsyncState(JSONFileStrategy.self)` does not compile. IsolatedPersistence overlays a UUID temp root `smlp-{uuid}`. `JSONFileFailure` is `decoding` or `io`. Persist-out is atomic; optional `nil` `onWrite` deletes the file.

- `IsolatedPersistence` overlays a unique UserDefaults suite for tests and previews. `additionalEnvironment()` shares that Persistence identity. `clear()` / deinit wipe the UUID disk. DEBUG `seed { }` forwards to `SharedEnvironment.seed`. DEBUG `.sharedEnvironment(iso)` / `.sharedEnvironment(.isolatedPersistence)` / `.seedEnvironment(.isolatedPersistence) { }` retain IsolatedPersistence for the View.

- Keychain Source. App `KeychainPolicy` static (`accessibility`, `accessGroup`, `synchronizable`, `service`). `@AsyncState(KeychainSource.self)` does not compile. IsolatedPersistence overlays a UUID Keychain service and forces `synchronizable = false` and `accessGroup = nil`.

- UserDefaults KVS Satellite on the StateManagement `Source` seam. Source with `@AsyncState(.userDefaults)`.

### Changed

- Package, product, and module are `SMLocalPersistence`.
- `UserDefaultsBind` is `UserDefaultsPolicy`. `@AsyncState(UserDefaultsSource.self)` does not compile.
- Tests and previews use `IsolatedPersistence`. Persistence identity lives on `UserDefaultsPolicy` (`.userDefaults` is `.standard`, or `init(suiteName:)`). Dropped `UserDefaultsConfiguration`, `UseUserDefaults`, and public `ClearUserDefaultsSuite`.
