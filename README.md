# Insurance Claims

An iOS app that lists and displays insurance claims, backed by the
[JSONPlaceholder](https://jsonplaceholder.typicode.com/posts) `/posts` endpoint
used as mock claims data.

## Requirements

- Xcode 14+
- [Carthage](https://github.com/Carthage/Carthage)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (used to generate the
  `.xcodeproj` from `project.yml` — the project file itself isn't committed,
  same as the Carthage build output)
- [SwiftLint](https://github.com/realm/SwiftLint) (runs as a build phase;
  the build just prints a warning and continues if it isn't installed)

## Setup

```bash
brew install xcodegen carthage swiftlint
carthage bootstrap --platform iOS --use-xcframeworks --no-use-binaries
xcodegen generate
open InsuranceClaims.xcodeproj
```

Run the `InsuranceClaims` scheme to launch the app, or `Cmd+U` to run the
`InsuranceClaimsTests` (unit) and `InsuranceClaimsAPITests` (functional,
hits the live API) targets.

## Architecture

MVVM-C:

- **Models** — `Claim`, decoded directly from the API's `posts` shape.
- **Networking** — `APIClient` (Alamofire-based request/decode), `Endpoint`,
  `NetworkError`, `SSLPinningManager` (builds Alamofire's `ServerTrustManager`
  for certificate pinning).
- **Cache** — `ClaimCache`, a per-page, time-boxed on-disk cache so repeat
  visits render instantly; a page is treated as empty and re-fetched once its
  entry goes stale.
- **Services** — `ClaimService`, the single point that decides cache vs.
  network and is what view models talk to. Networking code never leaks into
  the presentation layer.
- **Scenes** — one folder per screen (`ClaimsList`, `ClaimDetail`), each with
  a view model (plain Swift, unit-testable without any UI framework) and a
  Texture (`AsyncDisplayKit`) view controller. `ClaimsListViewModel` exposes
  its state and visible claims as RxSwift `BehaviorRelay`-backed observables;
  the view controller subscribes to them instead of using change-callback
  closures.
- **Application** — `AppCoordinator` owns navigation between scenes so view
  controllers never push one another directly.

## Pagination & search

The list requests 10 claims per page via the API's `_page`/`_limit`
parameters and loads the next page automatically as the user scrolls near the
bottom. The search bar filters already-loaded claims by title or description;
it does not issue new network requests. Typing is gated to a minimum of 3
characters and debounced 300ms (via RxSwift) before the filter runs, so the
list isn't re-filtered on every keystroke.

## Security hardening

- **TLS/certificate pinning** — `SSLPinningManager` configures Alamofire's
  `ServerTrustManager` with a custom evaluator that pins the API host's
  SubjectPublicKeyInfo hash, rejecting the connection if it doesn't match
  even when a rogue CA is trusted on the device. Rotate the pin in
  `SSLPinningManager` whenever the API's certificate is renewed with a new
  key pair (see the comment above `pinnedPublicKeyHashes`), and add a backup
  pin ahead of any planned rotation.
- **App Transport Security** — arbitrary loads are disabled; only the pinned
  host is allowed, over TLS 1.2+.
- **String obfuscation** — the API host and pinned key hash are stored
  XOR-masked (`ObfuscatedString`) rather than as plain string literals, so
  they don't show up directly under `strings` on the compiled binary.
- **Release hardening** — bitcode is disabled, the release build strips
  debug symbols (`STRIP_STYLE=all`) and compiles as a single whole module,
  which removes per-file symbol boundaries that make reverse engineering
  easier.

## Testing

- **Unit tests** (`InsuranceClaimsTests`) — Quick/Nimble specs covering every
  layer: models, networking (`APIClient`'s error mapping against a stubbed
  `URLProtocol`), `SSLPinningManager`'s evaluator (against offline-generated
  EC/RSA/DSA test certificates), the cache, both view models, the coordinator,
  the Texture cell/content nodes, and the list view controller's data source,
  delegate and error-recovery paths — currently ~98% line coverage on the app
  target. Some lines are intentionally left uncovered rather than chasing
  100% with fragile tests: `required init?(coder:)` boilerplate that calls
  `fatalError()`, and a couple of defensive `Security`-framework guards that
  only fire for certificate failures a valid test certificate can't produce.
- **Functional API tests** (`InsuranceClaimsAPITests`) — Quick/Nimble specs
  that call the live JSONPlaceholder API and assert on page size, field
  population and pagination behavior.

## Linting

[SwiftLint](https://github.com/realm/SwiftLint) runs as an Xcode build phase
(see `.swiftlint.yml`). It's non-blocking if SwiftLint isn't installed; run
`swiftlint lint` or `swiftlint lint --fix` from the repo root at any time to
check or auto-correct style locally.
