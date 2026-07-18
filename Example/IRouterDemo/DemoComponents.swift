import IRouter
import SwiftUI

/// Displays observable stack, modal, hierarchy, and outcome state for one router.
struct RouterInspector: View {
    /// The router whose current state is displayed.
    let router: IRouter<AppRoute>
    /// The latest command result produced by the owning lab.
    let latestOutcome: String
    /// The prefix used to create stable test identifiers for inspector rows.
    let accessibilityPrefix: String

    /// Builds the router-state inspector.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            inspectorRow(
                title: "Path",
                value: router.path.displayText,
                identifier: DemoAccessibility.statePath(accessibilityPrefix)
            )
            inspectorRow(
                title: "Modal route",
                value: router.modalContext?.route.compactTitle ?? "none",
                identifier: DemoAccessibility.stateModalRoute(accessibilityPrefix)
            )
            inspectorRow(
                title: "Modal style",
                value: router.modalContext?.style.displayText ?? "none",
                identifier: DemoAccessibility.stateModalStyle(accessibilityPrefix)
            )
            inspectorRow(
                title: "Child depth",
                value: String(childDepth),
                identifier: DemoAccessibility.stateChildDepth(accessibilityPrefix)
            )
            inspectorRow(
                title: "Latest outcome",
                value: latestOutcome,
                identifier: DemoAccessibility.stateOutcome(accessibilityPrefix)
            )
        }
        .font(.callout)
    }

    /// The number of consecutively presented modal child-router levels.
    private var childDepth: Int {
        var depth = 0
        var context = router.modalContext
        while let current = context {
            depth += 1
            context = current.childRouter.modalContext
        }
        return depth
    }

    /// Builds one labeled inspector value.
    ///
    /// - Parameters:
    ///   - title: The human-readable state label.
    ///   - value: The formatted state value.
    ///   - identifier: The stable UI-test identifier.
    /// - Returns: A labeled, monospaced inspector row.
    private func inspectorRow(
        title: String,
        value: String,
        identifier: String
    ) -> some View {
        LabeledContent(title) {
            Text(value)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
        }
    }
}

/// Renders a consistently styled, test-addressable router command button.
struct DemoCommandButton: View {
    /// The visible command title.
    let title: String
    /// The symbol displayed beside the title.
    let systemImage: String
    /// The stable UI-test identifier for the button.
    let accessibilityIdentifier: String
    /// The optional semantic button role.
    var role: ButtonRole?
    /// A value indicating whether the command is unavailable.
    var isDisabled = false
    /// The main-actor command executed by the button.
    let action: @MainActor () -> Void

    /// Creates a router command button.
    ///
    /// - Parameters:
    ///   - title: The visible command title.
    ///   - systemImage: The system symbol displayed beside the title.
    ///   - accessibilityIdentifier: The stable UI-test identifier.
    ///   - role: An optional semantic button role.
    ///   - isDisabled: Whether the command begins disabled.
    ///   - action: The main-actor router command to execute.
    init(
        _ title: String,
        systemImage: String,
        accessibilityIdentifier: String,
        role: ButtonRole? = nil,
        isDisabled: Bool = false,
        action: @MainActor @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.role = role
        self.isDisabled = isDisabled
        self.action = action
    }

    /// Builds the styled command button.
    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
        }
        .disabled(isDisabled)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

/// Provides consistent list presentation for one Example lab.
struct DemoSectionContainer<Content: View>: View {
    /// The navigation title for the lab.
    let title: String
    /// The list sections supplied by the caller.
    private let content: Content

    /// Creates a lab container.
    ///
    /// - Parameters:
    ///   - title: The lab's navigation title.
    ///   - content: A builder for the lab's list sections.
    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    /// Applies platform-specific list spacing.
    var body: some View {
        #if os(macOS)
        list
        #else
        list.listSectionSpacing(.compact)
        #endif
    }

    /// The shared list and navigation-title presentation.
    private var list: some View {
        List {
            content
        }
        .listStyle(.inset)
        .navigationTitle(title)
    }
}

/// Displays the current route and a short explanation for a lab.
struct DemoRouteHeader: View {
    /// The route currently rendered by the destination builder.
    let route: AppRoute
    /// Explanatory text for the current scenario.
    let detail: String
    /// The stable UI-test identifier for the header.
    let accessibilityIdentifier: String

    /// Builds the route title and explanatory text.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(route.title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
