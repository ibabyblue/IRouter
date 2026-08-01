# IRouter

IRouter is a SwiftUI router for typed, transactional stack and modal navigation. It resolves ordered filters before committing, reports structured outcomes, owns hierarchical child routers for nested modals, and keeps router state synchronized with native SwiftUI presentation behavior.

## Features

- Typed `Hashable & Sendable` routes
- Atomic stack, sheet, and full-screen-cover transactions
- Ordered allow, block, and redirect filters
- Redirect cycle detection and a bounded redirect chain
- Structured committed, blocked, deduplicated, and rejected outcomes
- One direct modal per router with inherited child routers for nesting
- Hierarchical dismissal and stale-context protection
- Native interactive dismissal, modal replacement animation, and system back synchronization
- Independent router switching without recreating `IRouterView`
- Swift 6 main-actor isolation with iOS and macOS support

## Requirements

| Toolchain or platform | Minimum |
| --- | --- |
| iOS | 17.0 |
| macOS | 14.0 |
| Swift | 6.0 |
| Xcode | 16.0 or newer |

## Installation

In Xcode, choose **File → Add Package Dependencies** and enter the repository URL.

To add IRouter in `Package.swift`, declare the package dependency:

```swift
dependencies: [
    .package(
        url: "https://github.com/ibabyblue/IRouter.git",
        from: "0.2.0"
    )
]
```

Then add the IRouter product to your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "IRouter", package: "IRouter")
        ]
    )
]
```

The package has no external dependencies.

## Quick Start

```swift
import IRouter
import SwiftUI

enum AppRoute: Hashable, Sendable {
    case home
    case detail(id: String)
    case login
    case settings
}

@MainActor
struct AppRoot: View {
    @State private var router = IRouter<AppRoute>(root: .home)

    var body: some View {
        IRouterView(router: router) { route in
            switch route {
            case .home:
                Button("Open detail") {
                    router.push(.detail(id: "42"))
                }
            case .detail(let id):
                Text("Detail \(id)")
            case .login:
                Text("Login")
            case .settings:
                Text("Settings")
            }
        }
    }
}
```

`IRouterView` injects the router for the current hierarchy level into the SwiftUI environment:

```swift
@Environment(IRouter<AppRoute>.self) private var router
```

Use `push`, `sheet`, `fullScreenCover`, `pop`, `popToRoot`, and `dismiss` instead of mutating `path` or `modalContext` directly.

## Filters

Filters run in registration order before state changes. The first block or redirect ends the current pass; redirected destinations restart from the first filter.

```swift
import Observation

@MainActor
@Observable
final class AuthModel {
    var isLoggedIn = false
}

@MainActor
func makeRouter(auth: AuthModel) -> IRouter<AppRoute> {
    IRouter(root: .home, filters: [
        IRouterFilter { route, _ in
            if case .settings = route, !auth.isLoggedIn {
                return .redirect(.login, .sheet)
            }
            return .allow
        },
    ])
}
```

Router and filter handlers are main-actor isolated, so filters may inspect main-actor application state synchronously.

## Options and Outcomes

Use `.deduplicateTop` to avoid appending a final push that matches the current top route. Use `.dismissPresented` to replace a final modal or dismiss the direct modal before a final push:

```swift
let outcome = router.push(
    .detail(id: "42"),
    options: [.deduplicateTop, .dismissPresented]
)
```

Navigation returns `IRouterNavigationOutcome`: `.committed`, `.blocked`, `.deduplicated`, or `.rejected`. Options are evaluated against the final destination after redirects. Every noncommitted outcome preserves router state.

Each router owns at most one direct modal. Its `IRouterContext` owns a child router for stack navigation and further modal levels inside that presentation.

## Documentation

The DocC catalog contains the complete integration and behavior reference:

- [Getting Started](Sources/IRouter/IRouter.docc/GettingStarted.md)
- [Transactional Navigation](Sources/IRouter/IRouter.docc/TransactionalNavigation.md)
- [Filters and Redirects](Sources/IRouter/IRouter.docc/FiltersAndRedirects.md)
- [Modal and Nested Routers](Sources/IRouter/IRouter.docc/ModalAndNestedRouters.md)
- [SwiftUI Integration](Sources/IRouter/IRouter.docc/SwiftUIIntegration.md)
- [Platform Behavior](Sources/IRouter/IRouter.docc/PlatformBehavior.md)
- [Migration from 0.0.4](Sources/IRouter/IRouter.docc/MigrationGuide.md)

Build the documentation archive with:

```bash
xcodebuild docbuild \
  -scheme IRouter \
  -destination 'generic/platform=iOS Simulator'
```

## Example

Open `Example/IRouterDemo.xcodeproj` to run the Stack, Filters, Modals, Nested, and Routers labs on iOS or macOS. The project links this repository as a local package and includes live UI regression tests in its shared scheme.

See the [Example guide](Example/README.md) for the scenario map and verification commands.

## License

IRouter is available under the MIT license. See [LICENSE](LICENSE).

Release history is maintained in [CHANGELOG.md](CHANGELOG.md).
