# SMLocalPersistence

UserDefaults persistence for [StateManagement](https://github.com). A Satellite: it owns the store. Core owns the Source seam.

## Source

```swift
final class Prefs: StateContainer {
    @AsyncState(.userDefaults) var theme: String = "system"
}
```

Values are `Codable`. The UserDefaults key is the Address (`smud.{path}` / `smud.{path}#{key}`). Load on first read or `preheat`. A Sync write to a bound Address persists once at notify.

Tests and previews perform `UseUserDefaults` with a named suite before first load, and `ClearUserDefaultsSuite` on teardown. Do not clear `.standard`.

## Requirements

- Swift 6.2+
- macOS 12+, iOS 17+
- StateManagement 1.0.0 (harness uses a path dependency)
