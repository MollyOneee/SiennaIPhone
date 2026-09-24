import SwiftUI

struct ChatView: View {
    @StateObject private var vm: ChatViewModel
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var store: ChatStore
    @FocusState private var inputFocused: Bool
    @State private var input = ""

    init(chat: Chat) {
        _vm = StateObject(wrappedValue: ChatViewModel(chat: chat))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.chat.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id.uuidString)
                        }
                        if !vm.streamingText.isEmpty {
                            MessageBubble(message: Message(role: .assistant, content: vm.streamingText))
                                .id("streaming")
                        }
                        if let status = vm.statusText {
                            Text(status)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .id("status")
                        } else if vm.isStreaming && vm.streamingText.isEmpty {
                            Text("Думаю…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .id("status")
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.streamingText) { _ in scrollToBottom(proxy) }
                .onChange(of: vm.chat.messages.count) { _ in scrollToBottom(proxy) }
            }

            if settings.apiKey.isEmpty {
                Text("Сначала укажи API-ключ в настройках (шестерёнка на главном экране)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }

            Divider()

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Сообщение", text: $input, axis: .vertical)
                    .focused($inputFocused)
                    .lineLimit(1...6)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Button {
                    let text = input
                    input = ""
                    vm.send(text, settings: settings)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isStreaming)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle(vm.chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onChange = { updated in store.update(updated) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        let target: String
        if vm.statusText != nil || (vm.isStreaming && vm.streamingText.isEmpty) {
            target = "status"
        } else if !vm.streamingText.isEmpty {
            target = "streaming"
        } else {
            target = vm.chat.messages.last?.id.uuidString ?? ""
        }
        guard !target.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Group {
                if let attributed = try? AttributedString(markdown: message.content) {
                    Text(attributed)
                } else {
                    Text(message.content)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(message.role == .user ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(message.role == .user ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .textSelection(.enabled)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}
