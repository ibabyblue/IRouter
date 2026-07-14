# IRouter Navigation State Machine Design

**Date:** 2026-07-14

**Status:** Approved

**Platforms:** iOS 17+, macOS 14+

**Toolchain:** Swift tools 6.0, Swift 6.0, Xcode 16.x

## 1. Goal

Rebuild IRouter's navigation core around a single valid state model and a two-phase navigation transaction. The new design must eliminate redirect recursion, partial state mutations, competing modal presentations, child-router dismissal failures, and the current Swift concurrency mismatch without adding third-party dependencies.

Breaking API changes are allowed. Invalid or ambiguous APIs from 0.0.4 do not need compatibility shims.

## 2. Non-Goals

- URL and universal-link parsing.
- Cross-tab coordination.
- Alert and confirmation-dialog routing.
- Custom transitions.
- Async filters.
- Navigation state persistence or restoration.
- UIKit navigation integration.
- Interception of the system back gesture.

## 3. Design Invariants

1. Every `IRouter` owns one push path and at most one directly presented modal.
2. A modal owns a child router; nested modals are represented by the child router's own modal state.
3. Public clients cannot directly mutate router state.
4. Filters and redirect resolution complete before any state is mutated.
5. A blocked, rejected, cyclic, or deduplicated navigation never produces partial state changes.
6. Redirect resolution is iterative and bounded; user-defined filters cannot overflow the call stack.
7. All filters execute on the main actor, matching the router and ordinary SwiftUI application state.
8. SwiftUI never has more than one active modal presentation host per router level.
9. Dismissal always removes exactly one visible navigation layer.
10. Stale child routers and stale dismissal callbacks cannot modify a newer modal.

## 4. Public Model

### 4.1 Router State

```swift
@MainActor
@Observable
public final class IRouter<Route: Hashable & Sendable> {
    public let root: Route
    public private(set) var path: [Route]
    public private(set) var modalContext: IRouterContext<Route>?
}
```

`path` and `modalContext` are observable but externally read-only. Forward navigation must use router methods. `IRouterView` owns an internal path binding that accepts only path contraction from SwiftUI, which covers the system back button and back gesture without allowing `NavigationLink(value:)` to bypass filters.

### 4.2 Presentation Types

`IRouterPresentation` continues to describe a navigation request:

```swift
public enum IRouterPresentation: Hashable, Sendable {
    case push
    case sheet
    case fullScreenCover
}
```

The persistent modal state uses a separate type so `.push` cannot appear in a modal context:

```swift
public enum IRouterModalStyle: Hashable, Sendable {
    case sheet
    case fullScreenCover
}
```

`IRouterContext` exposes immutable presentation information:

```swift
@MainActor
public final class IRouterContext<Route: Hashable & Sendable>: Identifiable {
    public let id: UUID
    public let route: Route
    public let style: IRouterModalStyle
    public let childRouter: IRouter<Route>
}
```

Only the module can construct contexts.

### 4.3 Navigation Options

The ambiguous `flush` and separate `dedup` Boolean parameters are replaced by typed options:

```swift
public struct IRouterNavigationOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int)

    public static let deduplicateTop: Self
    public static let dismissPresented: Self
}
```

- `deduplicateTop` applies only when the final filtered destination is a push.
- `dismissPresented` clears a current modal before a final push, or safely replaces it before a final modal presentation.
- Options belong to the complete navigation transaction and therefore survive redirects.

### 4.4 Navigation Entry Points

```swift
@discardableResult
public func navigate(
    to route: Route,
    as presentation: IRouterPresentation,
    options: IRouterNavigationOptions = []
) -> IRouterNavigationOutcome<Route>

@discardableResult
public func push(
    _ route: Route,
    options: IRouterNavigationOptions = []
) -> IRouterNavigationOutcome<Route>

@discardableResult
public func sheet(
    _ route: Route,
    options: IRouterNavigationOptions = []
) -> IRouterNavigationOutcome<Route>

@available(macOS, unavailable, message: "Full-screen cover is unavailable on macOS")
@discardableResult
public func fullScreenCover(
    _ route: Route,
    options: IRouterNavigationOptions = []
) -> IRouterNavigationOutcome<Route>
```

