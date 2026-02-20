import SwiftUI
import PiSwiftAI

public struct OAuthLoginView: View {
    @State private var isLoggingIn = false
    @State private var statusMessage = ""
    @State private var authUrl: String?
    @State private var showingCodeInput = false
    @State private var codeInput = ""
    @State private var pendingPrompt: OAuthPrompt?
    @State private var promptInput = ""
    @State private var promptContinuation: CheckedContinuation<String, Error>?
    @State private var error: String?
    @State private var loginSuccess = false
    
    @Environment(\.dismiss) private var dismiss
    
    private let provider: OAuthProvider
    private let onComplete: (OAuthCredentials) -> Void
    
    public init(provider: OAuthProvider = .anthropic, onComplete: @escaping (OAuthCredentials) -> Void) {
        self.provider = provider
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Login with \(providerName)")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            if loginSuccess {
                Label("Login successful!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else if isLoggingIn {
                ProgressView()
                    .padding()
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let authUrl {
                    VStack(spacing: 12) {
                        Text("Open this URL in your browser to authorize:")
                            .font(.callout)
                        
                        Link(destination: URL(string: authUrl)!) {
                            Label("Open Authorization Page", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Copy URL") {
                            #if os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(authUrl, forType: .string)
                            #endif
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                if showingCodeInput {
                    VStack(spacing: 12) {
                        Text("Paste the authorization code:")
                            .font(.callout)
                        
                        TextField("Authorization code...", text: $codeInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 300)
                        
                        Button("Submit") {
                            submitCode()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(codeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                if let prompt = pendingPrompt {
                    VStack(spacing: 12) {
                        Text(prompt.message)
                            .font(.callout)
                        
                        TextField(prompt.placeholder ?? "", text: $promptInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 300)
                        
                        Button("Continue") {
                            submitPrompt()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!prompt.allowEmpty && promptInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Button("Cancel") {
                    cancelLogin()
                }
                .buttonStyle(.bordered)
            } else {
                Text(providerDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Start Login") {
                    startLogin()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(30)
        .frame(minWidth: 400)
    }
    
    private var providerName: String {
        switch provider {
        case .anthropic:
            return "Claude Pro/Max"
        case .githubCopilot:
            return "GitHub Copilot"
        case .googleGeminiCli:
            return "Google Gemini CLI"
        case .googleAntigravity:
            return "Antigravity"
        case .openAICodex:
            return "ChatGPT Plus/Pro"
        }
    }
    
    private var providerDescription: String {
        switch provider {
        case .anthropic:
            return "Login with your Claude Pro or Claude Max subscription to use Claude without API credits."
        case .githubCopilot:
            return "Login with your GitHub Copilot subscription."
        case .googleGeminiCli:
            return "Login with Google Cloud Code Assist."
        case .googleAntigravity:
            return "Login with Antigravity (Gemini 3, Claude, GPT-OSS)."
        case .openAICodex:
            return "Login with your ChatGPT Plus or Pro subscription."
        }
    }
    
    private func startLogin() {
        isLoggingIn = true
        error = nil
        statusMessage = "Starting login..."
        
        Task {
            do {
                let credentials = try await performLogin()
                await MainActor.run {
                    loginSuccess = true
                    statusMessage = ""
                    
                    // Save credentials
                    saveCredentials(credentials)
                    onComplete(credentials)
                    
                    // Dismiss after short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch OAuthError.cancelled {
                await MainActor.run {
                    isLoggingIn = false
                    statusMessage = ""
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoggingIn = false
                    statusMessage = ""
                }
            }
        }
    }
    
    private func performLogin() async throws -> OAuthCredentials {
        let callbacks = OAuthLoginCallbacks(
            onAuth: { info in
                self.authUrl = info.url
                if let instructions = info.instructions {
                    self.statusMessage = instructions
                }
                
                // Auto-open URL
                if let url = URL(string: info.url) {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #endif
                }
            },
            onPrompt: { prompt in
                if prompt.message.lowercased().contains("authorization code") || 
                   prompt.message.lowercased().contains("paste") {
                    self.showingCodeInput = true
                    return try await withCheckedThrowingContinuation { continuation in
                        self.promptContinuation = continuation
                    }
                } else {
                    self.pendingPrompt = prompt
                    self.promptInput = ""
                    return try await withCheckedThrowingContinuation { continuation in
                        self.promptContinuation = continuation
                    }
                }
            },
            onProgress: { message in
                self.statusMessage = message
            }
        )
        
        switch provider {
        case .anthropic:
            return try await loginAnthropic(callbacks)
        case .githubCopilot:
            return try await loginGitHubCopilot(callbacks)
        case .googleGeminiCli:
            return try await loginGoogleGeminiCli(callbacks)
        case .openAICodex:
            return try await loginOpenAICodex(callbacks)
        case .googleAntigravity:
            return try await loginAntigravity(callbacks)
        }
    }
    
    private func submitCode() {
        let code = codeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        codeInput = ""
        showingCodeInput = false
        promptContinuation?.resume(returning: code)
        promptContinuation = nil
    }
    
    private func submitPrompt() {
        let input = promptInput.trimmingCharacters(in: .whitespacesAndNewlines)
        promptInput = ""
        pendingPrompt = nil
        promptContinuation?.resume(returning: input)
        promptContinuation = nil
    }
    
    private func cancelLogin() {
        promptContinuation?.resume(throwing: OAuthError.cancelled)
        promptContinuation = nil
        isLoggingIn = false
        authUrl = nil
        showingCodeInput = false
        pendingPrompt = nil
    }
    
    private func saveCredentials(_ credentials: OAuthCredentials) {
        // Save the access token as the API key
        do {
            try APIKeyManager.shared.setAPIKey(credentials.access, for: provider.rawValue)
        } catch {
            print("Failed to save credentials: \(error)")
        }
        
        // TODO: Also save refresh token for token refresh
    }
}

#Preview {
    OAuthLoginView(provider: .anthropic) { credentials in
        print("Got credentials: \(credentials)")
    }
}
