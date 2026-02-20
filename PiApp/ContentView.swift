//
//  ContentView.swift
//  PiApp
//
//  Created by Jonathan Wight on 2/20/26.
//

import SwiftUI
import PiAppSupport

struct ContentView: View {
    @State private var selectedTab: Tab = .chat

    enum Tab: String, CaseIterable {
        case chat = "Chat"
        case terminal = "Terminal"
        case settings = "Settings"
    }

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("Pi")
        } detail: {
            switch selectedTab {
            case .chat:
                AgentView()
            case .terminal:
                TerminalView()
            case .settings:
                SettingsView()
            }
        }
    }
}

extension ContentView.Tab {
    var icon: String {
        switch self {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .terminal:
            return "terminal"
        case .settings:
            return "gear"
        }
    }
}

#Preview {
    ContentView()
}
