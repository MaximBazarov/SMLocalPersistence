# SMLocalPersistence

Local persistence for StateManagement. A Satellite: it owns the store, the core owns the AsyncStrategy seam.

This glossary holds only the terms this package adds. Every other word is StateManagement's vocabulary, defined in that package's `CONTEXT.md`.

## Language

**Persistence identity**:
Which store an Address writes: UserDefaults `.standard` or a named suite, a Keychain service, or a JSON root. Resolved at `onRead`. Distinct from AsyncOperation Identity.
_Avoid_: Identity (unqualified), AsyncOperation Identity, Policy (when you mean only the store locator), using this for the whole Policy value, UserDefaultsConfiguration, UseUserDefaults

**IsolatedPersistence**:
A test and preview overlay of Persistence identity. Owns the Environments it creates. Not State. Not production.
_Avoid_: Use* as this overlay, ClearUserDefaultsSuite as this teardown, a TestingSupport product, treating this as Environment isolation, stacking core seedEnvironment on isolation
