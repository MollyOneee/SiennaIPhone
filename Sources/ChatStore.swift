import Foundation

/// Хранит чаты локально на устройстве (JSON в Documents).
@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var chats: [Chat] = []

    private var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chats.json")
    }

    init() {
        load()
    }

    func newChat() -> Chat {
        let chat = Chat()
        chats.insert(chat, at: 0)
        save()
        return chat
    }

    func update(_ chat: Chat) {
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[index] = chat
            save()
        }
    }

    func delete(at offsets: IndexSet) {
        chats.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Chat].self, from: data) else { return }
        chats = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(chats) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
