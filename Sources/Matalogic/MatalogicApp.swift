import SwiftUI

@main
struct MatalogicApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.purple)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1480, height: 900)
    }
}
