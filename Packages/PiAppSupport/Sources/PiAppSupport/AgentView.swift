import SwiftUI
import PiSwiftAI
import PiSwiftAgent
import Foundation

enum KeyType: String, CaseIterable {
    case apiKey = "api_key"
    case oauth = "oauth"
}

@Observable
final class AgentManager {
    var agent: Agent?
    var hasAPIKey: Bool = false
    
    let provider: String
    let modelId: String
    
    init(provider: String = "anthropic", modelId: String = "claude-opus-4-5") {
        self.provider = provider
        self.modelId = modelId
        refreshAgent()
    }
    
    func refreshAgent() {
        let apiKey = APIKeyManager.shared.getAPIKey(for: provider)
        hasAPIKey = apiKey != nil
        
        if let apiKey {
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = getModel(provider: .anthropic, modelId: modelId)
            
            let initialState = AgentState(
                systemPrompt: "You are a helpful AI assistant.",
                model: model,
                thinkingLevel: .off,
                tools: [],
                messages: []
            )
            
            self.agent = Agent(AgentOptions(
                initialState: initialState,
                getApiKey: { _ in trimmedKey }
            ))
        } else {
            self.agent = nil
        }
    }
}

/// A simple chat view that uses PiSwift's Agent for AI interactions.
public struct AgentView: View {
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isStreaming = false
    @State private var currentResponse = ""
    @State private var showingAPIKeySheet = false
    @State private var apiKeyInput = ""
    @State private var selectedKeyType: KeyType = .apiKey
    @State private var agentManager: AgentManager
    
    @Environment(\.scenePhase) private var scenePhase

    public init(provider: String = "anthropic", modelId: String = "claude-opus-4-5") {
        self._agentManager = State(initialValue: AgentManager(provider: provider, modelId: modelId))
    }

    public var body: some View {
        Group {
            if agentManager.hasAPIKey, agentManager.agent != nil {
                chatView
            } else {
                noAPIKeyView
            }
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            apiKeySheet
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                agentManager.refreshAgent()
            }
        }
        .onAppear {
            agentManager.refreshAgent()
        }
    }

    private var chatView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    showingAPIKeySheet = true
                } label: {
                    Image(systemName: "key")
                }
                .buttonStyle(.borderless)
                .padding(.horizontal)
            }
            .padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }

                        if !currentResponse.isEmpty {
                            MessageBubble(message: ChatMessage(role: .assistant, content: currentResponse))
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack {
                TextField("Message...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onSubmit {
                        sendMessage()
                    }
                    .disabled(isStreaming)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: isStreaming ? "stop.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming)
                .buttonStyle(.borderless)
            }
            .padding()
        }
    }

    private var noAPIKeyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No API Key Configured")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Set an API key to start chatting with Claude.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("You can also set the ANTHROPIC_API_KEY environment variable.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("Configure API Key") {
                showingAPIKeySheet = true
            }
            .buttonStyle(.borderedProminent)
            
            Button("Refresh") {
                agentManager.refreshAgent()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var apiKeySheet: some View {
        VStack(spacing: 20) {
            Text("Anthropic API Key")
                .font(.headline)

            Picker("Key Type", selection: $selectedKeyType) {
                Text("API Key").tag(KeyType.apiKey)
                Text("Claude Code (OAuth)").tag(KeyType.oauth)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            SecureField(selectedKeyType == .apiKey ? "sk-ant-api03-..." : "sk-ant-oat-...", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            if selectedKeyType == .apiKey {
                Link(destination: URL(string: "https://platform.claude.com/settings/keys")!) {
                    Label("Get an API key from Anthropic", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
            } else {
                Text("Use your Claude Code / Claude Pro OAuth token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") {
                    apiKeyInput = ""
                    showingAPIKeySheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveAPIKey()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if agentManager.hasAPIKey {
                Divider()
                Button("Delete Saved Key", role: .destructive) {
                    deleteAPIKey()
                }
                .font(.caption)
            }
        }
        .padding()
        .frame(minWidth: 350)
    }

    private func saveAPIKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            return
        }

        do {
            try APIKeyManager.shared.setAPIKey(key, for: agentManager.provider)
            agentManager.refreshAgent()
            apiKeyInput = ""
            showingAPIKeySheet = false
        } catch {
            // Handle error - could show an alert
        }
    }

    private func deleteAPIKey() {
        do {
            try APIKeyManager.shared.deleteAPIKey(for: agentManager.provider)
            agentManager.refreshAgent()
            apiKeyInput = ""
            showingAPIKeySheet = false
        } catch {
            // Handle error
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))

        Task {
            await streamResponse(text)
        }
    }

    private func streamResponse(_ text: String) async {
        guard let agent = agentManager.agent else {
            return
        }

        isStreaming = true
        currentResponse = ""

        let unsubscribe = agent.subscribe { [self] event in
            Task { @MainActor in
                handleAgentEvent(event)
            }
        }

        defer {
            unsubscribe()
            isStreaming = false
        }

        let userMessage = AgentMessage.user(UserMessage(content: .text(text)))

        print("[AgentView] Sending prompt: \(text)")
        print("[AgentView] Agent state - model: \(agent.state.model.id), provider: \(agent.state.model.provider)")
        print("[AgentView] Agent state - baseUrl: \(agent.state.model.baseUrl)")
        
        // Check if API key is available
        if let apiKey = APIKeyManager.shared.getAPIKey(for: agentManager.provider) {
            let prefix = String(apiKey.prefix(12))
            let suffix = String(apiKey.suffix(4))
            print("[AgentView] API key available, length: \(apiKey.count), key: \(prefix)...\(suffix)")
        } else {
            print("[AgentView] WARNING: No API key found!")
        }

        do {
            try await agent.prompt(userMessage)
            print("[AgentView] Prompt completed")
        } catch {
            print("[AgentView] Prompt error: \(error)")
            print("[AgentView] Prompt error type: \(type(of: error))")
            print("[AgentView] Prompt error description: \(String(describing: error))")
            messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
        }
    }

    @MainActor
    private func handleAgentEvent(_ event: AgentEvent) {
        print("[AgentView] Event: \(event)")
        switch event {
        case .messageUpdate(let message, let assistantEvent):
            print("[AgentView] messageUpdate - message: \(message), assistantEvent: \(assistantEvent)")
            if case .textDelta(_, let delta, _) = assistantEvent {
                print("[AgentView] textDelta: \(delta)")
                currentResponse += delta
            }
        case .messageEnd(let message):
            print("[AgentView] messageEnd: \(message)")
            if case .assistant(let assistant) = message {
                print("[AgentView] assistant content blocks: \(assistant.content)")
                print("[AgentView] assistant stopReason: \(assistant.stopReason)")
                if let errorMessage = assistant.errorMessage {
                    print("[AgentView] assistant error: \(errorMessage)")
                }
                let fullText = assistant.content.compactMap { block -> String? in
                    if case .text(let textBlock) = block {
                        print("[AgentView] text block: \(textBlock.text)")
                        return textBlock.text
                    }
                    return nil
                }.joined()
                print("[AgentView] fullText: \(fullText)")
                messages.append(ChatMessage(role: .assistant, content: fullText))
                currentResponse = ""
            }
        default:
            break
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role {
        case user
        case assistant
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            Text(message.content)
                .textSelection(.enabled)
                .padding(12)
                .background(message.role == .user ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role == .assistant {
                Spacer()
            }
        }
        .id(message.id)
    }
}
