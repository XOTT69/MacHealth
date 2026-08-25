import SwiftUI

@main
struct MacHealthApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 750)
    }
}
