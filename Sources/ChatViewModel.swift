import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var chat: Chat
    @Published var isStreaming = false
    @Published var streamingText = ""
    @Published var statusText: String?

    /// Вызывается, когда чат изменился и его пора сохранить.
    var onChange: (Chat) -> Void = { _ in }

    private let systemPrompt = """
    Ты — полезный ассистент в мобильном чат-приложении. Отвечай на языке пользователя, \
    по делу и без лишней воды. У тебя есть доступ к веб-поиску и к инструменту read_url \
    для чтения конкретных страниц. Сегодняшняя дата: 
    """

    init(chat: Chat) {
        self.chat = chat
    }

    func send(_ text: String, settings: Settings) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming, !settings.apiKey.isEmpty else { return }

        if chat.messages.isEmpty {
            chat.title = String(trimmed.prefix(40))
        }
        chat.messages.append(Message(role: .user, content: trimmed))
        isStreaming = true
        streamingText = ""
        statusText = nil

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt + formatter.string(from: Date())]
        ]
        apiMessages += chat.messages.map {
            ["role": $0.role.rawValue, "content": $0.content]
        }

        let service = APIService(settings: settings)
        Task {
            do {
                for try await event in service.chat(messages: apiMessages) {
                    switch event {
                    case .text(let piece):
                        streamingText += piece
                    case .status(let status):
                        statusText = status
                    }
                }
                finish(content: streamingText)
            } catch {
                var content = streamingText
                if !content.isEmpty { content += "\n\n" }
                content += "⚠️ Ошибка: \(error.localizedDescription)"
                finish(content: content)
            }
        }
    }

    private func finish(content: String) {
        if !content.isEmpty {
            chat.messages.append(Message(role: .assistant, content: content))
        }
        streamingText = ""
        statusText = nil
        isStreaming = false
        onChange(chat)
    }
}
