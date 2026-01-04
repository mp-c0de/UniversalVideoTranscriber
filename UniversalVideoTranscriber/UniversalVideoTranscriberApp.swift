//
//  UniversalVideoTranscriberApp.swift
//  UniversalVideoTranscriber
//
//  Main application entry point
//

import SwiftUI

@main
struct UniversalVideoTranscriberApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
