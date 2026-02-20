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
        #if os(macOS)
        case terminal = "Terminal"
        #else
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
        #if os(macOS)
        case .terminal:
            TerminalView()
        #else
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
        #if os(macOS)
        case .terminal:
            return "terminal"
        #else
        case .settings:
            return "gear"
        #endif
        }
    }
}

#Preview {
    ContentView()
}
