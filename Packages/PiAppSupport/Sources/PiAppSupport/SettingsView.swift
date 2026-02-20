import SwiftUI
import PiSwiftAI

public struct SettingsView: View {
    @State private var anthropicKey: String = ""
    @State private var selectedKeyType: KeyType = .apiKey
    @State private var showingSaveConfirmation = false
    @State private var showingOAuthLogin = false
    @State private var selectedOAuthProvider: OAuthProvider = .anthropic
    @State private var refreshTrigger = false

    public init() {
        if let existingKey = APIKeyManager.shared.getAPIKey(for: "anthropic") {
            if existingKey.contains("sk-ant-oat") {
                _selectedKeyType = State(initialValue: .oauth)
            } else {
                _selectedKeyType = State(initialValue: .apiKey)
            }
        }
    }

    public var body: some View {
        Form {
            Section {
                Picker("Key Type", selection: $selectedKeyType) {
                    Text("API Key").tag(KeyType.apiKey)
                    Text("OAuth Token").tag(KeyType.oauth)
                }

                if selectedKeyType == .apiKey {
                    SecureField("sk-ant-api03-...", text: $anthropicKey)

                    Link(destination: URL(string: "https://platform.claude.com/settings/keys")!) {
                        Label("Get an API key from Anthropic", systemImage: "arrow.up.right.square")
                    }
                } else {
                    SecureField("sk-ant-oat-...", text: $anthropicKey)
                    
                    Button {
                        selectedOAuthProvider = .anthropic
                        showingOAuthLogin = true
                    } label: {
                        Label("Login with Claude Pro/Max", systemImage: "person.badge.key")
                    }
                }

                HStack {
                    Button("Save API Key") {
                        saveKey(for: "anthropic")
                    }
                    .disabled(anthropicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if hasExistingKey(for: "anthropic") {
                        Button("Delete", role: .destructive) {
                            deleteKey(for: "anthropic")
                        }
                    }

                    Spacer()

                    if hasExistingKey(for: "anthropic") {
                        Label("Key saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Anthropic")
            } footer: {
                if showingSaveConfirmation {
                    Text("Key saved successfully!")
                        .foregroundStyle(.green)
                }
            }
            
            Section {
                ForEach(getOAuthProviders().filter { $0.available }, id: \.id) { provider in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(provider.name)
                                .font(.body)
                            
                            if hasExistingKey(for: provider.id.rawValue) {
                                Text("Logged in")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        
                        Spacer()
                        
                        if hasExistingKey(for: provider.id.rawValue) {
                            Button("Logout", role: .destructive) {
                                deleteKey(for: provider.id.rawValue)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Login") {
                                selectedOAuthProvider = provider.id
                                showingOAuthLogin = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            } header: {
                Text("OAuth Providers")
            } footer: {
                Text("Login with your existing subscriptions (Claude Pro/Max, GitHub Copilot, ChatGPT Plus/Pro, etc.)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showingOAuthLogin) {
            OAuthLoginView(provider: selectedOAuthProvider) { credentials in
                // Credentials are saved by OAuthLoginView
            }
        }
    }

    private func hasExistingKey(for provider: String) -> Bool {
        // Use refreshTrigger to force re-evaluation
        _ = refreshTrigger
        return APIKeyManager.shared.hasAPIKey(for: provider)
    }

    private func saveKey(for provider: String) {
        let key = anthropicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            return
        }

        do {
            try APIKeyManager.shared.setAPIKey(key, for: provider)
            anthropicKey = ""
            showingSaveConfirmation = true
            refreshTrigger.toggle()

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showingSaveConfirmation = false
            }
        } catch {
            // Handle error
        }
    }

    private func deleteKey(for provider: String) {
        do {
            try APIKeyManager.shared.deleteAPIKey(for: provider)
            anthropicKey = ""
            refreshTrigger.toggle()
        } catch {
            // Handle error
        }
    }
}

#Preview {
    SettingsView()
}