iOS also exposes `fullScreenCover`. On macOS that convenience method is unavailable. A dynamic macOS request using `.fullScreenCover` returns an unsupported-presentation failure and leaves state unchanged.

The following 0.0.4 APIs are removed:

- `push(_:dedup:flush:)`
- `sheet(_:flush:)`
- `fullScreenCover(_:flush:)`
- `dismissAndPush(_:)`
- Public setters for `path`, `sheetContext`, and `coverContext`

### 4.5 Outcomes

```swift
public struct IRouterDestination<Route: Hashable & Sendable>: Hashable, Sendable {
    public let route: Route
    public let presentation: IRouterPresentation

    public init(route: Route, presentation: IRouterPresentation)
}

public enum IRouterNavigationFailure<Route: Hashable & Sendable>: Hashable, Sendable {
    case redirectCycle(chain: [IRouterDestination<Route>])
    case redirectLimitExceeded(
        chain: [IRouterDestination<Route>],
        limit: Int
    )
    case modalAlreadyPresented(current: IRouterDestination<Route>)
    case unsupportedPresentation(IRouterPresentation)
}

public enum IRouterNavigationOutcome<Route: Hashable & Sendable>: Hashable, Sendable {
    case committed(IRouterDestination<Route>)
    case blocked(IRouterDestination<Route>)
    case deduplicated(IRouterDestination<Route>)
    case rejected(IRouterNavigationFailure<Route>)
}
```

`committed` means the router accepted and stored the final desired state. It does not claim that an in-progress SwiftUI dismissal animation has completed.

Failures distinguish at least:

- Redirect cycle, including the redirect chain.
- Redirect limit exceeded, including the redirect chain and limit.
- Modal already presented, including the current modal destination.
- Unsupported presentation on the current platform.

All destination, outcome, and failure values are `Hashable & Sendable`.

## 5. Main-Actor Filter Contract

```swift
public struct IRouterFilter<Route: Hashable & Sendable>: Sendable {
    public enum Result: Sendable {
        case allow
        case block
        case redirect(Route, IRouterPresentation)
    }

    public init(
        _ handler: @MainActor @Sendable @escaping
            (Route, IRouterPresentation) -> Result
    )
}
```

This contract lets filters synchronously read ordinary `@MainActor` authentication, feature-flag, loading, and analytics state. Filters remain synchronous; asynchronous authorization belongs outside the router.

Child routers inherit the same immutable filter array.

## 6. Navigation Transaction

Every public navigation method creates one internal request containing route, presentation, and options.

### 6.1 Resolution Phase

The resolution phase does not mutate router state:

1. Start with the requested destination.
2. Insert the destination into a visited set and append it to the redirect chain.
3. Run filters in registration order.
4. `.allow` produces the final destination.
5. `.block` returns `.blocked` for the destination at which the block occurred.
6. `.redirect` restarts the complete filter chain with the redirected destination.
7. A destination already in the visited set returns a redirect-cycle failure.
8. At most 32 redirect results are accepted. A 33rd redirect returns a redirect-limit failure, even if every generated route is unique.

Resolution uses a loop, not recursive calls to router entry points.

### 6.2 Commit Phase

The commit phase runs only after successful resolution:

- Final push plus `deduplicateTop` and a matching stack top returns `.deduplicated` without state changes.
- Final modal while another modal exists, without `dismissPresented`, returns `.rejected(.modalAlreadyPresented)` without state changes.
- Final push plus `dismissPresented` clears the desired modal state and appends the route in the same main-actor transaction.
- Final modal plus `dismissPresented` replaces the desired modal context. The presentation coordinator serializes the visible transition.
- Successful final push appends exactly once.
- Successful final modal creates exactly one context and one child router.

No filter is run during commit, and no commit path re-enters public navigation methods.

## 7. Dismissal Model

`dismiss()` removes one visible level using this order:

1. If the current router presents a modal, clear that modal.
2. Otherwise, if its push path is non-empty, remove the last route.
3. Otherwise, if it is a modal child router, ask its parent to dismiss the context that owns it.
4. Otherwise, return unchanged.

```swift
public enum IRouterDismissOutcome: Hashable, Sendable {
    case dismissedPresentedModal
    case popped
    case dismissedFromParent
    case unchanged
}
```

