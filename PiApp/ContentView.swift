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
        #if os(macOS)
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .navigationTitle("Pi")
        } detail: {
            detailView
        }
        #else
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                detailView(for: tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        #endif
    }
    
    @ViewBuilder
    private var detailView: some View {
        detailView(for: selectedTab)
    }
    
    @ViewBuilder
    private func detailView(for tab: Tab) -> some View {
        switch tab {
        case .chat:
            AgentView()
        case .terminal:
            TerminalView()
        case .settings:
            SettingsView()
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
