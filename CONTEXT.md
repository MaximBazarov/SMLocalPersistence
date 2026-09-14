# SMLocalPersistence

Local persistence for StateManagement. A Satellite: it owns the store, the core owns the AsyncStrategy seam.

This glossary holds only the terms this package adds. Every other word is StateManagement's vocabulary, defined in that package's `CONTEXT.md`.

## Language

**Persistence identity**:
Which store an Address writes: UserDefaults `.standard` or a named suite, a Keychain service, or a JSON root. Lives on Policy, resolved at `onRead`. App tests and previews isolate through TestingSupport (I9); the Satellite suite carries a unique identity per test Container through the public Policy initializers. Distinct from AsyncOperation Identity.
_Avoid_: Identity (unqualified), AsyncOperation Identity, Policy (when you mean only the store locator), using this for the whole Policy value, UserDefaultsConfiguration, UseUserDefaults, IsolatedPersistence as an overlay of this
