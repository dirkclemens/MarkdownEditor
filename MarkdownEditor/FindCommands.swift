//
//  FindCommands.swift
//  MarkdownEditor
//

import SwiftUI
import AppKit

/// Menü Bearbeiten › Suchen. Die Befehle gehen an den Editor oder an die Vorschau des
/// aktiven Fensters. (SwiftUIs `TextEditingCommands` funktionieren nur mit SwiftUI-
/// Textfeldern und bleiben für eine NSTextView ausgegraut.)
struct FindCommands: Commands {
    @FocusedValue(\.findController) private var findController

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Menu("Find") {
                item("Find…", .showFindInterface, "f", .command)
                item("Find and Replace…", .showReplaceInterface, "f", [.command, .option])
                item("Find Next", .nextMatch, "g", .command)
                item("Find Previous", .previousMatch, "g", [.command, .shift])
                item("Use Selection for Find", .setSearchString, "e", .command)
            }
        }
    }

    private func item(_ title: String, _ action: NSTextFinder.Action,
                      _ key: KeyEquivalent, _ modifiers: EventModifiers) -> some View {
        Button(title) { findController?.perform(action) }
            .keyboardShortcut(key, modifiers: modifiers)
            .disabled(findController == nil)
    }
}

extension FocusedValues {
    @Entry var findController: FindController?
}

/// Verteilt die Suchbefehle eines Fensters auf Editor und Vorschau.
@MainActor
final class FindController {
    weak var editor: NSTextView?
    let preview = PreviewFinder()

    func perform(_ action: NSTextFinder.Action) {
        let editor = self.editor.flatMap { $0.window != nil ? $0 : nil }
        let webView = preview.webView.flatMap { $0.window != nil ? $0 : nil }
        let firstResponder = (editor?.window ?? webView?.window)?.firstResponder as? NSView

        let previewFocused = webView.map { webView in
            preview.isFieldFocused || firstResponder?.isDescendant(of: webView) == true
        } ?? false
        // Die Vorschau ist schreibgeschützt: Ersetzen geht immer an den Editor, falls sichtbar.
        let replaces: [NSTextFinder.Action] = [.showReplaceInterface, .replace, .replaceAll,
                                               .replaceAndFind, .replaceAllInSelection]

        if let editor, replaces.contains(action) || !previewFocused {
            // Fokus nur holen, wenn er nicht schon im Editor oder dessen Suchleiste liegt.
            let container = editor.enclosingScrollView ?? editor
            if firstResponder?.isDescendant(of: container) != true {
                editor.window?.makeFirstResponder(editor)
            }
            // NSTextView liest die Aktion aus dem `tag` des Absenders.
            let sender = NSMenuItem()
            sender.tag = action.rawValue
            editor.performTextFinderAction(sender)
        } else if webView != nil {
            preview.perform(action)
        }
    }
}
