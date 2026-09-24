import Foundation

/// Инструмент read_url: скачивает веб-страницу и возвращает её текст.
enum WebFetch {
    static let toolDefinition: [String: Any] = [
        "type": "function",
        "function": [
            "name": "read_url",
            "description": "Открыть веб-страницу по ссылке и прочитать её текстовое содержимое. Используй, когда пользователь даёт ссылку или нужно посмотреть содержимое конкретной страницы.",
            "parameters": [
                "type": "object",
                "properties": [
                    "url": [
                        "type": "string",
                        "description": "Полный URL страницы, включая https://"
                    ]
                ],
                "required": ["url"]
            ]
        ]
    ]

    static func handle(_ toolCall: [String: Any]) async -> String {
        let fn = toolCall["function"] as? [String: Any] ?? [:]
        let argsString = fn["arguments"] as? String ?? "{}"
        guard let data = argsString.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = args["url"] as? String,
              let url = URL(string: urlString) else {
            return "Ошибка: не удалось разобрать URL"
        }
        return await fetch(url)
    }

    static func fetch(_ url: URL) async -> String {
        do {
            var request = URLRequest(url: url, timeoutInterval: 20)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                             forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status) else {
                return "Ошибка: сервер ответил HTTP \(status)"
            }
            let html = String(decoding: data.prefix(1_000_000), as: UTF8.self)
            let text = htmlToText(html)
            return text.isEmpty ? "Страница пуста или не содержит текста" : String(text.prefix(12_000))
        } catch {
            return "Ошибка загрузки: \(error.localizedDescription)"
        }
    }

    /// Грубая, но быстрая очистка HTML в читаемый текст.
    static func htmlToText(_ html: String) -> String {
        var text = html
        text = replace(in: text, pattern: "(?is)<(script|style)[^>]*>.*?</\\1>", with: " ")
        text = replace(in: text, pattern: "(?i)</(p|div|li|h[1-6]|tr|section|article)>|<br[^>]*>", with: "\n")
        text = replace(in: text, pattern: "<[^>]+>", with: "")

        let entities = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&apos;": "'"
        ]
        for (entity, value) in entities {
            text = text.replacingOccurrences(of: entity, with: value)
        }

        text = replace(in: text, pattern: "[ \\t]+", with: " ")
        text = replace(in: text, pattern: "\\n{3,}", with: "\n\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replace(in text: String, pattern: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }
}
