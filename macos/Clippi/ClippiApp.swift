import SwiftUI

@main
struct ClippiApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 700, height: 600)
    }
}
