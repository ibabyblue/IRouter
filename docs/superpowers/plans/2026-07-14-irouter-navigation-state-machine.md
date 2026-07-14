# IRouter Navigation State Machine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace IRouter 0.0.4's mutable three-state router with a transactional, single-modal state machine, then rebuild the Demo as an iOS/macOS regression application with focused UI tests.

**Architecture:** Public navigation calls resolve filters and redirects without mutation, then commit one valid desired state. Each modal owns a child router with an ID-checked weak parent dismissal action. `IRouterView` renders desired modal state through a separate presentation coordinator that serializes SwiftUI dismissal and replacement.

**Tech Stack:** Swift tools 6.0, Swift 6 strict concurrency, Observation, SwiftUI, Swift Testing, XCTest UI testing, iOS 17+, macOS 14+, zero third-party dependencies.

## Global Constraints

- Breaking public API changes are allowed; do not retain deprecated 0.0.4 overloads.
- Keep the library `@MainActor`, type-safe, SwiftUI-only, and dependency-free.
- Every failed, blocked, cyclic, rejected, or deduplicated navigation leaves router state unchanged.
- Every router level owns at most one direct modal context.
- Redirect resolution is iterative, cycle-aware, and limited to 32 accepted redirects.
- Forward path growth must use router APIs; SwiftUI bindings may only contract the path.
- Full-screen cover is unavailable as a convenience API on macOS and rejected by dynamic navigation there.
- Demo must contain no duplicate presentation modifiers, unsafe concurrency annotations, fixed presentation delays, or direct router-state mutation.
- Use a clean scratch path for SwiftPM verification because the ignored local `.build` contains artifacts from the former lowercase module name.

---

## File Map

### Library

- Modify `Package.swift`: lower tools version to 6.0 while retaining iOS 17/macOS 14.
- Modify `Sources/IRouter/IRouterPresentation.swift`: public destinations, options, modal style, outcomes, failures, and dismissal outcome.
- Modify `Sources/IRouter/IRouterFilter.swift`: main-actor filter handler.
- Modify `Sources/IRouter/IRouterContext.swift`: immutable single-modal context and child-router parent dismissal wiring.
- Modify `Sources/IRouter/IRouter.swift`: resolution loop, atomic commit, stack synchronization, and dismissal state machine.
- Create `Sources/IRouter/IRouterPresentationCoordinator.swift`: desired-to-visible modal serialization.
- Modify `Sources/IRouter/IRouterView.swift`: guarded path binding and coordinator-driven sheet/cover rendering.

### Package Tests

- Replace `Tests/IRouterTests/IRouterTests.swift` with focused files below.
- Create `Tests/IRouterTests/TestSupport.swift`.
- Create `Tests/IRouterTests/IRouterNavigationTests.swift`.
- Create `Tests/IRouterTests/IRouterRedirectTests.swift`.
- Create `Tests/IRouterTests/IRouterModalTests.swift`.
- Create `Tests/IRouterTests/IRouterPresentationCoordinatorTests.swift`.

### Demo

- Modify `demo/IRouterDemo/IRouterDemoApp.swift`: multi-platform app entry.
- Modify `demo/IRouterDemo/ContentView.swift`: five-tab iOS shell and five-item macOS sidebar.
- Create `demo/IRouterDemo/DemoModel.swift`: routes, sections, auth state, outcome formatting, and accessibility IDs.
- Create `demo/IRouterDemo/DemoComponents.swift`: stable router inspector and compact command rows.
- Replace `demo/IRouterDemo/BasicDemo.swift` with `demo/IRouterDemo/StackDemo.swift`.
- Modify `demo/IRouterDemo/FilterDemo.swift`.
- Replace `demo/IRouterDemo/FlushDemo.swift` with `demo/IRouterDemo/ModalDemo.swift`.
- Replace `demo/IRouterDemo/TabDemo.swift` with `demo/IRouterDemo/NestedDemo.swift` and `demo/IRouterDemo/MultipleRoutersDemo.swift`.
- Modify `demo/IRouterDemo.xcodeproj/project.pbxproj`: new files, macOS support, and UI test target.
- Create `demo/IRouterDemo.xcodeproj/xcshareddata/xcschemes/IRouterDemo.xcscheme`: shared build/test scheme.
- Create `demo/IRouterDemoUITests/IRouterDemoUITests.swift`: real presentation integration coverage.

### Documentation

- Modify `README.md`: new public API, behavior contract, and migration guide.
- Create `CHANGELOG.md`: breaking unreleased entry.

---

### Task 1: Public Value Types and Swift 6.0 Baseline

**Files:**
- Modify: `Package.swift:1`
- Modify: `Sources/IRouter/IRouterPresentation.swift`
- Create: `Tests/IRouterTests/TestSupport.swift`
- Create: `Tests/IRouterTests/IRouterNavigationTests.swift`

**Interfaces:**
- Produces: `IRouterDestination`, `IRouterNavigationOptions`, `IRouterModalStyle`, `IRouterNavigationFailure`, `IRouterNavigationOutcome`, and `IRouterDismissOutcome`.
- Consumes: no new interfaces.

- [ ] **Step 1: Lower the manifest baseline and write public-value compile tests**

Change the manifest baseline and explicitly lock Swift language mode 6:

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "IRouter",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "IRouter", targets: ["IRouter"]),
    ],
    targets: [
        .target(name: "IRouter"),
        .testTarget(name: "IRouterTests", dependencies: ["IRouter"]),
    ],
    swiftLanguageModes: [.v6]
)
```

Create shared test routes in `TestSupport.swift`:

```swift
import Foundation
@testable import IRouter

enum TestRoute: Hashable, Sendable {
    case home
    case detail(Int)
    case settings
    case login
    case modal(String)
    case redirect(Int)
}

@MainActor
final class TestAuthState {
    var isLoggedIn = false
}
```

Create initial tests in `IRouterNavigationTests.swift`:

```swift
import Testing
@testable import IRouter

@Suite("Navigation values")
struct IRouterNavigationValueTests {
    @Test
    func destinationRetainsRouteAndPresentation() {
        let destination = IRouterDestination(
            route: TestRoute.detail(42),
            presentation: .push
        )

        #expect(destination.route == .detail(42))
        #expect(destination.presentation == .push)
    }

    @Test
    func navigationOptionsCompose() {
        let options: IRouterNavigationOptions = [
            .deduplicateTop,
            .dismissPresented,
        ]

        #expect(options.contains(.deduplicateTop))
        #expect(options.contains(.dismissPresented))
    }
}
```

- [ ] **Step 2: Run the new tests and verify they fail to compile**

Run:

```bash
swift test --scratch-path /private/tmp/irouter-task1 --filter IRouterNavigationValueTests
```

Expected: compilation fails because the new destination, options, outcome, failure, and modal-style types do not exist.

- [ ] **Step 3: Replace `IRouterPresentation.swift` with the complete public value model**

Implement these exact declarations:

```swift
import Foundation

public enum IRouterPresentation: Hashable, Sendable {
    case push
    case sheet
    case fullScreenCover
}

public enum IRouterModalStyle: Hashable, Sendable {
    case sheet
    case fullScreenCover

    var presentation: IRouterPresentation {
        switch self {
        case .sheet: .sheet
        case .fullScreenCover: .fullScreenCover
        }
    }
}

public struct IRouterDestination<Route: Hashable & Sendable>: Hashable, Sendable {
    public let route: Route
    public let presentation: IRouterPresentation

    public init(route: Route, presentation: IRouterPresentation) {
        self.route = route
        self.presentation = presentation
    }
}

public struct IRouterNavigationOptions: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let deduplicateTop = Self(rawValue: 1 << 0)
    public static let dismissPresented = Self(rawValue: 1 << 1)
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

