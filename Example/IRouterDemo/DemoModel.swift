import IRouter
import Observation

/// The five runnable integration labs exposed by the Example catalog.
enum DemoSection: String, CaseIterable, Identifiable {
    /// Typed stack navigation and contraction.
    case stack
    /// Filter allow, block, redirect, and cycle behavior.
    case filters
    /// Direct-modal presentation and replacement behavior.
    case modals
    /// Nested modal child-router behavior.
    case nested
    /// Independent router switching and state retention.
    case multipleRouters

    /// Uses the section value as stable catalog identity.
    var id: Self { self }

    /// The visible catalog title for this lab.
    var title: String {
        switch self {
        case .stack: "Stack"
        case .filters: "Filters"
        case .modals: "Modals"
        case .nested: "Nested"
        case .multipleRouters: "Routers"
        }
    }

    /// The system symbol associated with this lab.
    var systemImage: String {
        switch self {
        case .stack: "square.stack.3d.up"
        case .filters: "line.3.horizontal.decrease.circle"
        case .modals: "rectangle.on.rectangle"
        case .nested: "square.stack.3d.forward.dottedline"
        case .multipleRouters: "arrow.triangle.branch"
        }
    }

    /// The stable UI-test identifier associated with this lab.
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

/// The shared typed route set exercised by every Example lab.
enum AppRoute: Hashable, Sendable {
    /// A generic home root destination.
    case home
    /// A numbered stack detail destination.
    case detail(Int)
    /// A settings destination used by stack and filter scenarios.
    case settings
    /// The authentication destination used by redirects.
    case login
    /// A destination intentionally blocked by a filter.
    case blocked
    /// A destination that redirects to itself for cycle detection.
    case selfCycle
    /// The first destination in a two-node redirect cycle.
    case cycleA
    /// The second destination in a two-node redirect cycle.
    case cycleB
    /// A named modal destination.
    case modal(String)
    /// A numbered nested-modal root destination.
    case nested(level: Int)
    /// The root destination for the second independent router.
    case feed
}

/// Supplies human-readable route formatting for Example presentation.
extension AppRoute {
    /// The title rendered by destination headers.
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

    /// A compact representation used by router-state inspectors.
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

/// Observable authentication state read by the filter lab.
@MainActor
@Observable
final class DemoAuthState {
    /// A value indicating whether protected settings navigation is allowed.
    var isLoggedIn = false
}

/// Stores independent outcome text for nested router levels.
@MainActor
@Observable
final class DemoOutcomeStore {
    /// Outcome text indexed by stable level key.
    private var outcomes: [String: String] = [:]

    /// Returns the recorded outcome or the initial placeholder text.
    ///
    /// - Parameter key: The stable router-level key.
    /// - Returns: The latest outcome text for that level.
    func value(for key: String) -> String {
        outcomes[key, default: "No command yet"]
    }

    /// Records outcome text for one router level.
    ///
    /// - Parameters:
    ///   - outcome: The formatted result to store.
    ///   - key: The stable router-level key.
    func record(_ outcome: String, for key: String) {
        outcomes[key] = outcome
    }
}

/// Formats Example route arrays for state inspection.
extension Array where Element == AppRoute {
    /// A compact ordered representation of the path.
    var displayText: String {
        isEmpty ? "[]" : "[\(map(\.compactTitle).joined(separator: ", "))]"
    }
}

/// Formats Example navigation outcomes for visible inspection.
extension IRouterNavigationOutcome where Route == AppRoute {
    /// A concise description of this transaction result.
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

/// Formats hierarchical dismissal results for visible inspection.
extension IRouterDismissOutcome {
    /// A concise description of the action performed by dismissal.
    var displayText: String {
        switch self {
        case .dismissedPresentedModal: "Dismissed presented modal"
        case .popped: "Popped top route"
        case .dismissedFromParent: "Dismissed from parent"
        case .unchanged: "Unchanged"
        }
    }
}

/// Formats typed destinations for Example outcome text.
private extension IRouterDestination where Route == AppRoute {
    /// The compact route and presentation pair.
    var displayText: String {
        "\(route.compactTitle) as \(presentation.displayText)"
    }
}

/// Formats transaction failures for Example outcome text.
private extension IRouterNavigationFailure where Route == AppRoute {
    /// A concise description including relevant chain or destination data.
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

/// Formats public navigation presentations for Example output.
extension IRouterPresentation {
    /// The source-level presentation name.
    var displayText: String {
        switch self {
        case .push: "push"
        case .sheet: "sheet"
        case .fullScreenCover: "fullScreenCover"
        }
    }
}

/// Formats committed modal styles for Example output.
extension IRouterModalStyle {
    /// The source-level modal style name.
    var displayText: String {
        switch self {
        case .sheet: "sheet"
        case .fullScreenCover: "fullScreenCover"
        }
    }
}

/// Centralizes stable accessibility identifiers used by Example UI tests.
enum DemoAccessibility {
    /// Identifies the stack lab tab.
    static let stackTab = "demo.tab.stack"
    /// Identifies the filters lab tab.
    static let filtersTab = "demo.tab.filters"
    /// Identifies the modals lab tab.
    static let modalsTab = "demo.tab.modals"
    /// Identifies the nested lab tab.
    static let nestedTab = "demo.tab.nested"
    /// Identifies the multiple-routers lab tab.
    static let multipleRoutersTab = "demo.tab.multipleRouters"

