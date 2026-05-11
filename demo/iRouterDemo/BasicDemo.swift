import SwiftUI
import iRouter

struct HomeView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Section("Basic Navigation") {
                Button("Push Detail") {
                    router.push(.detail(id: "42"))
                }
                Button("Push Settings (auth guarded)") {
                    router.push(.settings)
                }
                Button("Sheet Login") {
                    router.sheet(.login)
                }
                Button("FullScreen Feed") {
                    router.fullScreenCover(.feed)
                }
            }
        }
        .navigationTitle("Home")
    }
}

struct DetailView: View {
    let id: String
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        VStack(spacing: 20) {
            Text("Detail: \(id)")
                .font(.title)
            Button("Push Another Detail") {
                router.push(.detail(id: "sub-\(id)"))
            }
            Button("Pop") {
                router.pop()
            }
            Button("Pop to Root") {
                router.popToRoot()
            }
        }
        .navigationTitle("Detail \(id)")
    }
}

struct FeedView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        VStack(spacing: 20) {
            Text("Feed (FullScreenCover)")
                .font(.title2)
            Button("Dismiss") {
                router.dismiss()
            }
            Button("Push Detail inside Cover") {
                router.push(.detail(id: "feed-1"))
            }
        }
        .navigationTitle("Feed")
    }
}
