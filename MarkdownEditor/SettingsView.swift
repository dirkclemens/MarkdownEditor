//
//  SettingsView.swift
//  MarkdownEditor
//
//  Einstellungen (⌘,): Allgemein und Editor.
//

import SwiftUI
import MarkdownEditorKit

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }
            Tab("Editor", systemImage: "character.cursor.ibeam") {
                EditorSettingsView()
            }
        }
        .frame(width: 480)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(SettingsKey.reopenWindows) private var reopenWindows = false
    @AppStorage(SettingsKey.quitWhenLastDocumentClosed) private var quitWhenLastDocumentClosed = true
    @AppStorage(SettingsKey.startViewMode) private var startViewMode: StartViewMode = .lastUsed

    var body: some View {
        Form {
            Section {
                Toggle("Reopen windows when the app starts", isOn: $reopenWindows)
                Toggle("Quit when the last document is closed", isOn: $quitWhenLastDocumentClosed)
            } header: {
                Text("Windows")
            } footer: {
                Text("Documents that are open when you quit Markdown Editor are reopened at the next launch, each in its previous view. Closing Settings or About never quits the app.")
                    .settingsFooter()
            }

            Section {
                Picker("Open new windows in", selection: $startViewMode) {
                    Text(StartViewMode.lastUsed.title).tag(StartViewMode.lastUsed)
                    Divider()
                    ForEach([StartViewMode.editor, .split, .preview]) { mode in
                        Label(mode.title, systemImage: mode.viewMode.systemImage).tag(mode)
                    }
                }
            } header: {
                Text("View")
            } footer: {
                Text("“Last Used View” opens new windows in the view you chose most recently.")
                    .settingsFooter()
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct EditorSettingsView: View {
    @AppStorage(SettingsKey.theme) private var theme = "Light"
    @AppStorage(SettingsKey.fontSize) private var fontSize = SettingsKey.defaultFontSize
    @AppStorage(SettingsKey.showLineNumbers) private var showLineNumbers = true
    @AppStorage(SettingsKey.spellChecking) private var spellChecking = false
    @AppStorage(SettingsKey.autocorrection) private var autocorrection = false
    @AppStorage(SettingsKey.smartQuotes) private var smartQuotes = false
    @AppStorage(SettingsKey.textReplacement) private var textReplacement = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $theme) {
                    ForEach(MarkdownEditorTheme.builtInThemes.keys.sorted(), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                Picker("Font size", selection: $fontSize) {
                    ForEach(Array(stride(from: 8, through: 36, by: 2)), id: \.self) { size in
                        Text("\(size) pt").tag(size)
                    }
                }
                Toggle("Show line numbers", isOn: $showLineNumbers)
            }

            Section {
                Toggle("Check spelling while typing", isOn: $spellChecking)
                Toggle("Correct spelling automatically", isOn: $autocorrection)
                Toggle("Use smart quotes", isOn: $smartQuotes)
                Toggle("Use text replacements", isOn: $textReplacement)
            } header: {
                Text("Typing")
            } footer: {
                Text("Corrections, smart quotes and text replacements are never applied inside code blocks or inline code.")
                    .settingsFooter()
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private extension Text {
    func settingsFooter() -> some View {
        font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    SettingsView()
}