Each child router receives a private main-actor dismissal action. The action weakly captures the parent and carries the context ID. The parent clears its modal only if the current context still has that ID. This prevents retain cycles and protects newer presentations from stale child callbacks.

Interactive SwiftUI dismissal reaches the same ID-checked router method. Programmatic, interactive, and child-root dismissal therefore share one source of truth.

`pop()` and `popToRoot()` return whether they changed the path.

## 8. SwiftUI Presentation Coordinator

`IRouterView` maps desired router state to actual SwiftUI presentation through an internal, testable `IRouterPresentationCoordinator`.

The coordinator maintains one active context, its visibility acknowledgement, and one optional pending context. Its effective phases are:

```text
idle
presenting(active)
replacingBeforeAppearance(active, replacement)
dismissing(active, pending)
```

Rules:

- Desired nil while visible active starts dismissal; before appearance it clears directly.
- Desired B while visible active A stores B as pending and first dismisses A.
- Modal content reports `presentationDidAppear(id:)`. If desired state changes before A actually appears, the coordinator replaces A directly because SwiftUI is not guaranteed to emit `onDismiss` for a presentation that never became visible.
- Desired C while A is dismissing replaces pending B with C.
- Desired nil while A is dismissing removes the pending context.
- The `onDismiss` for A's active dismissal presents the latest pending context, if any.
- An `onDismiss` callback whose style does not match the active dismissal is ignored.
- Interactive dismissal notifies the router using the dismissed context ID.

The coordinator is a rendering adapter only. It never runs filters, creates routes, or changes navigation policy.

Each recursive `IRouterView` owns its own coordinator, so nested modal levels serialize independently.

## 9. NavigationStack Synchronization

The `NavigationStack` binding is internal to `IRouterView`:

- A new path that is a prefix of the current path is accepted as a system-driven pop.
- An identical path is ignored.
- A growing or otherwise replaced path is rejected because it would bypass filters and outcomes.

README and Demo must use buttons or commands that call router methods for forward navigation. `NavigationLink(value:)` is explicitly unsupported because SwiftUI writes directly to the bound path without a filter hook.

## 10. Platform Behavior

- Package manifest uses `swift-tools-version: 6.0` and explicitly selects Swift language mode 6.
- Minimum deployment targets remain iOS 17 and macOS 14.
- Full-screen cover is supported only on iOS.
- macOS cannot accumulate an invisible full-screen-cover context.
- Source, tests, Demo, README, and changelog use the same toolchain claims.
- No third-party runtime or test dependencies are introduced.

## 11. Demo Application

The Demo becomes an iOS and macOS interactive regression application for the public API. It must use only normal `IRouterView` composition and must not add competing `.sheet` or `.fullScreenCover` modifiers around it.

The first screen is the actual test surface, not a marketing or explanatory page. iOS uses a five-item `TabView`: Stack, Filters, Modals, Nested, and Multiple Routers. macOS uses a `NavigationSplitView` whose sidebar contains the same five destinations. Platform-specific behavior is shown inside the Modals screen instead of adding a sixth destination. Each scenario uses compact native controls, SF Symbols, stable state rows, and accessibility identifiers. State inspection remains unframed and readable rather than being nested inside decorative cards.

### 11.1 Screens

1. **Stack**
   - Push multiple routes.
   - Deduplicate the top route.
   - Pop and pop to root.
   - Display the latest navigation and dismissal outcomes.

2. **Filters**
   - Allow and block.
   - Redirect to a different presentation.
   - Read a real `@MainActor` authentication state.
   - Demonstrate a self-cycle and a two-route cycle without crashing.
   - Show the returned failure and redirect chain.

3. **Modals**
   - Present sheet and full-screen cover on iOS.
   - Reject a second modal without `dismissPresented`.
   - Safely replace sheet with cover and cover with sheet.
   - Trigger rapid A -> B -> C replacement and show that only C appears after dismissal.

4. **Nested Router**
   - Push inside a modal using the child router.
   - `dismiss()` first pops the child path.
   - `dismiss()` at the child root closes the parent modal.
   - Present and dismiss at least three nested modal levels.

5. **Multiple Routers**
   - Two independent tab routers.
   - Actions and modal states remain isolated.

