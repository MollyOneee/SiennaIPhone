import Foundation
import Combine

final class Settings: ObservableObject {
    static let defaultBaseURL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "baseURL") }
    }
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: "model") }
    }
    @Published var apiKey: String {
        didSet { Keychain.set(apiKey, for: "apiKey") }
    }
    @Published var webSearch: Bool {
        didSet { UserDefaults.standard.set(webSearch, forKey: "webSearch") }
    }

    init() {
        baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? Self.defaultBaseURL
        model = UserDefaults.standard.string(forKey: "model") ?? "qwen-plus"
        apiKey = Keychain.get("apiKey") ?? ""
        webSearch = UserDefaults.standard.object(forKey: "webSearch") as? Bool ?? true
    }
}
