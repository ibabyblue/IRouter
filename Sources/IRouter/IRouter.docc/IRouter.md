# ``IRouter``

Build typed SwiftUI stack and modal navigation from atomic router transactions.

## Overview

IRouter owns a route-typed `NavigationStack` path and one directly presented modal at each router level. Navigation requests resolve an ordered filter chain before committing, so a blocked redirect, cycle, platform rejection, or modal conflict never partially mutates state.

```swift
import IRouter
import SwiftUI

enum AppRoute: Hashable, Sendable {
    case home
    case detail(id: String)
    case settings
}

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
            case .settings:
                Text("Settings")
            }
        }
    }
}
```

The router and its filter handlers are main-actor isolated. Routes must conform to both `Hashable` and `Sendable`.

## Topics

### Essentials

- <doc:GettingStarted>
- ``IRouter``
- ``IRouterView``
- ``IRouterDestination``

### Transactions

- <doc:TransactionalNavigation>
- ``IRouterNavigationOptions``
- ``IRouterNavigationOutcome``
- ``IRouterNavigationFailure``
- ``IRouterDismissOutcome``

### Filters and Redirects

- <doc:FiltersAndRedirects>
- ``IRouterFilter``

### Modal Hierarchy

- <doc:ModalAndNestedRouters>
- ``IRouterContext``
- ``IRouterPresentation``
- ``IRouterModalStyle``

### Integration and Platforms

- <doc:SwiftUIIntegration>
- <doc:PlatformBehavior>

### Migration

- <doc:MigrationGuide>
