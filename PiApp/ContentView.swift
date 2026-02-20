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
        case files = "Files"
        case terminal = "Terminal"
        #if !os(macOS)
        case settings = "Settings"
        #endif
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
        case .files:
            FileBrowserView()
        case .terminal:
            TerminalView()
        #if !os(macOS)
        case .settings:
            SettingsView()
        #endif
        }
    }
}

extension ContentView.Tab {
    var icon: String {
        switch self {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .files:
            return "folder"
        case .terminal:
            return "terminal"
        #if !os(macOS)
        case .settings:
            return "gear"
        #endif
        }
    }
}

#Preview {
    ContentView()
}
