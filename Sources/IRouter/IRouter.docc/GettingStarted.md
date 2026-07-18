# Getting Started

Define typed routes, host a router, and navigate from the SwiftUI environment.

## Add the package

Add IRouter with Swift Package Manager and link the `IRouter` product to an iOS 17, macOS 14, or newer target:

```swift
dependencies: [
    .package(url: "https://github.com/ibabyblue/IRouter.git", from: "0.2.0")
]
```

IRouter has no external dependencies.

## Define route identity

A route must be `Hashable` so `NavigationStack` can identify path values and `Sendable` so transaction values satisfy Swift 6 concurrency rules:

```swift
enum AppRoute: Hashable, Sendable {
    case home
    case article(id: UUID)
    case profile(username: String)
    case settings
}
```

Associated values become part of route identity. Choose values that describe navigation state rather than mutable view models.

## Host the root router

Create ``IRouter`` with SwiftUI state and render it through ``IRouterView``:

```swift
@MainActor
struct AppRoot: View {
    @State private var router = IRouter<AppRoute>(root: .home)

    var body: some View {
        IRouterView(router: router) { route in
            destination(for: route)
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .home:
            HomeView()
        case .article(let id):
            ArticleView(id: id)
        case .profile(let username):
            ProfileView(username: username)
        case .settings:
            SettingsView()
        }
    }
}
```

The destination builder must handle every route that may become the root, a pushed destination, or modal content.

## Navigate from a destination

``IRouterView`` injects the current router level into the environment:

```swift
@MainActor
struct HomeView: View {
    @Environment(IRouter<AppRoute>.self) private var router

    var body: some View {
        VStack {
            Button("Article") {
                router.push(.article(id: UUID()))
            }
            Button("Settings") {
                router.sheet(.settings)
            }
        }
    }
}
```

Use router APIs rather than mutating ``IRouter/path`` or ``IRouter/modalContext``. Both properties are read-only outside the package so all changes retain transaction guarantees.

## Continue learning

Read <doc:TransactionalNavigation> for options and outcomes, <doc:FiltersAndRedirects> for policy routing, and <doc:ModalAndNestedRouters> for modal ownership.
