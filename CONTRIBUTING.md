# Contributing

Thank you for helping. SMLocalPersistence is persistence for [StateManagement](https://github.com/MaximBazarov/StateManagement). Read that package's [PHILOSOPHY.md](https://github.com/MaximBazarov/StateManagement/blob/main/PHILOSOPHY.md) first. Every change is judged against its pillars.

The library is pre-1.0. The public API is still in discussion and can change between versions. Expect that.

## Proposing an API or scope change

Open an issue with a proposal. Discuss it on this repo. After the issue is accepted, the library developer writes the ADR in [`docs/adr/`](docs/adr/). Then code.

The review decides the shape before the code exists. That saves you from building something we then turn down on a pillar.

Small changes do not need an ADR. Bug fixes, tests, doc comments, and typo fixes can go straight to a pull request.

## Build and test

You need Swift 6.2 or later, and Xcode (not Command Line Tools alone). This package depends on StateManagement.

- Build: `swift build`
- Test (macOS / host): `swift test`
- Test (iOS Simulator): `xcodebuild test -scheme SMLocalPersistence -destination 'platform=iOS Simulator,name=iPhone 17'`

CI runs the suite on a macOS **and** an iOS Simulator on every pull request (matrix in `.github/workflows/ci.yml`), so run both locally before opening one.

## Project layout

- `Sources/` the library.
- `Tests/` the tests.
- `docs/adr/` accepted contributor decisions. A README until a proposal is accepted.

## Code style

- Document every public symbol with a `///` doc comment. These show up in Xcode while people write code, so they are part of the API, not an extra. If a symbol is hard to describe in one simple sentence, that is a sign to redesign it, not to write a longer comment.
- Match the style of the code around you.
- Keep prose simple and short: simple words, short sentences, the main point first.

## Pull requests

- Branch off `main`.
- Keep each pull request small and about one thing. Small is easier to review and to reason about, and it lands faster.
- Link the issue. Link the ADR once the library developer has written it.
- Make sure the build and tests pass.
- In the description, say why, not just what.

## Reporting bugs and ideas

Open an issue. For a bug, include the smallest code that shows it, what you expected, and what happened instead. For an idea, expect the pillars: say what it buys the user, and why composing the parts we already have is not enough.

## Be kind

Be respectful and assume good intent. We are all here to make a small, sharp library.
