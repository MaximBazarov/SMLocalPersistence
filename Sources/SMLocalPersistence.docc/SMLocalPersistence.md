# SMLocalPersistence

UserDefaults KVS Satellite for StateManagement.

Source a Value with `@AsyncState(.userDefaults)`. Address names the Value. Policy selects UserDefaults, not a second Address. The UserDefaults key is the Address.

Tests and previews use ``IsolatedPersistence``. It overlays Persistence identity before first `provide`. Production Containers stay unchanged. `SharedEnvironment()` stays production.
