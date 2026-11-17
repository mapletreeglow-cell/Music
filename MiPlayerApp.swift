import SwiftUI

@main
struct MiPlayerApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var player = PlayerModel()
    @StateObject private var theme = ThemeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(player)
                .environmentObject(theme)
                .task {
                    player.library = library
                    library.scanMusicFolder()
                }
        }
    }
}