public enum IRouterDismissOutcome: Hashable, Sendable {
    case dismissedPresentedModal
    case popped
    case dismissedFromParent
    case unchanged
}
```

- [ ] **Step 4: Run the value tests and the package build**

Run:

```bash
swift test --scratch-path /private/tmp/irouter-task1 --filter IRouterNavigationValueTests
swift build --scratch-path /private/tmp/irouter-task1-build
```

Expected: value tests pass and the package builds. Existing tests may still fail because they target the old API; do not delete them until Task 2 replaces their coverage.

- [ ] **Step 5: Commit the value model**

```bash
git add Package.swift Sources/IRouter/IRouterPresentation.swift Tests/IRouterTests/TestSupport.swift Tests/IRouterTests/IRouterNavigationTests.swift
git commit -m "refactor: define transactional router values"
```

---

### Task 2: Main-Actor Filters and Transactional Stack Navigation

**Files:**
- Modify: `Sources/IRouter/IRouterFilter.swift`
- Modify: `Sources/IRouter/IRouter.swift`
- Modify: `Sources/IRouter/IRouterView.swift`
- Modify: `Tests/IRouterTests/IRouterNavigationTests.swift`
- Create: `Tests/IRouterTests/IRouterRedirectTests.swift`
- Delete: `Tests/IRouterTests/IRouterTests.swift`

**Interfaces:**
- Consumes: Task 1 public value types.
- Produces: `navigate(to:as:options:)`, `push(_:options:)`, bounded redirect resolution, `pop() -> Bool`, `popToRoot() -> Bool`, and internal `synchronizePathFromUI(_:)`.

- [ ] **Step 1: Add failing stack and main-actor filter tests**

Add to `IRouterNavigationTests.swift`:

```swift
@Suite("Stack navigation")
struct IRouterStackTests {
    @Test @MainActor
    func pushCommitsDestination() {
        let router = IRouter<TestRoute>(root: .home)

        let outcome = router.push(.detail(1))

        #expect(outcome == .committed(.init(route: .detail(1), presentation: .push)))
        #expect(router.path == [.detail(1)])
    }

    @Test @MainActor
    func finalDestinationIsDeduplicatedWithoutMutation() {
        let router = IRouter<TestRoute>(root: .home)
        router.push(.detail(1))
        let before = router.path

        let outcome = router.push(.detail(1), options: [.deduplicateTop])

        #expect(outcome == .deduplicated(.init(route: .detail(1), presentation: .push)))
        #expect(router.path == before)
    }

    @Test @MainActor
    func filterCanReadMainActorState() {
        let auth = TestAuthState()
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, _ in
                route == .settings && !auth.isLoggedIn ? .block : .allow
            },
        ])

        #expect(router.push(.settings) == .blocked(.init(route: .settings, presentation: .push)))
        auth.isLoggedIn = true
        #expect(router.push(.settings) == .committed(.init(route: .settings, presentation: .push)))
    }

    @Test @MainActor
    func filtersRunInOrderAndStopAtFirstBlock() {
        var order: [Int] = []
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { _, _ in
                order.append(1)
                return .allow
            },
            IRouterFilter { _, _ in
                order.append(2)
                return .block
            },
            IRouterFilter { _, _ in
                order.append(3)
                return .allow
            },
        ])

        let outcome = router.push(.detail(1))

        #expect(outcome == .blocked(.init(route: .detail(1), presentation: .push)))
        #expect(order == [1, 2])
        #expect(router.path.isEmpty)
    }

    @Test @MainActor
    func popAndPopToRootReportMutation() {
        let router = IRouter<TestRoute>(root: .home)
        #expect(router.pop() == false)
        router.push(.detail(1))
        router.push(.detail(2))
        #expect(router.pop() == true)
        #expect(router.path == [.detail(1)])
        #expect(router.popToRoot() == true)
        #expect(router.path.isEmpty)
        #expect(router.popToRoot() == false)
    }

    @Test @MainActor
    func uiSynchronizationOnlyAcceptsPathContraction() {
        let router = IRouter<TestRoute>(root: .home)
        router.push(.detail(1))
        router.push(.detail(2))

        #expect(router.synchronizePathFromUI([.detail(1)]) == true)
        #expect(router.path == [.detail(1)])
        #expect(router.synchronizePathFromUI([.detail(1), .settings]) == false)
        #expect(router.path == [.detail(1)])
        #expect(router.synchronizePathFromUI([.settings]) == false)
        #expect(router.path == [.detail(1)])
    }
}
```

- [ ] **Step 2: Add failing redirect-resolution tests**

Create `IRouterRedirectTests.swift` with tests for one redirect, a self-cycle, a two-node cycle, and the hard limit:

```swift
import Testing
@testable import IRouter

@Suite("Redirect resolution")
struct IRouterRedirectTests {
    @Test @MainActor
    func redirectCommitsFinalDestination() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, _ in
                route == .settings ? .redirect(.login, .push) : .allow
            },
        ])

        let outcome = router.push(.settings)

        #expect(outcome == .committed(.init(route: .login, presentation: .push)))
        #expect(router.path == [.login])
        #expect(router.modalContext == nil)
    }

    @Test @MainActor
    func selfRedirectReturnsCycleWithoutMutation() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, presentation in
                .redirect(route, presentation)
            },
        ])

        let outcome = router.push(.settings)

        #expect(outcome == .rejected(.redirectCycle(chain: [
            .init(route: .settings, presentation: .push),
            .init(route: .settings, presentation: .push),
        ])))
        #expect(router.path.isEmpty)
        #expect(router.modalContext == nil)
    }

    @Test @MainActor
    func optionsApplyToFinalRedirectedDestination() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, _ in
                route == .settings ? .redirect(.detail(1), .push) : .allow
            },
        ])
        router.push(.detail(1))

        let outcome = router.push(
            .settings,
            options: [.deduplicateTop]
        )

        #expect(outcome == .deduplicated(.init(
            route: .detail(1),
            presentation: .push
        )))
        #expect(router.path == [.detail(1)])
    }

    @Test @MainActor
    func twoNodeRedirectReturnsCycle() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, presentation in
                switch route {
                case .detail(1): .redirect(.detail(2), presentation)
                case .detail(2): .redirect(.detail(1), presentation)
                default: .allow
                }
            },
        ])

        let outcome = router.push(.detail(1))

        #expect(outcome == .rejected(.redirectCycle(chain: [
            .init(route: .detail(1), presentation: .push),
            .init(route: .detail(2), presentation: .push),
            .init(route: .detail(1), presentation: .push),
        ])))
    }

    @Test @MainActor
    func thirtyThirdRedirectReturnsLimitFailure() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, presentation in
                guard case .redirect(let value) = route else { return .allow }
                return .redirect(.redirect(value + 1), presentation)
            },
        ])

        let outcome = router.push(.redirect(0))

        guard case .rejected(.redirectLimitExceeded(let chain, let limit)) = outcome else {
            Issue.record("Expected redirectLimitExceeded, got \(outcome)")
            return
        }
        #expect(limit == 32)
        #expect(chain.count == 34)
        #expect(chain.first?.route == .redirect(0))
        #expect(chain.last?.route == .redirect(33))
        #expect(router.path.isEmpty)
    }
}
```

- [ ] **Step 3: Run focused tests and verify the old implementation fails**

Run:

```bash
swift test --scratch-path /private/tmp/irouter-task2 --filter IRouterStackTests
swift test --scratch-path /private/tmp/irouter-task2 --filter IRouterRedirectTests
```

Expected: compilation fails on the new signatures and `modalContext`; the actor-state test also proves the old nonisolated `@Sendable` filter contract is invalid.

- [ ] **Step 4: Make the filter handler main-actor isolated**

Change the stored handler and initializer in `IRouterFilter.swift` to:

```swift
let handler: @MainActor @Sendable (Route, IRouterPresentation) -> Result

public init(
    _ handler: @MainActor @Sendable @escaping
        (Route, IRouterPresentation) -> Result
) {
    self.handler = handler
}
```

- [ ] **Step 5: Implement the transaction shell and stack commit path**

Refactor `IRouter.swift` around these members:

```swift
@MainActor
@Observable
public final class IRouter<Route: Hashable & Sendable> {
    static var redirectLimit: Int { 32 }

    public let root: Route
    public private(set) var path: [Route] = []
    public private(set) var modalContext: IRouterContext<Route>?

    private let filters: [IRouterFilter<Route>]
    private let dismissFromParent: (@MainActor @Sendable () -> Bool)?

