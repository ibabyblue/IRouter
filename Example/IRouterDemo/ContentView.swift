import SwiftUI

/// Presents the five router labs using platform-appropriate navigation.
struct ContentView: View {
    #if os(macOS)
    /// The lab selected in the macOS split-view sidebar.
    @State private var selection: DemoSection? = .stack
    #endif

    /// Builds an iOS tab catalog or macOS split-view catalog.
    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(DemoSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
                    .accessibilityIdentifier(section.accessibilityIdentifier)
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

    /// Builds the destination associated with one catalog section.
    ///
    /// - Parameter section: The router lab to display.
    @ViewBuilder
    private func demoView(_ section: DemoSection) -> some View {
        switch section {
        case .stack:
            StackDemoView()
        case .filters:
            FilterDemoView()
        case .modals:
            ModalDemoView()
        case .nested:
            NestedDemoView()
        case .multipleRouters:
            MultipleRoutersDemoView()
        }
    }

    /// Wraps one iOS lab in its tab metadata.
    ///
    /// - Parameters:
    ///   - section: The catalog metadata for the tab.
    ///   - content: The lab content displayed by the tab.
    /// - Returns: The supplied content with its tab item attached.
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
}
