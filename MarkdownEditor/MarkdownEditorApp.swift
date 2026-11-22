//
//  MarkdownEditorApp.swift
//  MarkdownEditor
//
//  Created by Dirk Clemens on 20.10.25.
//

import SwiftUI

@main
struct MarkdownEditorApp: App {
    init() {
        SettingsKey.migrateSandboxPreferences()
        SettingsKey.registerDefaults()
    }

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownEditorDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .commands {
            // Bearbeiten › Suchen: Suchen, Suchen und Ersetzen, Weitersuchen, Auswahl suchen
            FindCommands()
            AboutCommands()
        }

        Settings {
            SettingsView()
        }

        Window("About Markdown Editor", id: AboutView.windowID) {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
        .commandsRemoved()
    }
}