    public init(root: Route, filters: [IRouterFilter<Route>] = []) {
        self.root = root
        self.filters = filters
        self.dismissFromParent = nil
    }

    init(
        root: Route,
        filters: [IRouterFilter<Route>],
        dismissFromParent: @escaping @MainActor @Sendable () -> Bool
    ) {
        self.root = root
        self.filters = filters
        self.dismissFromParent = dismissFromParent
    }
}
```

Implement `navigate` as one loop. The limit check must accept 32 redirects and reject the 33rd:

```swift
@discardableResult
public func navigate(
    to route: Route,
    as presentation: IRouterPresentation,
    options: IRouterNavigationOptions = []
) -> IRouterNavigationOutcome<Route> {
    var current = IRouterDestination(route: route, presentation: presentation)
    var visited: Set<IRouterDestination<Route>> = []
    var chain: [IRouterDestination<Route>] = []
    var redirectCount = 0

    while true {
        guard visited.insert(current).inserted else {
            return .rejected(.redirectCycle(chain: chain + [current]))
        }
        chain.append(current)

        switch runFilters(for: current) {
        case .allow:
            return commit(current, options: options)
        case .block:
            return .blocked(current)
        case .redirect(let route, let presentation):
            let redirected = IRouterDestination(
                route: route,
                presentation: presentation
            )
            guard redirectCount < Self.redirectLimit else {
                return .rejected(.redirectLimitExceeded(
                    chain: chain + [redirected],
                    limit: Self.redirectLimit
                ))
            }
            redirectCount += 1
            current = redirected
        }
    }
}
```

Add `push`, `pop`, `popToRoot`, and guarded UI synchronization:

```swift
@discardableResult
public func push(
    _ route: Route,
    options: IRouterNavigationOptions = []
) -> IRouterNavigationOutcome<Route> {
    navigate(to: route, as: .push, options: options)
}

@discardableResult
public func pop() -> Bool {
    guard !path.isEmpty else { return false }
    path.removeLast()
    return true
}

@discardableResult
public func popToRoot() -> Bool {
    guard !path.isEmpty else { return false }
    path.removeAll()
    return true
}

@discardableResult
func synchronizePathFromUI(_ newPath: [Route]) -> Bool {
    guard newPath != path,
          newPath.count < path.count,
          path.starts(with: newPath) else { return false }
    path = newPath
    return true
}
```

In this task, `commit` fully supports push. Until Task 3 adds the single-modal commit path, sheet and full-screen-cover destinations return `.rejected(.unsupportedPresentation(destination.presentation))`; no Task 2 test treats that interim behavior as final. Remove the old sheet/cover/dismiss methods so the package compiles against the new state properties:

```swift
private func commit(
    _ destination: IRouterDestination<Route>,
    options: IRouterNavigationOptions
) -> IRouterNavigationOutcome<Route> {
    guard destination.presentation == .push else {
        return .rejected(.unsupportedPresentation(destination.presentation))
    }
    if options.contains(.deduplicateTop), path.last == destination.route {
        return .deduplicated(destination)
    }
    if options.contains(.dismissPresented) {
        modalContext = nil
    }
    path.append(destination.route)
    return .committed(destination)
}

private func runFilters(
    for destination: IRouterDestination<Route>
) -> IRouterFilter<Route>.Result {
    for filter in filters {
        let result = filter.handler(
            destination.route,
            destination.presentation
        )
        if case .allow = result {
            continue
        }
        return result
    }
    return .allow
}
```

Replace `IRouterView` with a stack-only renderer during this task so removal of `sheetContext` and `coverContext` does not break the package before Task 4 adds the tested modal coordinator:

```swift
import SwiftUI

public struct IRouterView<Route: Hashable & Sendable, Content: View>: View {
    @Bindable private var router: IRouter<Route>
    private let destination: (Route) -> Content

    public init(
        router: IRouter<Route>,
        @ViewBuilder destination: @escaping (Route) -> Content
    ) {
        _router = Bindable(router)
        self.destination = destination
    }

    public var body: some View {
        NavigationStack(path: pathBinding) {
            destination(router.root)
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
        .environment(router)
    }

    private var pathBinding: Binding<[Route]> {
        Binding(
            get: { router.path },
            set: { _ = router.synchronizePathFromUI($0) }
        )
    }
}
```

- [ ] **Step 6: Delete the obsolete monolithic tests and run the focused suites**

Delete `Tests/IRouterTests/IRouterTests.swift`, then run:

```bash
swift test --scratch-path /private/tmp/irouter-task2
```

Expected: all Task 1 and Task 2 tests pass. There must be no recursion and no `nonisolated(unsafe)` test state.

- [ ] **Step 7: Commit the transaction engine**

```bash
git add Sources/IRouter/IRouterFilter.swift Sources/IRouter/IRouter.swift Sources/IRouter/IRouterView.swift Tests/IRouterTests
git commit -m "refactor: resolve navigation transactions atomically"
```

---

### Task 3: Single Modal State and Hierarchical Dismissal

**Files:**
- Modify: `Sources/IRouter/IRouterContext.swift`
- Modify: `Sources/IRouter/IRouter.swift`
- Create: `Tests/IRouterTests/IRouterModalTests.swift`

**Interfaces:**
- Consumes: Task 2 transaction engine and outcomes.
- Produces: read-only `modalContext`, `sheet`, iOS `fullScreenCover`, ID-checked parent dismissal, and one-layer `dismiss()`.

- [ ] **Step 1: Write failing modal atomicity tests**

Create `IRouterModalTests.swift` with:

```swift
import Testing
@testable import IRouter

@Suite("Modal transactions")
struct IRouterModalTests {
    @Test @MainActor
    func sheetCreatesOneTypedContext() {
        let router = IRouter<TestRoute>(root: .home)

        let outcome = router.sheet(.modal("A"))

        #expect(outcome == .committed(.init(route: .modal("A"), presentation: .sheet)))
        #expect(router.modalContext?.route == .modal("A"))
        #expect(router.modalContext?.style == .sheet)
        #expect(router.modalContext?.childRouter.root == .modal("A"))
    }

    @Test @MainActor
    func secondModalWithoutReplacementIsRejectedAtomically() {
        let router = IRouter<TestRoute>(root: .home)
        router.sheet(.modal("A"))
        let originalID = router.modalContext?.id

        let outcome = router.sheet(.modal("B"))

        #expect(outcome == .rejected(.modalAlreadyPresented(
            current: .init(route: .modal("A"), presentation: .sheet)
        )))
        #expect(router.modalContext?.id == originalID)
        #expect(router.modalContext?.route == .modal("A"))
    }

    @Test @MainActor
    func blockedDismissPresentedRequestLeavesModalUntouched() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, _ in route == .settings ? .block : .allow },
        ])
        router.sheet(.modal("A"))
        let originalID = router.modalContext?.id

        let outcome = router.push(.settings, options: [.dismissPresented])

        #expect(outcome == .blocked(.init(route: .settings, presentation: .push)))
        #expect(router.modalContext?.id == originalID)
        #expect(router.path.isEmpty)
    }

    @Test @MainActor
    func replacementCreatesNewDesiredContext() {
        let router = IRouter<TestRoute>(root: .home)
        router.sheet(.modal("A"))
        let originalID = router.modalContext?.id

        let outcome = router.sheet(.modal("B"), options: [.dismissPresented])

        #expect(outcome == .committed(.init(route: .modal("B"), presentation: .sheet)))
        #expect(router.modalContext?.id != originalID)
        #expect(router.modalContext?.route == .modal("B"))
    }

    @Test @MainActor
    func redirectCommitsFinalModalAndCarriesOptions() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, _ in
                route == .settings ? .redirect(.login, .sheet) : .allow
            },
        ])
        router.sheet(.modal("A"))

        let outcome = router.push(
            .settings,
            options: [.dismissPresented]
        )

        #expect(outcome == .committed(.init(route: .login, presentation: .sheet)))
        #expect(router.modalContext?.route == .login)
        #expect(router.modalContext?.style == .sheet)
        #expect(router.path.isEmpty)
    }

    #if os(macOS)
    @Test @MainActor
    func dynamicFullScreenCoverIsRejectedOnMacOS() {
        let router = IRouter<TestRoute>(root: .home)

        let outcome = router.navigate(
            to: .modal("cover"),
            as: .fullScreenCover
        )

        #expect(outcome == .rejected(.unsupportedPresentation(.fullScreenCover)))
        #expect(router.modalContext == nil)
    }
    #else
    @Test @MainActor
    func fullScreenCoverCreatesTypedContextOniOS() {
        let router = IRouter<TestRoute>(root: .home)

        let outcome = router.fullScreenCover(.modal("cover"))

        #expect(outcome == .committed(.init(
            route: .modal("cover"),
            presentation: .fullScreenCover
        )))
        #expect(router.modalContext?.style == .fullScreenCover)
    }
    #endif
}
```

- [ ] **Step 2: Write failing hierarchy and stale-child tests**

Append:

```swift
@Suite("Hierarchical dismissal")
struct IRouterDismissalTests {
    @Test @MainActor
    func childDismissPopsBeforeClosingParentModal() {
        let parent = IRouter<TestRoute>(root: .home)
        parent.sheet(.modal("A"))
        let child = parent.modalContext!.childRouter
        child.push(.detail(1))

        #expect(child.dismiss() == .popped)
        #expect(parent.modalContext != nil)
        #expect(child.path.isEmpty)
        #expect(child.dismiss() == .dismissedFromParent)
        #expect(parent.modalContext == nil)
    }

