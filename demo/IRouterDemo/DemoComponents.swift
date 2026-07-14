import IRouter
import SwiftUI

struct RouterInspector: View {
    let router: IRouter<AppRoute>
    let latestOutcome: String
    let accessibilityPrefix: String

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

    private var childDepth: Int {
        var depth = 0
        var context = router.modalContext
        while let current = context {
            depth += 1
            context = current.childRouter.modalContext
        }
        return depth
    }

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

struct DemoCommandButton: View {
    let title: String
    let systemImage: String
    let accessibilityIdentifier: String
    var role: ButtonRole?
    var isDisabled = false
    let action: @MainActor () -> Void

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

struct DemoSectionContainer<Content: View>: View {
    let title: String
    private let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        #if os(macOS)
        list
        #else
        list.listSectionSpacing(.compact)
        #endif
    }

    private var list: some View {
        List {
            content
        }
        .listStyle(.inset)
        .navigationTitle(title)
    }
}

struct DemoRouteHeader: View {
    let route: AppRoute
    let detail: String
    let accessibilityIdentifier: String

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
