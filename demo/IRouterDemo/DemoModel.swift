import IRouter
import Observation

enum DemoSection: String, CaseIterable, Identifiable {
    case stack
    case filters
    case modals
    case nested
    case multipleRouters

    var id: Self { self }

    var title: String {
        switch self {
        case .stack: "Stack"
        case .filters: "Filters"
        case .modals: "Modals"
        case .nested: "Nested"
        case .multipleRouters: "Routers"
        }
    }

    var systemImage: String {
        switch self {
        case .stack: "square.stack.3d.up"
        case .filters: "line.3.horizontal.decrease.circle"
        case .modals: "rectangle.on.rectangle"
        case .nested: "square.stack.3d.forward.dottedline"
        case .multipleRouters: "arrow.triangle.branch"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .stack: DemoAccessibility.stackTab
        case .filters: DemoAccessibility.filtersTab
        case .modals: DemoAccessibility.modalsTab
        case .nested: DemoAccessibility.nestedTab
        case .multipleRouters: DemoAccessibility.multipleRoutersTab
        }
    }
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

extension AppRoute {
    var title: String {
        switch self {
        case .home: "Home"
        case .detail(let value): "Detail \(value)"
        case .settings: "Settings"
        case .login: "Login"
        case .blocked: "Blocked"
        case .selfCycle: "Self Cycle"
        case .cycleA: "Cycle A"
        case .cycleB: "Cycle B"
        case .modal(let name): "Modal \(name)"
        case .nested(let level): "Nested Level \(level)"
        case .feed: "Feed"
        }
    }

    var compactTitle: String {
        switch self {
        case .home: "home"
        case .detail(let value): "detail(\(value))"
        case .settings: "settings"
        case .login: "login"
        case .blocked: "blocked"
        case .selfCycle: "selfCycle"
        case .cycleA: "cycleA"
        case .cycleB: "cycleB"
        case .modal(let name): "modal(\(name))"
        case .nested(let level): "nested(\(level))"
        case .feed: "feed"
        }
    }
}

@MainActor
@Observable
final class DemoAuthState {
    var isLoggedIn = false
}

@MainActor
@Observable
final class DemoOutcomeStore {
    private var outcomes: [String: String] = [:]

    func value(for key: String) -> String {
        outcomes[key, default: "No command yet"]
    }

    func record(_ outcome: String, for key: String) {
        outcomes[key] = outcome
    }
}

extension Array where Element == AppRoute {
    var displayText: String {
        isEmpty ? "[]" : "[\(map(\.compactTitle).joined(separator: ", "))]"
    }
}

extension IRouterNavigationOutcome where Route == AppRoute {
    var displayText: String {
        switch self {
        case .committed(let destination):
            "Committed: \(destination.displayText)"
        case .blocked(let destination):
            "Blocked: \(destination.displayText)"
        case .deduplicated(let destination):
            "Deduplicated: \(destination.displayText)"
        case .rejected(let failure):
            "Rejected: \(failure.displayText)"
        }
    }
}

extension IRouterDismissOutcome {
    var displayText: String {
        switch self {
        case .dismissedPresentedModal: "Dismissed presented modal"
        case .popped: "Popped top route"
        case .dismissedFromParent: "Dismissed from parent"
        case .unchanged: "Unchanged"
        }
    }
}

private extension IRouterDestination where Route == AppRoute {
    var displayText: String {
        "\(route.compactTitle) as \(presentation.displayText)"
    }
}

private extension IRouterNavigationFailure where Route == AppRoute {
    var displayText: String {
        switch self {
        case .redirectCycle(let chain):
            "redirect cycle [\(chain.map(\.displayText).joined(separator: " -> "))]"
        case .redirectLimitExceeded(let chain, let limit):
            "redirect limit \(limit) exceeded [\(chain.map(\.displayText).joined(separator: " -> "))]"
        case .modalAlreadyPresented(let current):
            "modal already presented (\(current.displayText))"
        case .unsupportedPresentation(let presentation):
            "unsupported presentation \(presentation.displayText)"
        }
    }
}

extension IRouterPresentation {
    var displayText: String {
        switch self {
        case .push: "push"
        case .sheet: "sheet"
        case .fullScreenCover: "fullScreenCover"
        }
    }
}

extension IRouterModalStyle {
    var displayText: String {
        switch self {
        case .sheet: "sheet"
        case .fullScreenCover: "fullScreenCover"
        }
    }
}

enum DemoAccessibility {
    static let stackTab = "demo.tab.stack"
    static let filtersTab = "demo.tab.filters"
    static let modalsTab = "demo.tab.modals"
    static let nestedTab = "demo.tab.nested"
    static let multipleRoutersTab = "demo.tab.multipleRouters"

