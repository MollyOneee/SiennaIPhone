import SwiftUI

@main
struct QwenChatApp: App {
    @StateObject private var settings = Settings()
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            ChatListView()
                .environmentObject(settings)
                .environmentObject(store)
        }
    }
}
