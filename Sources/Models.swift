import Foundation

enum Role: String, Codable {
    case user, assistant
}

struct Message: Identifiable, Codable, Equatable {
    var id = UUID()
    let role: Role
    var content: String

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

struct Chat: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var messages: [Message]
    var created = Date()

    init(id: UUID = UUID(), title: String = "Новый чат", messages: [Message] = []) {
        self.id = id
        self.title = title
        self.messages = messages
    }
}