    /// Identifies the stack command that appends a detail.
    static let stackPushDetail = "demo.stack.pushDetail"
    /// Identifies the stack command that appends settings.
    static let stackPushSettings = "demo.stack.pushSettings"
    /// Identifies the stack deduplication command.
    static let stackDeduplicate = "demo.stack.deduplicate"
    /// Identifies the single-pop command.
    static let stackPop = "demo.stack.pop"
    /// Identifies the pop-to-root command.
    static let stackPopToRoot = "demo.stack.popToRoot"

    /// Identifies the authentication toggle.
    static let authToggle = "demo.filters.authToggle"
    /// Identifies the filter allow command.
    static let filterAllow = "demo.filters.allow"
    /// Identifies the filter block command.
    static let filterBlock = "demo.filters.block"
    /// Identifies the protected settings command.
    static let filterSettings = "demo.filters.settings"
    /// Identifies the self-cycle rejection command.
    static let filterSelfCycle = "demo.filters.selfCycle"
    /// Identifies the two-node cycle rejection command.
    static let filterTwoNodeCycle = "demo.filters.twoNodeCycle"
    /// Identifies the filter-lab dismissal command.
    static let filterDismiss = "demo.filters.dismiss"

    /// Identifies the command that opens sheet A.
    static let openSheetA = "demo.modals.openSheetA"
    /// Identifies the command that opens or attempts cover B.
    static let openCoverB = "demo.modals.openCoverB"
    /// Identifies the command that rejects an unrequested second modal.
    static let rejectSecondModal = "demo.modals.rejectSecondModal"
    /// Identifies replacement with sheet B.
    static let replaceWithSheetB = "demo.modals.replaceWithSheetB"
    /// Identifies replacement with cover B.
    static let replaceWithCoverB = "demo.modals.replaceWithCoverB"
    /// Identifies rapid replacement with B and then C.
    static let rapidReplaceABC = "demo.modals.rapidReplaceABC"
    /// Identifies replacement of a modal with a pushed route.
    static let replaceWithPush = "demo.modals.replaceWithPush"
    /// Identifies a push inside a modal child router.
    static let modalChildPush = "demo.modal.childPush"
    /// Identifies modal A content.
    static let modalA = "demo.modal.A"
    /// Identifies modal B content.
    static let modalB = "demo.modal.B"
    /// Identifies modal C content.
    static let modalC = "demo.modal.C"
    /// Identifies the modal lab root content.
    static let modalRoot = "demo.modals.root"
    /// Identifies the current-level modal dismissal command.
    static let dismissCurrent = "demo.modal.dismissCurrent"
    /// Identifies the visible direct-modal state label.
    static let modalState = "demo.state.modal"
    /// Prefixes modal-lab inspector identifiers.
    static let modalInspectorPrefix = "demo.modals"

    /// Builds a route-header identifier inside a modal container.
    ///
    /// - Parameter modalIdentifier: The identifier for the containing modal view.
    /// - Returns: The matching route-header identifier.
    static func modalHeader(_ modalIdentifier: String) -> String {
        "\(modalIdentifier).header"
    }

    /// Identifies the command that opens the first nested child.
    static let nestedOpenChild = "demo.nested.openChild"
    /// Identifies the legacy root nested push command.
    static let nestedPush = "demo.nested.push"
    /// Identifies the legacy root nested pop command.
    static let nestedPop = "demo.nested.pop"
    /// Identifies the root nested dismissal command.
    static let nestedDismiss = "demo.nested.dismiss"
    /// Identifies the nested lab root content.
    static let nestedRoot = "demo.nested.root"

