import SwiftUI

@main
struct MoltShotApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // 菜单栏工具类 App：不需要主窗口
        Settings {
            EmptyView()
        }
        .environmentObject(appState)
    }
}
