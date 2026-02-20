import SwiftUI
import PiSwiftAI
import PiSwiftAgent
import PiSwiftCodingAgent
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
    let workingDirectory: String
    
    init(provider: String = "anthropic", modelId: String = "claude-opus-4-5", workingDirectory: String? = nil) {
        self.provider = provider
        self.modelId = modelId
        self.workingDirectory = workingDirectory ?? FileManager.default.currentDirectoryPath
        refreshAgent()
    }
    
    func refreshAgent() {
        let apiKey = APIKeyManager.shared.getAPIKey(for: provider)
        hasAPIKey = apiKey != nil
        
        if let apiKey {
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = getModel(provider: .anthropic, modelId: modelId)
            
            // Create coding tools with the current working directory
            let tools = createCodingTools(cwd: workingDirectory)
            
            let initialState = AgentState(
                systemPrompt: """
                    You are a helpful AI coding assistant. You have access to tools to read, write, and edit files, \
                    as well as run bash commands. Use these tools to help users with coding tasks.
                    
                    Current working directory: \(workingDirectory)
                    """,
                model: model,
                thinkingLevel: .off,
                tools: tools,
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

        do {
            try await agent.prompt(userMessage)
        } catch {
            messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
        }
    }

    @MainActor
    private func handleAgentEvent(_ event: AgentEvent) {
        switch event {
        case .messageUpdate(_, let assistantEvent):
            if case .textDelta(_, let delta, _) = assistantEvent {
                currentResponse += delta
            }
        case .messageEnd(let message):
            if case .assistant(let assistant) = message {
                let fullText = assistant.content.compactMap { block -> String? in
                    if case .text(let textBlock) = block {
                        return textBlock.text
                    }
                    return nil
                }.joined()
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
