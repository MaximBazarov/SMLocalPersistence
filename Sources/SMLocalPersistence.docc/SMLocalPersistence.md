# ``SMLocalPersistence``

Local-persistence Satellite for StateManagement: UserDefaults, Keychain, and JSON-file.

Back a Value with `@AsyncState(.userDefaults)` or an app Policy static (``KeychainPolicy``, ``JSONFilePolicy``). Strategy kicks take the `$` Address. Policy selects the store, not a second Address.

App tests and previews that must not touch a store seat a no-op strategy with `SharedEnvironment.install(_:)`. To exercise a real store, give each test Container a unique Persistence identity through the public Policy initializers. Production Persistence identity is the Policy static, resolved at `onRead`. `SharedEnvironment()` stays production.

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