    @Test @MainActor
    func staleChildCannotDismissReplacement() {
        let parent = IRouter<TestRoute>(root: .home)
        parent.sheet(.modal("A"))
        let staleChild = parent.modalContext!.childRouter
        parent.sheet(.modal("B"), options: [.dismissPresented])
        let replacementID = parent.modalContext!.id

        #expect(staleChild.dismiss() == .unchanged)
        #expect(parent.modalContext?.id == replacementID)
        #expect(parent.modalContext?.route == .modal("B"))
    }

    @Test @MainActor
    func nestedDismissRemovesExactlyOneVisibleLevel() {
        let root = IRouter<TestRoute>(root: .home)
        root.sheet(.modal("level1"))
        let level1 = root.modalContext!.childRouter
        level1.sheet(.modal("level2"))
        let level2 = level1.modalContext!.childRouter

        #expect(level2.dismiss() == .dismissedFromParent)
        #expect(level1.modalContext == nil)
        #expect(root.modalContext != nil)
        #expect(level1.dismiss() == .dismissedFromParent)
        #expect(root.modalContext == nil)
    }
}
```

- [ ] **Step 3: Run modal tests and verify failure**

Run:

```bash
swift test --scratch-path /private/tmp/irouter-task3 --filter IRouterModalTests
swift test --scratch-path /private/tmp/irouter-task3 --filter IRouterDismissalTests
```

Expected: failures because the old contexts are split, child routers have no dismissal action, and block-with-dismiss currently mutates state.

- [ ] **Step 4: Implement immutable context creation with an ID-bound weak parent action**

Replace the context implementation with:

```swift
import Foundation

@MainActor
public final class IRouterContext<Route: Hashable & Sendable>: Identifiable {
    public let id: UUID
    public let route: Route
    public let style: IRouterModalStyle
    public let childRouter: IRouter<Route>

    init(
        route: Route,
        style: IRouterModalStyle,
        filters: [IRouterFilter<Route>],
        parent: IRouter<Route>
    ) {
        let id = UUID()
        self.id = id
        self.route = route
        self.style = style
        self.childRouter = IRouter(
            root: route,
            filters: filters,
            dismissFromParent: { [weak parent] in
                parent?.dismissModal(id: id) ?? false
            }
        )
    }
}
```

- [ ] **Step 5: Complete modal commit and dismissal in `IRouter`**

Add convenience methods:

```swift
@discardableResult
public func sheet(
    _ route: Route,
    options: IRouterNavigationOptions = []
) -> IRouterNavigationOutcome<Route> {
    navigate(to: route, as: .sheet, options: options)
}

@available(macOS, unavailable, message: "Full-screen cover is unavailable on macOS")
@discardableResult
public func fullScreenCover(
    _ route: Route,
    options: IRouterNavigationOptions = []
) -> IRouterNavigationOutcome<Route> {
    navigate(to: route, as: .fullScreenCover, options: options)
}
```

Complete `commit` with platform rejection before any mutation, push handling, and a single modal helper:

```swift
private func commit(
    _ destination: IRouterDestination<Route>,
    options: IRouterNavigationOptions
) -> IRouterNavigationOutcome<Route> {
    #if os(macOS)
    if destination.presentation == .fullScreenCover {
        return .rejected(.unsupportedPresentation(.fullScreenCover))
    }
    #endif

    switch destination.presentation {
    case .push:
        if options.contains(.deduplicateTop), path.last == destination.route {
            return .deduplicated(destination)
        }
        if options.contains(.dismissPresented) {
            modalContext = nil
        }
        path.append(destination.route)
        return .committed(destination)

    case .sheet:
        return commitModal(destination, style: .sheet, options: options)

    case .fullScreenCover:
        return commitModal(
            destination,
            style: .fullScreenCover,
            options: options
        )
    }
}

private func commitModal(
    _ destination: IRouterDestination<Route>,
    style: IRouterModalStyle,
    options: IRouterNavigationOptions
) -> IRouterNavigationOutcome<Route> {
    if let current = modalContext,
       !options.contains(.dismissPresented) {
        return .rejected(.modalAlreadyPresented(
            current: IRouterDestination(
                route: current.route,
                presentation: current.style.presentation
            )
        ))
    }

    modalContext = IRouterContext(
        route: destination.route,
        style: style,
        filters: filters,
        parent: self
    )
    return .committed(destination)
}
```

Implement `dismiss`, exact-ID clearing, and interactive synchronization:

```swift
@discardableResult
public func dismiss() -> IRouterDismissOutcome {
    if modalContext != nil {
        modalContext = nil
        return .dismissedPresentedModal
    }
    if pop() {
        return .popped
    }
    if dismissFromParent?() == true {
        return .dismissedFromParent
    }
    return .unchanged
}

@discardableResult
func dismissModal(id: UUID) -> Bool {
    guard modalContext?.id == id else { return false }
    modalContext = nil
    return true
}

func modalDidDismiss(id: UUID) {
    _ = dismissModal(id: id)
}
```

- [ ] **Step 6: Run all package tests**

Run:

```bash
swift test --scratch-path /private/tmp/irouter-task3
xcodebuild -scheme IRouter -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -derivedDataPath /private/tmp/irouter-task3-ios-tests CODE_SIGNING_ALLOWED=NO test
```

Expected: all navigation, redirect, modal, cover, and hierarchy tests pass on macOS and iOS.

- [ ] **Step 7: Commit the single-modal hierarchy**

```bash
git add Sources/IRouter/IRouterContext.swift Sources/IRouter/IRouter.swift Tests/IRouterTests/IRouterModalTests.swift
git commit -m "refactor: enforce hierarchical modal state"
```

---

### Task 4: Presentation Coordinator and Safe SwiftUI Rendering

**Files:**
- Create: `Sources/IRouter/IRouterPresentationCoordinator.swift`
- Modify: `Sources/IRouter/IRouterView.swift`
- Create: `Tests/IRouterTests/IRouterPresentationCoordinatorTests.swift`

**Interfaces:**
- Consumes: Task 3 `modalContext`, `style`, child router, `modalDidDismiss(id:)`, and path synchronization.
- Produces: `IRouterPresentationCoordinator.reconcile(desired:)`, style-filtered item access, interactive dismissal handling, and serialized `presentationDidDismiss(style:)`.

- [ ] **Step 1: Write failing coordinator transition tests**

Create `IRouterPresentationCoordinatorTests.swift`:

```swift
import Testing
@testable import IRouter

@Suite("Presentation coordinator")
struct IRouterPresentationCoordinatorTests {
    @Test @MainActor
    func replacementWaitsForCurrentDismissal() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        let contextA = router.modalContext!
        coordinator.reconcile(desired: contextA)
        coordinator.presentationDidAppear(id: contextA.id)

