# Changelog

All notable changes to SMLocalPersistence are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `IsolatedPersistence` overlays a unique UserDefaults suite for tests and previews. `additionalEnvironment()` shares that Persistence identity. `clear()` / deinit wipe the UUID disk. DEBUG `seed { }` forwards to `SharedEnvironment.seed`. DEBUG `.sharedEnvironment(iso)` / `.sharedEnvironment(.isolatedPersistence)` retain IsolatedPersistence for the View.

- UserDefaults KVS Satellite on the StateManagement `Source` seam. Source with `@AsyncState(.userDefaults)`.

### Changed

- Package, product, and module are `SMLocalPersistence`.
- `UserDefaultsBind` is `UserDefaultsPolicy`. `@AsyncState(UserDefaultsSource.self)` does not compile.
- Tests and previews use `IsolatedPersistence`. Persistence identity lives on `UserDefaultsPolicy` (`.userDefaults` is `.standard`, or `init(suiteName:)`). Dropped `UserDefaultsConfiguration`, `UseUserDefaults`, and public `ClearUserDefaultsSuite`.
