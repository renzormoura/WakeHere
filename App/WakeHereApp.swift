import SwiftUI

@main
struct WakeHereApp: App {
    @StateObject private var root = CompositionRoot()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(root)
        }
    }
}