    static let stackPushDetail = "demo.stack.pushDetail"
    static let stackPushSettings = "demo.stack.pushSettings"
    static let stackDeduplicate = "demo.stack.deduplicate"
    static let stackPop = "demo.stack.pop"
    static let stackPopToRoot = "demo.stack.popToRoot"

    static let authToggle = "demo.filters.authToggle"
    static let filterAllow = "demo.filters.allow"
    static let filterBlock = "demo.filters.block"
    static let filterSettings = "demo.filters.settings"
    static let filterSelfCycle = "demo.filters.selfCycle"
    static let filterTwoNodeCycle = "demo.filters.twoNodeCycle"
    static let filterDismiss = "demo.filters.dismiss"

    static let openSheetA = "demo.modals.openSheetA"
    static let openCoverB = "demo.modals.openCoverB"
    static let rejectSecondModal = "demo.modals.rejectSecondModal"
    static let replaceWithSheetB = "demo.modals.replaceWithSheetB"
    static let replaceWithCoverB = "demo.modals.replaceWithCoverB"
    static let rapidReplaceABC = "demo.modals.rapidReplaceABC"
    static let replaceWithPush = "demo.modals.replaceWithPush"
    static let modalChildPush = "demo.modal.childPush"
    static let modalA = "demo.modal.A"
    static let modalB = "demo.modal.B"
    static let modalC = "demo.modal.C"
    static let modalRoot = "demo.modals.root"
    static let dismissCurrent = "demo.modal.dismissCurrent"
    static let modalState = "demo.state.modal"
    static let modalInspectorPrefix = "demo.modals"

    static let nestedOpenChild = "demo.nested.openChild"
    static let nestedPush = "demo.nested.push"
    static let nestedPop = "demo.nested.pop"
    static let nestedDismiss = "demo.nested.dismiss"
    static let nestedRoot = "demo.nested.root"

    static func nestedLevelRoot(_ level: Int) -> String {
        "demo.nested.level\(level)"
    }

    static func nestedInspectorPrefix(_ level: Int) -> String {
        "demo.nested.level\(level)"
    }

    static func nestedOpenNext(_ level: Int) -> String {
        "demo.nested.level\(level).openNext"
    }

    static func nestedPush(_ level: Int) -> String {
        "demo.nested.level\(level).push"
    }

    static func nestedDismiss(_ level: Int) -> String {
        "demo.nested.level\(level).dismiss"
    }

    static let routerAPush = "demo.multiple.routerA.push"
    static let routerAPop = "demo.multiple.routerA.pop"
    static let routerBPush = "demo.multiple.routerB.push"
    static let routerBPop = "demo.multiple.routerB.pop"
    static let multipleRoot = "demo.multiple.root"
    static let multipleTargetPicker = "demo.multiple.targetPicker"
    static let multipleRouterAOption = "demo.multiple.target.routerA"
    static let multipleRouterBOption = "demo.multiple.target.routerB"
    static let multipleSelectedState = "demo.multiple.state.selected"
    static let multiplePush = "demo.multiple.push"
    static let multiplePresent = "demo.multiple.present"
    static let multiplePop = "demo.multiple.pop"
    static let multipleDismiss = "demo.multiple.dismiss"
    static let multipleRouterAPrefix = "demo.multiple.routerA"
    static let multipleRouterBPrefix = "demo.multiple.routerB"

    static func statePath(_ prefix: String) -> String { "\(prefix).state.path" }
    static func stateModalRoute(_ prefix: String) -> String { "\(prefix).state.modalRoute" }
    static func stateModalStyle(_ prefix: String) -> String { "\(prefix).state.modalStyle" }
    static func stateChildDepth(_ prefix: String) -> String { "\(prefix).state.childDepth" }
    static func stateOutcome(_ prefix: String) -> String { "\(prefix).state.outcome" }
    static func stateCurrentRoute(_ prefix: String) -> String { "\(prefix).state.currentRoute" }
}