    /// Builds the root-content identifier for one nested level.
    ///
    /// - Parameter level: The modal hierarchy depth.
    /// - Returns: The matching nested-level identifier.
    static func nestedLevelRoot(_ level: Int) -> String {
        "demo.nested.level\(level)"
    }

    /// Builds the state-inspector prefix for one nested level.
    ///
    /// - Parameter level: The modal hierarchy depth.
    /// - Returns: The matching inspector prefix.
    static func nestedInspectorPrefix(_ level: Int) -> String {
        "demo.nested.level\(level)"
    }

    /// Builds the open-next-level command identifier.
    ///
    /// - Parameter level: The current modal hierarchy depth.
    /// - Returns: The matching command identifier.
    static func nestedOpenNext(_ level: Int) -> String {
        "demo.nested.level\(level).openNext"
    }

    /// Builds the nested-level push command identifier.
    ///
    /// - Parameter level: The current modal hierarchy depth.
    /// - Returns: The matching command identifier.
    static func nestedPush(_ level: Int) -> String {
        "demo.nested.level\(level).push"
    }

    /// Builds the nested-level dismissal command identifier.
    ///
    /// - Parameter level: The current modal hierarchy depth.
    /// - Returns: The matching command identifier.
    static func nestedDismiss(_ level: Int) -> String {
        "demo.nested.level\(level).dismiss"
    }

    /// Identifies the legacy Router A push command.
    static let routerAPush = "demo.multiple.routerA.push"
    /// Identifies the legacy Router A pop command.
    static let routerAPop = "demo.multiple.routerA.pop"
    /// Identifies the legacy Router B push command.
    static let routerBPush = "demo.multiple.routerB.push"
    /// Identifies the legacy Router B pop command.
    static let routerBPop = "demo.multiple.routerB.pop"
    /// Identifies the multiple-routers lab root content.
    static let multipleRoot = "demo.multiple.root"
    /// Identifies the router-target picker.
    static let multipleTargetPicker = "demo.multiple.targetPicker"
    /// Identifies the Router A picker option.
    static let multipleRouterAOption = "demo.multiple.target.routerA"
    /// Identifies the Router B picker option.
    static let multipleRouterBOption = "demo.multiple.target.routerB"
    /// Identifies the selected-router state label.
    static let multipleSelectedState = "demo.multiple.state.selected"
    /// Identifies the selected-router push command.
    static let multiplePush = "demo.multiple.push"
    /// Identifies the selected-router modal command.
    static let multiplePresent = "demo.multiple.present"
    /// Identifies the selected-router pop command.
    static let multiplePop = "demo.multiple.pop"
    /// Identifies the selected-router dismissal command.
    static let multipleDismiss = "demo.multiple.dismiss"
    /// Prefixes Router A state-inspector identifiers.
    static let multipleRouterAPrefix = "demo.multiple.routerA"
    /// Prefixes Router B state-inspector identifiers.
    static let multipleRouterBPrefix = "demo.multiple.routerB"

    /// Builds a path-state identifier from an inspector prefix.
    ///
    /// - Parameter prefix: The inspector's stable prefix.
    /// - Returns: The matching path-state identifier.
    static func statePath(_ prefix: String) -> String { "\(prefix).state.path" }
    /// Builds a modal-route-state identifier from an inspector prefix.
    ///
    /// - Parameter prefix: The inspector's stable prefix.
    /// - Returns: The matching modal-route identifier.
    static func stateModalRoute(_ prefix: String) -> String { "\(prefix).state.modalRoute" }
    /// Builds a modal-style-state identifier from an inspector prefix.
    ///
    /// - Parameter prefix: The inspector's stable prefix.
    /// - Returns: The matching modal-style identifier.
    static func stateModalStyle(_ prefix: String) -> String { "\(prefix).state.modalStyle" }
    /// Builds a child-depth-state identifier from an inspector prefix.
    ///
    /// - Parameter prefix: The inspector's stable prefix.
    /// - Returns: The matching child-depth identifier.
    static func stateChildDepth(_ prefix: String) -> String { "\(prefix).state.childDepth" }
    /// Builds an outcome-state identifier from an inspector prefix.
    ///
    /// - Parameter prefix: The inspector's stable prefix.
    /// - Returns: The matching outcome identifier.
    static func stateOutcome(_ prefix: String) -> String { "\(prefix).state.outcome" }
    /// Builds a current-route-state identifier from an inspector prefix.
    ///
    /// - Parameter prefix: The inspector's stable prefix.
    /// - Returns: The matching current-route identifier.
    static func stateCurrentRoute(_ prefix: String) -> String { "\(prefix).state.currentRoute" }
}
