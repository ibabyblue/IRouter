import SwiftUI

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
