import Foundation

enum StreamEvent {
    case text(String)
    case status(String)
}

enum APIError: LocalizedError {
    case badURL
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Некорректный Base URL"
        case .http(let code, let body):
            return "HTTP \(code): \(body.prefix(300))"
        }
    }
}

/// Клиент для OpenAI-совместимого API DashScope (Alibaba Cloud).
/// Ходит в интернет напрямую с телефона, без каких-либо прокси.
final class APIService {
    private let settings: Settings
    private let maxToolRounds = 3

    init(settings: Settings) {
        self.settings = settings
    }

    /// Стримит ответ модели. Если модель вызывает инструменты (например read_url),
    /// выполняет их и продолжает диалог, максимум `maxToolRounds` раундов.
    func chat(messages: [[String: Any]]) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var convo = messages
                    var round = 0
                    while true {
                        let result = try await self.streamRound(convo) { piece in
                            continuation.yield(.text(piece))
                        }
                        guard !result.toolCalls.isEmpty, round < self.maxToolRounds else { break }
                        round += 1

                        var assistantMsg: [String: Any] = ["role": "assistant"]
                        assistantMsg["content"] = result.text.isEmpty ? NSNull() : result.text
                        assistantMsg["tool_calls"] = result.toolCalls
                        convo.append(assistantMsg)

                        for call in result.toolCalls {
                            let fn = call["function"] as? [String: Any] ?? [:]
                            let name = fn["name"] as? String ?? "tool"
                            continuation.yield(.status("Использую инструмент: \(name)…"))
                            let output = await WebFetch.handle(call)
                            convo.append([
                                "role": "tool",
                                "tool_call_id": call["id"] as? String ?? "",
                                "content": output
                            ])
                        }
                        continuation.yield(.text("\n\n"))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private struct RoundResult {
        var text: String
        var toolCalls: [[String: Any]]
    }

    private func streamRound(_ messages: [[String: Any]],
                             onText: @escaping (String) -> Void) async throws -> RoundResult {
        let base = settings.baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/chat/completions") else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "model": settings.model,
            "messages": messages,
            "stream": true,
            "tools": [WebFetch.toolDefinition]
        ]
        if settings.webSearch {
            body["enable_search"] = true
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            var errorBody = ""
            for try await line in bytes.lines { errorBody += line }
            throw APIError.http(http.statusCode, errorBody)
        }

        var text = ""
        var toolCalls: [Int: (id: String, name: String, args: String)] = [:]

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any] else { continue }

            if let content = delta["content"] as? String, !content.isEmpty {
                text += content
                onText(content)
            }
            if let calls = delta["tool_calls"] as? [[String: Any]] {
                for call in calls {
                    let idx = call["index"] as? Int ?? 0
                    var acc = toolCalls[idx] ?? (id: "", name: "", args: "")
                    if let id = call["id"] as? String { acc.id += id }
                    if let fn = call["function"] as? [String: Any] {
                        if let name = fn["name"] as? String { acc.name += name }
                        if let args = fn["arguments"] as? String { acc.args += args }
                    }
                    toolCalls[idx] = acc
                }
            }
        }

        let calls: [[String: Any]] = toolCalls.sorted { $0.key < $1.key }.map { _, acc in
            [
                "id": acc.id.isEmpty ? "call_\(UUID().uuidString)" : acc.id,
                "type": "function",
                "function": ["name": acc.name, "arguments": acc.args]
            ]
        }
        return RoundResult(text: text, toolCalls: calls)
    }
}