        router.sheet(.modal("B"), options: [.dismissPresented])
        let contextB = router.modalContext!
        coordinator.reconcile(desired: contextB)

        #expect(coordinator.presentedContext == nil)
        #expect(coordinator.pendingContext?.id == contextB.id)
        coordinator.presentationDidDismiss(style: .sheet)
        #expect(coordinator.presentedContext?.id == contextB.id)
        #expect(coordinator.pendingContext == nil)
    }

    @Test @MainActor
    func rapidReplacementKeepsOnlyLatestPendingContext() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidAppear(id: router.modalContext!.id)

        router.sheet(.modal("B"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)
        router.sheet(.modal("C"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)

        #expect(coordinator.pendingContext?.route == .modal("C"))
        coordinator.presentationDidDismiss(style: .sheet)
        #expect(coordinator.presentedContext?.route == .modal("C"))
    }

    @Test @MainActor
    func interactiveDismissalClearsMatchingRouterContext() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidAppear(id: router.modalContext!.id)

        coordinator.bindingDidDismiss(style: .sheet, router: router)

        #expect(router.modalContext == nil)
        #expect(coordinator.presentedContext == nil)
        coordinator.presentationDidDismiss(style: .sheet)
        #expect(coordinator.presentedContext == nil)
    }

    @Test @MainActor
    func callbackForWrongStyleIsIgnored() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidAppear(id: router.modalContext!.id)
        router.sheet(.modal("B"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)

        coordinator.presentationDidDismiss(style: .fullScreenCover)

        #expect(coordinator.presentedContext == nil)
        #expect(coordinator.pendingContext?.route == .modal("B"))
    }

    @Test @MainActor
    func replacementBeforeAppearanceDoesNotWaitForDismissCallback() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        coordinator.reconcile(desired: router.modalContext)

        router.sheet(.modal("B"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)

        #expect(coordinator.presentedContext?.route == .modal("B"))
        #expect(coordinator.pendingContext == nil)
    }

    @Test @MainActor
    func pendingPresentationCanBeCancelled() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidAppear(id: router.modalContext!.id)
        router.sheet(.modal("B"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)

        #expect(router.dismiss() == .dismissedPresentedModal)
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidDismiss(style: .sheet)

        #expect(coordinator.presentedContext == nil)
        #expect(coordinator.pendingContext == nil)
    }

    #if !os(macOS)
    @Test @MainActor
    func crossStyleReplacementWaitsForSheetDismissal() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidAppear(id: router.modalContext!.id)

        router.fullScreenCover(
            .modal("B"),
            options: [.dismissPresented]
        )
        coordinator.reconcile(desired: router.modalContext)

        #expect(coordinator.context(for: .sheet) == nil)
        #expect(coordinator.context(for: .fullScreenCover) == nil)
        coordinator.presentationDidDismiss(style: .sheet)
        #expect(coordinator.context(for: .fullScreenCover)?.route == .modal("B"))
    }
    #endif
}
```

- [ ] **Step 2: Run the coordinator suite and verify missing-type failure**

Run:

```bash
swift test --scratch-path /private/tmp/irouter-task4 --filter IRouterPresentationCoordinatorTests
```

Expected: compilation fails because the coordinator does not exist.

- [ ] **Step 3: Implement the pure presentation coordinator**

Create `IRouterPresentationCoordinator.swift` with one presented context, one pending context, and one private dismissing identity/style. Use this interface:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class IRouterPresentationCoordinator<Route: Hashable & Sendable> {
    private(set) var presentedContext: IRouterContext<Route>?
    private(set) var pendingContext: IRouterContext<Route>?
    private var visibleID: UUID?
    private var dismissing: (id: UUID, style: IRouterModalStyle)?

    func reconcile(desired: IRouterContext<Route>?) {
        if dismissing != nil {
            pendingContext = desired
            return
        }

        guard presentedContext?.id != desired?.id else { return }
        guard let presentedContext else {
            self.presentedContext = desired
            return
        }

        guard visibleID == presentedContext.id else {
            self.presentedContext = desired
            pendingContext = nil
            return
        }

        dismissing = (presentedContext.id, presentedContext.style)
        pendingContext = desired
        self.presentedContext = nil
        visibleID = nil
    }

    func presentationDidAppear(id: UUID) {
        guard dismissing == nil,
              presentedContext?.id == id else { return }
        visibleID = id
    }

    func context(for style: IRouterModalStyle) -> IRouterContext<Route>? {
        presentedContext?.style == style ? presentedContext : nil
    }

    func bindingDidDismiss(
        style: IRouterModalStyle,
        router: IRouter<Route>
    ) {
        guard dismissing == nil,
              let presentedContext,
              presentedContext.style == style else { return }
        dismissing = (presentedContext.id, style)
        pendingContext = nil
        self.presentedContext = nil
        visibleID = nil
        router.modalDidDismiss(id: presentedContext.id)
    }

    func presentationDidDismiss(style: IRouterModalStyle) {
        guard dismissing?.style == style else { return }
        dismissing = nil
        presentedContext = pendingContext
        pendingContext = nil
        visibleID = nil
    }
}
```

If tuple equality causes a Swift compiler limitation, compare `dismissing == nil` only and compare `dismissing?.style` explicitly; do not introduce unchecked sendability.

- [ ] **Step 4: Run coordinator tests and verify all transitions pass**

Run:

```bash
swift test --scratch-path /private/tmp/irouter-task4 --filter IRouterPresentationCoordinatorTests
```

Expected: all coordinator tests pass.

- [ ] **Step 5: Rebuild `IRouterView` around guarded bindings**

Use a state-owned coordinator initialized in `init`, a guarded `NavigationStack` binding, and style-filtered modal bindings:

```swift
public struct IRouterView<Route: Hashable & Sendable, Content: View>: View {
    @Bindable private var router: IRouter<Route>
    @State private var presentationCoordinator:
        IRouterPresentationCoordinator<Route>
    private let destination: (Route) -> Content

    public init(
        router: IRouter<Route>,
        @ViewBuilder destination: @escaping (Route) -> Content
    ) {
        _router = Bindable(router)
        _presentationCoordinator = State(
            initialValue: IRouterPresentationCoordinator()
        )
        self.destination = destination
    }

    public var body: some View {
        NavigationStack(path: pathBinding) {
            destination(router.root)
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
        .sheet(
            item: modalBinding(for: .sheet),
            onDismiss: {
                presentationCoordinator.presentationDidDismiss(style: .sheet)
            }
        ) { context in
            IRouterView(
                router: context.childRouter,
                destination: destination
            )
            .onAppear {
                presentationCoordinator.presentationDidAppear(id: context.id)
            }
        }
        #if !os(macOS)
        .fullScreenCover(
            item: modalBinding(for: .fullScreenCover),
            onDismiss: {
                presentationCoordinator.presentationDidDismiss(
                    style: .fullScreenCover
                )
            }
        ) { context in
            IRouterView(
                router: context.childRouter,
                destination: destination
            )
            .onAppear {
                presentationCoordinator.presentationDidAppear(id: context.id)
            }
        }
        #endif
        .onAppear {
            presentationCoordinator.reconcile(desired: router.modalContext)
        }
        .onChange(of: router.modalContext?.id) {
            presentationCoordinator.reconcile(desired: router.modalContext)
        }
        .environment(router)
    }

    private var pathBinding: Binding<[Route]> {
        Binding(
            get: { router.path },
            set: { _ = router.synchronizePathFromUI($0) }
        )
    }

    private func modalBinding(
        for style: IRouterModalStyle
    ) -> Binding<IRouterContext<Route>?> {
        Binding(
            get: { presentationCoordinator.context(for: style) },
            set: { context in
                guard context == nil else { return }
                presentationCoordinator.bindingDidDismiss(
                    style: style,
                    router: router
                )
            }
        )
    }
}
```

- [ ] **Step 6: Run package tests and build both package platforms**

Run:

```bash
swift test --scratch-path /private/tmp/irouter-task4
swift build --scratch-path /private/tmp/irouter-task4-build
xcodebuild -scheme IRouter -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -derivedDataPath /private/tmp/irouter-task4-ios CODE_SIGNING_ALLOWED=NO test
```

Expected: all tests pass on macOS and iOS, including cross-style coordinator coverage.

- [ ] **Step 7: Commit the SwiftUI presentation host**

```bash
git add Sources/IRouter/IRouterPresentationCoordinator.swift Sources/IRouter/IRouterView.swift Tests/IRouterTests/IRouterPresentationCoordinatorTests.swift
git commit -m "fix: serialize SwiftUI modal presentation"
```

---

### Task 5: Demo Shared Model, Shell, Stack, and Filter Labs

**Files:**
- Modify: `demo/IRouterDemo/IRouterDemoApp.swift`
- Modify: `demo/IRouterDemo/ContentView.swift`
- Create: `demo/IRouterDemo/DemoModel.swift`
- Create: `demo/IRouterDemo/DemoComponents.swift`
- Rename/replace: `demo/IRouterDemo/BasicDemo.swift` -> `demo/IRouterDemo/StackDemo.swift`
- Modify: `demo/IRouterDemo/FilterDemo.swift`
- Rename/migrate: `demo/IRouterDemo/FlushDemo.swift` -> `demo/IRouterDemo/ModalDemo.swift`
- Rename/migrate: `demo/IRouterDemo/TabDemo.swift` -> `demo/IRouterDemo/NestedDemo.swift`
- Create: `demo/IRouterDemo/MultipleRoutersDemo.swift`
- Modify: `demo/IRouterDemo.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: completed public router API.
- Produces: `DemoSection`, `AppRoute`, `DemoAuthState`, stable accessibility IDs, outcome summaries, router inspector, and two complete labs.

- [ ] **Step 1: Create the shared Demo model**

Define exactly five sections and routes that cover all labs:

```swift
enum DemoSection: String, CaseIterable, Identifiable {
    case stack
    case filters
    case modals
    case nested
    case multipleRouters

    var id: Self { self }
}

enum AppRoute: Hashable, Sendable {
    case home
    case detail(Int)
    case settings
    case login
    case blocked
    case selfCycle
    case cycleA
    case cycleB
    case modal(String)
    case nested(level: Int)
    case feed
}

@MainActor
@Observable
final class DemoAuthState {
    var isLoggedIn = false
}
```

Add centralized display strings for `DemoSection`, `AppRoute`, `IRouterNavigationOutcome<AppRoute>`, `IRouterDismissOutcome`, and `[AppRoute]`. Add a `DemoAccessibility` namespace with stable identifiers for every UI-test control and state value, including:

```swift
enum DemoAccessibility {
    static let modalsTab = "demo.tab.modals"
    static let openSheetA = "demo.modals.openSheetA"
    static let replaceWithCoverB = "demo.modals.replaceWithCoverB"
    static let rapidReplaceABC = "demo.modals.rapidReplaceABC"
    static let modalA = "demo.modal.A"
    static let modalB = "demo.modal.B"
    static let modalC = "demo.modal.C"
    static let dismissCurrent = "demo.modal.dismissCurrent"
    static let modalState = "demo.state.modal"
}
```

- [ ] **Step 2: Build reusable state and command components**

Create `DemoComponents.swift` with:

- `RouterInspector`: stable rows for path, modal route/style, child depth, and latest outcome.
- `DemoCommandButton`: native `Label` with SF Symbol, fixed vertical padding, accessibility identifier, role, and disabled state.
- `DemoSectionContainer`: a `List` wrapper with compact section spacing and navigation title.

Do not place cards inside cards. The inspector is an unframed `Grid`/`LabeledContent` section and must not set hardcoded text heights.

- [ ] **Step 3: Replace the root menu with the actual adaptive test surface**

Implement `ContentView` with:

```swift
struct ContentView: View {
    #if os(macOS)
    @State private var selection: DemoSection? = .stack
    #endif

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(DemoSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("IRouter")
        } detail: {
            demoView(selection ?? .stack)
        }
        #else
        TabView {
            tab(.stack, StackDemoView())
            tab(.filters, FilterDemoView())
            tab(.modals, ModalDemoView())
            tab(.nested, NestedDemoView())
            tab(.multipleRouters, MultipleRoutersDemoView())
        }
        #endif
    }
}
```

Implement the helpers with exhaustive section switches:

```swift
@ViewBuilder
private func demoView(_ section: DemoSection) -> some View {
    switch section {
    case .stack: StackDemoView()
    case .filters: FilterDemoView()
    case .modals: ModalDemoView()
    case .nested: NestedDemoView()
    case .multipleRouters: MultipleRoutersDemoView()
    }
}

private func tab<Content: View>(
    _ section: DemoSection,
    _ content: Content
) -> some View {
    content
        .tabItem {
            Label(section.title, systemImage: section.systemImage)
                .accessibilityIdentifier(section.accessibilityIdentifier)
        }
}
```

`DemoSection` supplies an exhaustive `title`, `systemImage`, and accessibility identifier switch for all five cases.

- [ ] **Step 4: Rebuild the Stack lab using only public router commands**

`StackDemoView` owns one router and one latest-outcome string. Its destination builder supports `.home`, `.detail`, and `.settings`. Commands cover append, deduplicate, pop, and pop-to-root. Every command stores the returned outcome or Boolean-derived result in the inspector. No code writes `router.path`.

- [ ] **Step 5: Rebuild the Filter lab with real actor state and safe cycle examples**

Initialize one `DemoAuthState` and one router in `FilterDemoView.init`. Its filters must:

```swift
IRouterFilter { route, presentation in
    switch route {
    case .settings where !auth.isLoggedIn:
        .redirect(.login, .sheet)
    case .blocked:
        .block
    case .selfCycle:
        .redirect(.selfCycle, presentation)
    case .cycleA:
        .redirect(.cycleB, presentation)
    case .cycleB:
        .redirect(.cycleA, presentation)
    default:
        .allow
    }
}
```

Expose a login toggle, allow/block commands, settings redirect, self-cycle, and two-node cycle. Display the exact outcome and redirect chain rather than maintaining an unsafe asynchronous log.

- [ ] **Step 6: Migrate the remaining three labs to compiling final-type files**

Rename the old modal and tab files before updating the root shell. The Task 5 baseline implementations are complete, usable labs:

- `ModalDemoView` owns one `IRouterView`, presents sheet/cover through router commands, displays the current modal/outcome, and lets the child call `dismiss()`; advanced replacement controls are added in Task 6.
- `NestedDemoView` presents one child router, lets that child push/pop/dismiss, and uses no outer presentation modifier; deeper nesting is added in Task 6.
- `MultipleRoutersDemoView` owns two routers, shows both inspectors, and provides push/pop commands for each; modal isolation controls are added in Task 6.

All three files use `IRouterNavigationOptions` and read-only `modalContext`. No old `flush`, `dedup`, context setter, or direct path setter remains.

- [ ] **Step 7: Update the Xcode project source list and enable macOS on the app target**

Replace old file references/build files with the nine-file final source list from the File Map. Add `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"`, `MACOSX_DEPLOYMENT_TARGET = 14.0`, and `SUPPORTS_MACCATALYST = NO` to both app target configurations. Change project-level `SDKROOT = iphoneos` to `SDKROOT = auto` in Debug and Release. Keep `IPHONEOS_DEPLOYMENT_TARGET = 17.0` and Swift 6.0.

- [ ] **Step 8: Build the migrated Demo on iOS and macOS**

Run:

```bash
xcodebuild -project demo/IRouterDemo.xcodeproj -scheme IRouterDemo -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/irouter-demo-task5-ios CODE_SIGNING_ALLOWED=NO build
xcodebuild -project demo/IRouterDemo.xcodeproj -scheme IRouterDemo -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/irouter-demo-task5-mac CODE_SIGNING_ALLOWED=NO build
```

Expected: both builds succeed and all five labs are usable. Task 6 adds advanced regression scenarios without changing their public type names.

- [ ] **Step 9: Commit the adaptive Demo foundation**

