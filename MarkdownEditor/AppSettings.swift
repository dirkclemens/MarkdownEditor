//
//  AppSettings.swift
//  MarkdownEditor
//
//  Schlüssel und Standardwerte der Einstellungen (UserDefaults).
//

import AppKit

enum SettingsKey {
    static let fontSize = "FontSize"
    static let theme = "selectedTheme"
    static let startViewMode = "StartViewMode"
    static let lastViewMode = "LastViewMode"
    static let showLineNumbers = "ShowLineNumbers"
    static let spellChecking = "ContinuousSpellChecking"
    static let autocorrection = "AutomaticSpellingCorrection"
    static let smartQuotes = "SmartQuotes"
    static let textReplacement = "TextReplacement"
    /// Systemschlüssel von AppKit: Fenster beim Beenden behalten und beim nächsten Start
    /// wiederherstellen. Ohne eigenen Wert gilt die Systemeinstellung
    /// „Fenster beim Beenden einer App schließen“.
    static let reopenWindows = "NSQuitAlwaysKeepsWindows"
    static let quitWhenLastDocumentClosed = "QuitWhenLastDocumentClosed"

    static let defaultFontSize = 16

    private static let migratedSandboxPreferences = "MigratedSandboxPreferences"

    /// Bis Version 1.2 lief die App in der Sandbox; ihre Einstellungen liegen noch im
    /// Container. Einmalig übernehmen, ohne inzwischen gesetzte Werte zu überschreiben.
    static func migrateSandboxPreferences() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migratedSandboxPreferences),
              let bundleID = Bundle.main.bundleIdentifier
        else { return }
        // Vorher setzen: Verweigert macOS den Zugriff auf den Container, nicht erneut fragen.
        defaults.set(true, forKey: migratedSandboxPreferences)
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Containers/\(bundleID)/Data/Library/Preferences/\(bundleID).plist")
        guard let old = NSDictionary(contentsOf: url) as? [String: Any] else { return }
        let current = defaults.persistentDomain(forName: bundleID) ?? [:]
        for (key, value) in old where current[key] == nil {
            defaults.set(value, forKey: key)
        }
    }

    /// Standardwerte registrieren; die Schreibhilfen folgen anfangs den Systemeinstellungen.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            fontSize: defaultFontSize,
            theme: "Light",
            startViewMode: StartViewMode.lastUsed.rawValue,
            showLineNumbers: true,
            quitWhenLastDocumentClosed: true,
            spellChecking: false,
            autocorrection: NSSpellChecker.isAutomaticSpellingCorrectionEnabled,
            smartQuotes: NSSpellChecker.isAutomaticQuoteSubstitutionEnabled,
            textReplacement: NSSpellChecker.isAutomaticTextReplacementEnabled
        ])
    }
}

/// Ansicht, in der neue Fenster geöffnet werden.
enum StartViewMode: String, CaseIterable, Identifiable {
    case lastUsed, editor, split, preview

    var id: Self { self }

    var title: String {
        switch self {
        case .lastUsed: "Last Used View"
        case .editor: ViewMode.editor.title
        case .split: ViewMode.split.title
        case .preview: ViewMode.preview.title
        }
    }

    var viewMode: ViewMode {
        switch self {
        case .lastUsed: ViewMode.lastUsed
        case .editor: .editor
        case .split: .split
        case .preview: .preview
        }
    }
}
