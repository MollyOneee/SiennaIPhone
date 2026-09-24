import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var store: ChatStore
    @State private var showSettings = false
    @State private var newChat: Chat?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.chats) { chat in
                    NavigationLink {
                        ChatView(chat: chat)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.title).lineLimit(1)
                            Text(chat.created, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: store.delete)
            }
            .navigationTitle("Чаты")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { newChat = store.newChat() } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .navigationDestination(item: $newChat) { chat in
                ChatView(chat: chat)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .overlay {
                if store.chats.isEmpty {
                    VStack(spacing: 12) {
                        Text("Пока пусто")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Нажми на карандаш, чтобы начать новый чат")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
