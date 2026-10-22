import SwiftUI

@main
struct AcordeAquiApp: App {
    @StateObject private var root = CompositionRoot()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(root)
        }
    }
}
