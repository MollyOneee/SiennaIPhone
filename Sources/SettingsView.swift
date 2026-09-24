import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("API") {
                    SecureField("API ключ", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Модель (например qwen-plus)", text: $settings.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Base URL", text: $settings.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.footnote)
                }

                Section("Веб") {
                    Toggle("Веб-поиск (enable_search)", isOn: $settings.webSearch)
                }

                Section {
                    Text("Ключ хранится в Keychain на устройстве и никуда не отправляется, кроме API DashScope.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Если при отправке сообщения приходит ошибка про enable_search — выключи тумблер веб-поиска: твоя модель может его не поддерживать.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