6. **Platform**
   - macOS omits full-screen-cover controls.
   - Shared screens run on both supported platforms.

### 11.2 Demo Quality Requirements

- Every command displays the resulting path, current modal, child depth, and latest outcome.
- Buttons are disabled when an action is structurally unavailable rather than intentionally testing rejection.
- Intentional rejection and cycle examples remain enabled and label their expected result.
- Demo code contains no unsafe concurrency annotations, arbitrary presentation delays, or manual bindings to router state.
- Existing duplicated modal modifiers and `DispatchQueue.main.asyncAfter` presentation timing are removed.
- Route names and outcome formatting are centralized to keep screens readable.
- Controls used by UI tests have stable accessibility identifiers; dynamic route text is not used as the sole selector.

## 12. Test Strategy

### 12.1 Router Unit Tests

- Push, pop, pop-to-root, and final-target deduplication.
- Filter ordering and short-circuit behavior.
- A filter reading `@MainActor` state as a compile-time regression test.
- Block with `dismissPresented` leaves every state value unchanged.
- One-step and multi-step redirects.
- Options applied to the final redirected destination.
- Self-cycle, two-node cycle, and 32-redirect limit.
- Modal rejection without replacement.
- Push dismissal and same-style/cross-style modal replacement.
- Child-root dismissal, child-path pop, stale-child protection, and three-level nesting.
- Unsupported macOS presentation leaves state unchanged.
- Invalid forward path synchronization is rejected; system path contraction is accepted.

### 12.2 Presentation Coordinator Tests

- Idle to active and active to idle.
- A to B waits for A's dismissal callback.
- A replaced before its appearance acknowledgement switches directly to B and never waits for an `onDismiss` callback.
- A to B to C retains only C as pending.
- Pending presentation cancellation.
- Stale callback rejection.
- Interactive dismissal synchronization.
- Sheet-to-cover and cover-to-sheet serialization on iOS.

### 12.3 Build Matrix

- macOS SwiftPM tests from a clean scratch path.
- iOS simulator tests for the package scheme.
- Demo Debug and Release builds for a generic iOS simulator.
- Demo Debug and Release builds for macOS.
- macOS package build.
- A compile fixture covering platform availability and the main-actor filter contract.

### 12.4 iOS UI Integration Tests

Add a focused `IRouterDemoUITests` target with deterministic accessibility-based tests for behavior that cannot be proven by state-machine tests alone:

- A child router at its modal root dismisses the owning sheet.
- Replacing sheet A with full-screen cover B waits for A to disappear before B appears.
- Rapid A -> B -> C replacement never presents B after A finishes dismissing and eventually presents C.
- Interactive sheet dismissal clears the visible modal state in the Demo inspector.

Tests use `waitForExistence` and disappearance predicates. They do not use fixed sleeps.

## 13. Documentation and Migration

README must describe the new state model, options, outcomes, Filter actor contract, dismiss order, nesting behavior, macOS limitation, and unsupported `NavigationLink(value:)` behavior.

Add `CHANGELOG.md` with a breaking-change entry and a migration table:

| 0.0.4 | New API |
|---|---|
| `dedup: true` | `options: [.deduplicateTop]` |
| `flush: true` | `options: [.dismissPresented]` |
| `dismissAndPush(route)` | `push(route, options: [.dismissPresented])` |
| `sheetContext` / `coverContext` | Read-only `modalContext` and `style` |
| Direct `path` mutation | Router navigation and pop APIs |

The next release should use a minor pre-1.0 version bump because the public API is intentionally breaking. Tagging and publishing are outside this implementation scope unless requested separately.

## 14. Acceptance Criteria

- No public operation can create two direct modal states in one router.
- No filter configuration can cause recursive stack overflow.
- No failed navigation changes router state.
- Main-actor application state is directly usable in filters under Swift 6 strict concurrency.
- A modal child router can close its owning modal without `Environment(\.dismiss)`.
- Rapid modal replacement is serialized and stale callbacks are harmless.
- macOS never stores an invisible full-screen-cover state.
- All new unit tests, focused UI integration tests, and the complete platform build matrix pass.
- Demo exercises every public behavior without private state mutation or duplicate presentation modifiers.
- README, changelog, manifest, and compiled API agree on supported platforms and toolchain.