```bash
git add demo/IRouterDemo demo/IRouterDemo.xcodeproj/project.pbxproj
git commit -m "refactor: rebuild demo navigation labs"
```

---

### Task 6: Demo Modal, Nested, and Multiple-Router Labs

**Files:**
- Modify: `demo/IRouterDemo/ModalDemo.swift`
- Modify: `demo/IRouterDemo/NestedDemo.swift`
- Modify: `demo/IRouterDemo/MultipleRoutersDemo.swift`
- Modify: `demo/IRouterDemo/DemoModel.swift`
- Modify: `demo/IRouterDemo.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Demo shared model/components and public router API.
- Produces: complete presentation replacement, hierarchy dismissal, and router-isolation demonstrations.

- [ ] **Step 1: Implement the Modal lab without manual presentation modifiers**

`ModalDemoView` must contain exactly one root `IRouterView`. Its root commands cover:

- `sheet(.modal("A"))`.
- A second modal without options, expecting `modalAlreadyPresented`.
- `sheet(.modal("B"), options: [.dismissPresented])`.
- On iOS, `fullScreenCover(.modal("B"), options: [.dismissPresented])`.
- Rapid replacement from active A by immediately committing B and C; C is the latest desired state.
- `push(.detail(1), options: [.dismissPresented])`.

The modal destination receives both the current child router from `@Environment` and the owning root router explicitly. It provides child push/dismiss commands and root replacement commands. Apply the accessibility identifiers from `DemoAccessibility` to visible modal roots and commands.

No `.sheet`, `.fullScreenCover`, manual Binding, or `DispatchQueue.main.asyncAfter` may appear in Demo source outside library-owned `IRouterView`.

- [ ] **Step 2: Implement the Nested lab with three real router levels**

`NestedDemoView` presents `.nested(level: 1)`. Each nested destination:

- Reads its current child router from the environment.
- Pushes a detail route, then shows that the first `dismiss()` returns `.popped`.
- Presents `.nested(level: level + 1)` until level 3.
- Calls `dismiss()` at an empty root to close exactly its owning parent modal.
- Displays its own path/modal/outcome inspector, not the root router's inspector.

- [ ] **Step 3: Implement the Multiple Routers lab**

Create two state-owned routers with roots `.home` and `.feed`. Use a segmented picker to select which router's commands are active while both inspectors remain visible. Verify in the UI that push, modal, pop, and dismiss commands mutate only the selected router.

- [ ] **Step 4: Scan Demo source for forbidden workarounds**

Run:

```bash
rg -n "nonisolated\(unsafe\)|@unchecked|DispatchQueue\.main\.asyncAfter|\.sheet\(|\.fullScreenCover\(|sheetContext|coverContext|router\.path\s*=" demo/IRouterDemo
```

Expected: no matches. Calls to the router method named `fullScreenCover` are allowed; if the pattern finds them, inspect and confirm there are no SwiftUI modifiers.

- [ ] **Step 5: Build all Demo platform/configuration combinations**

Run Debug and Release builds for generic iOS Simulator and macOS using separate `/private/tmp` DerivedData paths.

Expected: all four builds succeed without concurrency warnings or unavailable-API errors.

- [ ] **Step 6: Commit the complete Demo scenarios**

```bash
git add -A demo/IRouterDemo demo/IRouterDemo.xcodeproj/project.pbxproj
git commit -m "feat: complete router regression demo"
```

---

### Task 7: Focused iOS UI Presentation Tests

**Files:**
- Create: `demo/IRouterDemoUITests/IRouterDemoUITests.swift`
- Modify: `demo/IRouterDemo.xcodeproj/project.pbxproj`
- Create: `demo/IRouterDemo.xcodeproj/xcshareddata/xcschemes/IRouterDemo.xcscheme`

**Interfaces:**
- Consumes: stable Demo accessibility identifiers and completed modal/nested flows.
- Produces: `IRouterDemoUITests` target included in the shared scheme's Test action.

- [ ] **Step 1: Add the UI test source with predicate-based waits**

Create an XCTestCase that launches with `-ui-testing`, resets state in `setUpWithError`, and implements these tests:

```swift
import XCTest

