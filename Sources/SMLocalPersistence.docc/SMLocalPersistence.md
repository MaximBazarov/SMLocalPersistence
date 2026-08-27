# SMLocalPersistence

Local-persistence Satellite for StateManagement: UserDefaults, Keychain, and JSON-file.

Back a Value with `@AsyncState(.userDefaults)` or an app Policy static (``KeychainPolicy``, ``JSONFilePolicy``). Address names the Value. Policy selects the store, not a second Address.

Tests and previews use ``IsolatedPersistence``. It overlays Persistence identity before first `onRead`. Production Containers stay unchanged. `SharedEnvironment()` stays production.
