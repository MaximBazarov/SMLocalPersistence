# ``SMLocalPersistence``

Local-persistence Satellite for StateManagement: UserDefaults, Keychain, and JSON-file.

Back a Value with `@AsyncState(.userDefaults)` or an app Policy static (``KeychainPolicy``, ``JSONFilePolicy``). Strategy kicks take the `$` Address. Policy selects the store, not a second Address.

App tests and previews isolate through StateManagement's TestingSupport (I9): silence the strategy, no store is touched. Production Persistence identity is the Policy static, resolved at `onRead`. `SharedEnvironment()` stays production.

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
