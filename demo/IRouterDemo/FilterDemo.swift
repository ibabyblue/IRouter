import SwiftUI
import IRouter

// MARK: - ③ Filter Demo

struct FilterDemoView: View {
    @State private var router = IRouter<AppRoute>(root: .home)

    var body: some View {
        IRouterView(router: router) { route in
            switch route {
            case .home:     FilterMenuView()
            case .a:        AllowFilterTestView()
            case .b:        BlockFilterTestView()
            case .c:        RedirectFilterTestView()
            case .settings: ChainFilterTestView()
            default:        EmptyView()
            }
        }
    }
}

// MARK: 菜单

private struct FilterMenuView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Button("Allow — push(.a) → 导航正常执行")        { router.push(.a) }
            Button("Block — push(.b) → 导航被拦截")          { router.push(.b) }
            Button("Redirect — push(.c) → 重定向到 sheet")   { router.push(.c) }
            Button("Chain — push(.settings) → filter 链")    { router.push(.settings) }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Filter 测试")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { DismissButton() }
        }
    }
}

// MARK: Allow
// 预期：filter 全部放行，push / sheet / dismiss 正常改变 state

private struct AllowFilterTestView: View {
    @State private var router = IRouter<AppRoute>(
        root: .home,
        filters: [IRouterFilter { _, _ in .allow }]
    )

    var body: some View {
        List {
            Section("State") {
                RouterStateView(router: router)
            }
            Section("预期：操作正常执行") {
                Button("push(.a)  → path = [a]")           { router.push(.a) }
                Button("sheet(.login)  → sheetContext 设置") { router.sheet(.login) }
                Button("dismiss()")                         { router.dismiss() }
                Button("popToRoot()  → path = []")          { router.popToRoot() }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Allow Filter")
    }
}

// MARK: Block
// 预期：filter 全部拦截，state 始终不变

private struct BlockFilterTestView: View {
    @State private var router = IRouter<AppRoute>(
        root: .home,
        filters: [IRouterFilter { _, _ in .block }]
    )

    var body: some View {
        List {
            Section("State") {
                RouterStateView(router: router)
            }
            Section("预期：state 始终不变") {
                Button("push(.a)  → path 仍为 []")             { router.push(.a) }
                Button("sheet(.login)  → sheetContext 仍为 nil") { router.sheet(.login) }
                Button("fullScreenCover(.feed)  → cover 仍为 nil") { router.fullScreenCover(.feed) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Block Filter")
    }
}

// MARK: Redirect
// 预期：push(.settings) 被重定向为 sheet(.login)；其他路由正常放行

private struct RedirectFilterTestView: View {
    @State private var router = IRouter<AppRoute>(
        root: .home,
        filters: [
            IRouterFilter { route, _ in
                if case .settings = route { return .redirect(.login, .sheet) }
                return .allow
            }
        ]
    )

    var body: some View {
        List {
            Section("State") {
                RouterStateView(router: router)
            }
            Section("预期") {
                Button("push(.a)  → path = [a]，正常入栈") { router.push(.a) }
                Button("push(.settings)  → redirect → sheetContext = login") {
                    router.push(.settings)
                }
                Button("dismiss()  → 关闭 sheet / pop") { router.dismiss() }
                Button("popToRoot()") { router.popToRoot() }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Redirect Filter")
    }
}

// MARK: Chain
// 预期：push(.a) → filter1 allow → filter2 allow → 入栈
//       push(.b) → filter1 block → filter2 不执行 → state 不变

@Observable
private final class ChainLog: @unchecked Sendable {
    var entries: [String] = []
    func append(_ s: String) { entries.append(s) }
    func clear() { entries = [] }
}

private struct ChainFilterTestView: View {
    @State private var log = ChainLog()
    @State private var router = IRouter<AppRoute>(root: .home)

    var body: some View {
        List {
            Section("State") {
                RouterStateView(router: router)
            }
            Section("Filter 执行日志") {
                if log.entries.isEmpty {
                    Text("（尚未操作）").foregroundStyle(.secondary)
                }
                ForEach(Array(log.entries.enumerated()), id: \.offset) { _, entry in
                    Text(entry).font(.caption.monospaced())
                }
                if !log.entries.isEmpty {
                    Button("清空") { rebuild() }
                }
            }
            Section("预期") {
                Button("push(.a)  → f1 allow, f2 allow, path = [a]") {
                    rebuild()
                    router.push(.a)
                }
                Button("push(.b)  → f1 block, f2 不执行, path = []") {
                    rebuild()
                    router.push(.b)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Filter Chain")
        .onAppear { rebuild() }
    }

    private func rebuild() {
        log.clear()
        let log = log
        router = IRouter<AppRoute>(
            root: .home,
            filters: [
                IRouterFilter { route, _ in
                    Task { @MainActor in log.append("filter1 called") }
                    if case .b = route {
                        Task { @MainActor in log.append("filter1 → .block (chain stops)") }
                        return .block
                    }
                    Task { @MainActor in log.append("filter1 → .allow") }
                    return .allow
                },
                IRouterFilter { _, _ in
                    Task { @MainActor in log.append("filter2 called → .allow") }
                    return .allow
                },
            ]
        )
    }
}
