# ``SMLocalPersistence``

Local-persistence Satellite for StateManagement: UserDefaults, Keychain, and JSON-file.

Back a Value with `@AsyncState(.userDefaults)` or an app Policy static (``KeychainPolicy``, ``JSONFilePolicy``). Strategy kicks take the `$` Address. Policy selects the store, not a second Address.

App tests and previews isolate stores with a unique Persistence identity per Container through the public Policy initializers. Production Persistence identity is the Policy static, resolved at `onRead`. `SharedEnvironment()` stays production.

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

## Durable UserDefaults addresses

Conform a Container to ``StableUserDefaultsContainer`` to give each persisted
property a permanent name. Map both its backing and projected key paths to the
same name. Names must be unique within the suite and stable across releases.
Containers without conformance retain key-path description keys, which can
include process-specific getter addresses in optimized builds. No automatic
migration is performed. Keychain and JSON-file identities are unchanged.
