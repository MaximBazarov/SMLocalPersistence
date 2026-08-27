# ``SMLocalPersistence``

Local-persistence Satellite for StateManagement: UserDefaults, Keychain, and JSON-file.

Back a Value with `@AsyncState(.userDefaults)` or an app Policy static (``KeychainPolicy``, ``JSONFilePolicy``). Address names the Value. Policy selects the store, not a second Address.

Tests and previews use ``IsolatedPersistence``. It overlays Persistence identity before first `onRead`. Production Containers stay unchanged. `SharedEnvironment()` stays production.

## Topics

### Policy

- ``UserDefaultsPolicy``
- ``KeychainPolicy``
- ``JSONFilePolicy``

### UserDefaults

- ``UserDefaultsStrategy``
- ``UserDefaultsPolicy/userDefaults``

### Keychain

- ``KeychainStrategy``
- ``KeychainFailure``

### JSON file

- ``JSONFileStrategy``
- ``JSONFileFailure``

### Tests and previews

``IsolatedPersistence`` overlays Persistence identity for tests and previews. DEBUG `.sharedEnvironment(.isolatedPersistence)` and `.seedEnvironment(.isolatedPersistence) { }` construct and retain IsolatedPersistence per View identity. Production `SharedEnvironment()` is unchanged.

- ``IsolatedPersistence``
- ``IsolatedPersistenceToken``
- ``IsolatedPersistence/environment``
- ``IsolatedPersistence/additionalEnvironment()``
- ``IsolatedPersistence/clear()``
- ``IsolatedPersistence/seed(_:)``