final class IRouterDemoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.tabBars.buttons["demo.tab.modals"].tap()
    }

    func testChildRouterDismissesOwningSheet() {
        app.buttons["demo.modals.openSheetA"].tap()
        let modalA = app.otherElements["demo.modal.A"]
        XCTAssertTrue(modalA.waitForExistence(timeout: 2))

        app.buttons["demo.modal.dismissCurrent"].tap()

        XCTAssertTrue(waitForDisappearance(modalA))
        XCTAssertEqual(app.staticTexts["demo.state.modal"].label, "None")
    }

    func testSheetToCoverReplacementIsSerialized() {
        app.buttons["demo.modals.openSheetA"].tap()
        let modalA = app.otherElements["demo.modal.A"]
        XCTAssertTrue(modalA.waitForExistence(timeout: 2))

        app.buttons["demo.modals.replaceWithCoverB"].tap()

        XCTAssertTrue(waitForDisappearance(modalA))
        XCTAssertTrue(app.otherElements["demo.modal.B"].waitForExistence(timeout: 2))
    }

    func testRapidReplacementPresentsOnlyLatestContext() {
        app.buttons["demo.modals.openSheetA"].tap()
        XCTAssertTrue(app.otherElements["demo.modal.A"].waitForExistence(timeout: 2))

        app.buttons["demo.modals.rapidReplaceABC"].tap()

        XCTAssertFalse(app.otherElements["demo.modal.B"].waitForExistence(timeout: 0.5))
        XCTAssertTrue(app.otherElements["demo.modal.C"].waitForExistence(timeout: 2))
    }

    func testInteractiveDismissalClearsRouterInspector() {
        app.buttons["demo.modals.openSheetA"].tap()
        let modalA = app.otherElements["demo.modal.A"]
        XCTAssertTrue(modalA.waitForExistence(timeout: 2))

        modalA.swipeDown(velocity: .fast)

        XCTAssertTrue(waitForDisappearance(modalA))
        XCTAssertEqual(app.staticTexts["demo.state.modal"].label, "None")
    }

    private func waitForDisappearance(
        _ element: XCUIElement,
        timeout: TimeInterval = 2
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
```

- [ ] **Step 2: Add the UI test target to the Xcode project**

Add a `com.apple.product-type.bundle.ui-testing` native target with:

- Product name `IRouterDemoUITests.xctest`.
- Bundle identifier `com.ibabyblue.IRouterDemoUITests`.
- Swift 6.0.
- iOS deployment target 17.0.
- `TEST_TARGET_NAME = IRouterDemo`.
- A target dependency on `IRouterDemo`.
- Sources phase containing only `IRouterDemoUITests.swift`.
- No macOS supported platform for this test target.

Use deterministic PBX identifiers so the shared scheme can reference the target without Xcode-generated churn:

```text
CCCC000000000000000000E2  IRouterDemoUITests target
CCCC000000000000000000B8  IRouterDemoUITests.xctest product
CCCC000000000000000000B9  IRouterDemoUITests.swift file reference
CCCC000000000000000000A8  IRouterDemoUITests.swift build file
CCCC000000000000000000C4  UI test sources phase
CCCC000000000000000000C5  UI test frameworks phase
CCCC000000000000000000C6  UI test resources phase
CCCC000000000000000000D4  Target dependency
CCCC000000000000000000D5  Container item proxy
CCCC000000000000000000F10 UI test Debug configuration
CCCC000000000000000000F11 UI test Release configuration
CCCC000000000000000000F12 UI test configuration list
```

Create a shared `IRouterDemo` scheme whose Test action builds and runs `IRouterDemoUITests` and whose Run action launches `IRouterDemo`.

Write `demo/IRouterDemo.xcodeproj/xcshareddata/xcschemes/IRouterDemo.xcscheme` with these buildable references:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1630" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES"
            buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary"
               BlueprintIdentifier="BBBB000000000000000000E1"
               BuildableName="IRouterDemo.app" BlueprintName="IRouterDemo"
               ReferencedContainer="container:IRouterDemo.xcodeproj"/>
         </BuildActionEntry>
         <BuildActionEntry buildForTesting="YES" buildForRunning="NO"
            buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">
            <BuildableReference BuildableIdentifier="primary"
               BlueprintIdentifier="CCCC000000000000000000E2"
               BuildableName="IRouterDemoUITests.xctest"
               BlueprintName="IRouterDemoUITests"
               ReferencedContainer="container:IRouterDemo.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug"
      selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv="YES">
      <Testables>
         <TestableReference skipped="NO" parallelizable="NO">
            <BuildableReference BuildableIdentifier="primary"
               BlueprintIdentifier="CCCC000000000000000000E2"
               BuildableName="IRouterDemoUITests.xctest"
               BlueprintName="IRouterDemoUITests"
               ReferencedContainer="container:IRouterDemo.xcodeproj"/>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug"
      selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle="0" useCustomWorkingDirectory="NO"
      ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"
      debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary"
            BlueprintIdentifier="BBBB000000000000000000E1"
            BuildableName="IRouterDemo.app" BlueprintName="IRouterDemo"
            ReferencedContainer="container:IRouterDemo.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES"
      savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary"
            BlueprintIdentifier="BBBB000000000000000000E1"
            BuildableName="IRouterDemo.app" BlueprintName="IRouterDemo"
            ReferencedContainer="container:IRouterDemo.xcodeproj"/>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug"/>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
```

- [ ] **Step 3: List the project and verify target/scheme discovery**

Run:

```bash
xcodebuild -project demo/IRouterDemo.xcodeproj -list
```

Expected: targets include `IRouterDemo` and `IRouterDemoUITests`; shared schemes include `IRouterDemo`.

- [ ] **Step 4: Run UI tests on an installed iOS 17+ simulator**

Select an available simulator from `xcodebuild -showdestinations`, then run:

```bash
xcodebuild -project demo/IRouterDemo.xcodeproj -scheme IRouterDemo -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -derivedDataPath /private/tmp/irouter-demo-ui-tests CODE_SIGNING_ALLOWED=NO test
```

Expected: all four UI tests pass without fixed sleeps or presentation warnings.

- [ ] **Step 5: Commit UI integration coverage**

```bash
git add demo/IRouterDemoUITests demo/IRouterDemo.xcodeproj/project.pbxproj demo/IRouterDemo.xcodeproj/xcshareddata/xcschemes/IRouterDemo.xcscheme
git commit -m "test: cover live modal presentation flows"
```

---

### Task 8: README, Changelog, and Migration Contract

**Files:**
- Modify: `README.md`
- Create: `CHANGELOG.md`

**Interfaces:**
- Consumes: final compiled public API and verified Demo behavior.
- Produces: installation requirements, API reference, behavior tables, and 0.0.4 migration guide that exactly match source.

- [ ] **Step 1: Rewrite requirements and quick start against the compiled API**

Set requirements to iOS 17, macOS 14, Swift 6.0, and Xcode 16.x. Quick start must use:

```swift
router.push(.detail(id: "42"), options: [.deduplicateTop])
router.push(.settings, options: [.dismissPresented])
```

The auth filter example must use an `@MainActor` auth model and compile under Swift 6.

- [ ] **Step 2: Replace the API reference and behavior tables**

Document:

- Read-only `path` and `modalContext`.
- Single direct modal per router.
- `navigate`, `push`, `sheet`, iOS `fullScreenCover`.
- Options and final-target semantics after redirects.
- Outcomes and all failure cases.
- Iterative redirect limit of 32.
- Exact four-step dismissal order.
- Child-router filter inheritance and parent dismissal.
- SwiftUI presentation serialization.
- macOS rejection of dynamic full-screen-cover requests.
- Unsupported `NavigationLink(value:)` forward navigation and supported system pop behavior.

- [ ] **Step 3: Add the breaking migration table and changelog**

Include this exact mapping:

| 0.0.4 | New API |
|---|---|
| `dedup: true` | `options: [.deduplicateTop]` |
| `flush: true` | `options: [.dismissPresented]` |
| `dismissAndPush(route)` | `push(route, options: [.dismissPresented])` |
| `sheetContext` / `coverContext` | Read-only `modalContext` plus `style` |
| Direct `path` mutation | Router navigation/pop APIs |

Create `CHANGELOG.md` with an `Unreleased` breaking section covering the state model, API, filter actor contract, redirect protection, presentation serialization, Demo, and test matrix. Do not claim a release tag.

- [ ] **Step 4: Scan docs and Demo for removed API**

Run:

```bash
rg -n "sheetContext|coverContext|dismissAndPush|dedup:|flush:" README.md CHANGELOG.md demo Sources Tests
```

Expected: matches appear only inside the migration documentation; no source, test, or Demo code uses removed APIs.

- [ ] **Step 5: Commit documentation**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: document transactional router API"
```

---

### Task 9: Full Verification and Release Readiness Audit

**Files:**
- Modify only files required to fix failures found by this task.

**Interfaces:**
- Consumes: all prior tasks.
- Produces: fresh evidence for every acceptance criterion; does not tag or publish.

- [ ] **Step 1: Verify repository scope and formatting**

Run:

```bash
git status --short --branch
git diff --check
rg -n "TODO|FIXME|nonisolated\(unsafe\)|@unchecked|DispatchQueue\.main\.asyncAfter" Sources Tests demo README.md CHANGELOG.md
```

Expected: no unintended files, no whitespace errors, and no forbidden placeholders/unsafe timing workarounds.

- [ ] **Step 2: Run clean macOS package tests**

Run:

```bash
swift test --scratch-path /private/tmp/irouter-final-macos
```

Expected: every Swift Testing test passes with zero failures.

- [ ] **Step 3: Run iOS package tests**

Choose an installed simulator destination and run the package scheme with a fresh DerivedData path:

```bash
xcodebuild -scheme IRouter -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -derivedDataPath /private/tmp/irouter-final-ios-tests CODE_SIGNING_ALLOWED=NO test
```

Expected: package tests pass on iOS, including full-screen-cover coordinator coverage.

- [ ] **Step 4: Run all Demo UI tests**

Run:

```bash
xcodebuild -project demo/IRouterDemo.xcodeproj -scheme IRouterDemo -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -derivedDataPath /private/tmp/irouter-final-ui-tests CODE_SIGNING_ALLOWED=NO test
```

Expected: all UI tests pass and no presentation warning appears in the test log.

- [ ] **Step 5: Build Demo Debug and Release for iOS and macOS**

Run four builds with independent DerivedData paths:

```bash
xcodebuild -project demo/IRouterDemo.xcodeproj -scheme IRouterDemo -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/irouter-final-demo-ios-debug CODE_SIGNING_ALLOWED=NO build
xcodebuild -project demo/IRouterDemo.xcodeproj -scheme IRouterDemo -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/irouter-final-demo-ios-release CODE_SIGNING_ALLOWED=NO build
xcodebuild -project demo/IRouterDemo.xcodeproj -scheme IRouterDemo -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/irouter-final-demo-mac-debug CODE_SIGNING_ALLOWED=NO build
xcodebuild -project demo/IRouterDemo.xcodeproj -scheme IRouterDemo -configuration Release -destination 'platform=macOS' -derivedDataPath /private/tmp/irouter-final-demo-mac-release CODE_SIGNING_ALLOWED=NO build
```

Expected: all four builds succeed.

- [ ] **Step 6: Audit the final public API and staged scope**

Run:

```bash
swift package dump-package
git diff --stat ee80546..HEAD
git log --oneline ee80546..HEAD
git status --short --branch
```

Confirm:

- Manifest tools version is 6.0.
- Only planned source, tests, Demo project, README, and changelog changed after the design commit.
- No old public state setters or old overloads remain.
- No tag or push occurred.

- [ ] **Step 7: Create a final verification commit only if Task 9 required fixes**

If verification required code or documentation corrections:

```bash
git add Package.swift Sources/IRouter Tests/IRouterTests demo/IRouterDemo demo/IRouterDemoUITests demo/IRouterDemo.xcodeproj README.md CHANGELOG.md
git commit -m "fix: close router verification gaps"
```

If no corrections were required, do not create an empty commit.
