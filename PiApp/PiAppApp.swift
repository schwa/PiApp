//
//  PiAppApp.swift
//  PiApp
//
//  Created by Jonathan Wight on 2/20/26.
//

import SwiftUI
import PiAppSupport

@main
struct PiAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
