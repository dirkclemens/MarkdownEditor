//
//  ContentView.swift
//  MarkdownEditor
//
//  Created by Dirk Clemens on 20.10.25.
//

import SwiftUI
import AppKit
import os

struct ContentView: View {
    @Binding var document: MarkdownEditorDocument
    @State private var showPreview: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var showTablePicker: Bool = false
    @State private var editorTextView: NSTextView?

    @AppStorage("FontSize") private var fontSizeInt: Int = 16
    @AppStorage("selectedTheme") private var selectedTheme: String = "Light"
    
    var logger = Logger(subsystem: "de.adcore.Markdown", category: "ContentView")
    
    let themes: [String: MarkdownEditorTheme] = [
        "Dark": darkTheme,
        "Dracula": draculaTheme,
        "Gruvbox Dark": gruvboxDarkTheme,
        "Light": lightTheme,
        "Monokai": monokaiDarkTheme,
        "Nord": nordTheme,
        "One Dark": oneDarkTheme,
        "Pastel": pastelTheme,
        "Solarized Dark": solarizedDarkTheme,
        "Solarized Light": solarizedLightTheme,
        "Tomorrow Night": tomorrowNightTheme
    ]
    
    var theme: MarkdownEditorTheme {
        themes[selectedTheme] ?? lightTheme
    }
    
    var body: some View {
        NavigationStack {
            HStack(){
                if showPreview {
                    MarkdownRenderer(markdown: document.text)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MarkdownEditor(text: $document.text, gutterWidth: 50, fontSize: CGFloat(fontSizeInt), separatorWidth: 1.0, theme: theme, onTextViewReady: { textView in
                        DispatchQueue.main.async { editorTextView = textView }
                    })
                }
            }
            .toolbar {
                ToolbarItemGroup() {
                    Button(showPreview ? "Edit" : "Preview", systemImage: showPreview ? "pencil" : "eye") {
                        showPreview.toggle()
                    }
                    .help(showPreview ? "Switch to editor" : "Show Markdown preview")
                }
                
                ToolbarSpacer(.flexible)

                ToolbarItemGroup() {
                    Button("Undo", systemImage: "arrow.uturn.backward") {
                        NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                    }
                    .help("Undo last action")
                    Button("Redo", systemImage: "arrow.uturn.forward") {
                        NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                    }
                    .help("Redo last action")
                }
                
                ToolbarSpacer(.flexible)
                
                ToolbarItemGroup() {
                    Button("italic", systemImage: "italic") {
                        applyMarkdownFormatting(.italic)
                    }
                    .keyboardShortcut("i", modifiers: [.command])
                    .help("Make text italic (⌘I)")
                    
                    Button("bold", systemImage: "bold") {
                        applyMarkdownFormatting(.bold)
                    }
                    .keyboardShortcut("b", modifiers: [.command])
                    .help("Make text bold (⌘B)")
                    
                    Button("Strike", systemImage: "strikethrough") {
                        applyMarkdownFormatting(.strikethrough)
                    }
                    .help("Strikethrough text")
                }
                
                ToolbarItemGroup() {
                    Menu {
                        ForEach(1...6, id: \.self) { level in
                            Button("H\(level)") {
                                applyMarkdownFormatting(.heading(level))
                            }
                        }
                    } label: {
                        Label("Heading", systemImage: "number")
                    }
                    .help("Insert Markdown heading")
                    Button("Code", systemImage: "chevron.left.forwardslash.chevron.right") {
                        applyMarkdownFormatting(.inlineCode)
                    } .help("Inline code")
                    Button("Block", systemImage: "curlybraces") {
                        applyMarkdownFormatting(.codeBlock)
                    } .help("Code block")
                    Button("List", systemImage: "list.bullet") {
                        applyMarkdownFormatting(.unorderedList)
                    } .help("Unordered list")
                    Button("Numbers", systemImage: "list.number") {
                        applyMarkdownFormatting(.orderedList)
                    } .help("Ordered list")
                    Button("Checklist", systemImage: "checklist") {
                        applyMarkdownFormatting(.checkList)
                    } .help("Checklist")                    
                    Button("Link", systemImage: "link") {
                        applyMarkdownFormatting(.link)
                    } .help("Insert link")
                    Button("Image", systemImage: "photo") {
                        applyMarkdownFormatting(.image)
                    } .help("Insert image")
                    Button("Image Picker", systemImage: "face.smiling") {
                        showImagePicker = true
                    } .help("Insert emoji icon")
                    Button("Table Picker", systemImage: "tablecells") {
                        showTablePicker = true
                    } .help("Insert Markdown table")
                }
                
                ToolbarSpacer(.flexible)

                ToolbarItemGroup() {
                    
                    Button("A-", systemImage: "textformat.size.smaller") {
                        fontSizeInt = max(8, fontSizeInt - 2)
                    }
                    .keyboardShortcut("-", modifiers: [.command])
                    .help("Decrease font size")
                    Button("Aa", systemImage: "textformat.size") {
                        fontSizeInt = 16
                    }
                    .keyboardShortcut("0", modifiers: [.command])
                    .help("Default font size")
                    Button("A+", systemImage: "textformat.size.larger") {
                        fontSizeInt = min(36, fontSizeInt + 2)
                    }
                    .keyboardShortcut("+", modifiers: [.command])
                    .help("Increase font size")
                    Picker("Font Size", selection: $fontSizeInt) {
                        ForEach(Array(stride(from: 8, through: 36, by: 2)), id: \.self) { size in
                            Text("\(size) pt").tag(size)
                                .foregroundColor(size == fontSizeInt ? .accentColor : .primary)
                        }
                    }
                    .help("Select font size")
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 60)
                }
                
                ToolbarSpacer(.flexible)

                ToolbarItemGroup() {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(Array(themes.keys).sorted(), id: \ .self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .help("Select editor theme")
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 120)
                }
            } // toolbar
        }
        .background(WindowFrameSaver(windowKey: "MarkdownEditorMainWindow"))
        .sheet(isPresented: $showImagePicker) {
            ImagePickerSheet { emoji in
                insertAtCursor(emoji)
                showImagePicker = false
            }
        }
        .sheet(isPresented: $showTablePicker) {
            TableSelectorSheet { columns, rows in
                let header = (0..<columns).map { "Header\($0+1)" }.joined(separator: " | ")
                let separator = Array(repeating: " :--- ", count: columns).joined(separator: " | ")
                let body = (0..<rows-1).map { _ in "| " + Array(repeating: "Cell", count: columns).joined(separator: " | ") + " |" }.joined(separator: "\n")
                let markdownTable = "| " + header + " |\n| " + separator + " |\n" + (body.isEmpty ? "" : body + "\n")
                insertAtCursor(markdownTable)
                logger.debug("Inserted Markdown table: \(columns)x\(rows)")
                showTablePicker = false
            }
        }
    }
}

#Preview {
    ContentView(document: .constant(MarkdownEditorDocument()))
}

private struct WindowFrameSaver: NSViewRepresentable {
    let windowKey: String
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            if !window.setFrameAutosaveName(windowKey) {
                window.setFrameAutosaveName(windowKey)
            }
            window.setFrameUsingName(windowKey)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            guard let window = nsView?.window else { return }
            if !window.setFrameAutosaveName(windowKey) {
                window.setFrameAutosaveName(windowKey)
            }
        }
    }
}

extension ContentView {

    enum MarkdownFormatting: Equatable {
        case italic, bold, strikethrough, inlineCode, codeBlock
        case heading(Int)
        case unorderedList, orderedList, checkList, link, image

        var wrapper: String? {
            switch self {
            case .italic: return "*"
            case .bold: return "**"
            case .strikethrough: return "~~"
            case .inlineCode: return "`"
            default: return nil
            }
        }
    }

    /// Die Text View des Editors, sofern sie gerade in einem Fenster angezeigt wird.
    private var activeTextView: NSTextView? {
        guard let editorTextView, editorTextView.window != nil else { return nil }
        return editorTextView
    }

    private func insertAtCursor(_ string: String) {
        guard let textView = activeTextView else { return }
        let range = textView.selectedRange()
        replace(range, with: string, in: textView,
                select: NSRange(location: range.location + (string as NSString).length, length: 0))
    }

    private func applyMarkdownFormatting(_ formatting: MarkdownFormatting) {
        guard let textView = activeTextView else { return }
        applyFormatting(using: textView, formatting: formatting)
    }

    private func applyFormatting(using textView: NSTextView, formatting: MarkdownFormatting) {
        switch formatting {
        case .italic, .bold, .strikethrough, .inlineCode:
            toggleWrapper(formatting.wrapper ?? "", in: textView)
        case .heading, .unorderedList, .orderedList, .checkList:
            prefixLines(formatting, in: textView)
        case .codeBlock:
            insertCodeBlock(in: textView)
        case .link:
            insertLink(image: false, in: textView)
        case .image:
            insertLink(image: true, in: textView)
        }
    }

    /// Ersetzt einen Bereich als eigenen Undo-Schritt und setzt danach die Auswahl.
    private func replace(_ range: NSRange, with string: String, in textView: NSTextView, select selection: NSRange) {
        textView.breakUndoCoalescing()
        guard textView.shouldChangeText(in: range, replacementString: string) else { return }
        textView.textStorage?.replaceCharacters(in: range, with: string)
        textView.didChangeText()
        textView.setSelectedRange(selection)
        textView.scrollRangeToVisible(selection)
    }

    // MARK: Fett, kursiv, durchgestrichen, Inline-Code

    /// Fügt das Wrapper-Paar hinzu oder entfernt es, wenn die Auswahl bereits davon umschlossen ist.
    private func toggleWrapper(_ wrapper: String, in textView: NSTextView) {
        let text = textView.string as NSString
        let selection = textView.selectedRange()
        let width = (wrapper as NSString).length
        guard width > 0 else { return }
        let marker = (wrapper as NSString).character(at: 0)
        let asterisk: unichar = 0x2A

        func run(from start: Int, step: Int, limit: Int) -> Int {
            var count = 0
            var i = start
            while (step > 0 ? i < limit : i >= limit), text.character(at: i) == marker {
                count += 1
                i += step
            }
            return count
        }
        // *** ist fett und kursiv zugleich: passt sowohl zu * als auch zu **.
        func isWrapper(_ count: Int) -> Bool {
            marker == asterisk ? (count == width || count == 3) : count >= width
        }

        // Wrapper innerhalb der Auswahl: **wort** markiert
        if selection.length > 2 * width {
            let leading = run(from: selection.location, step: 1, limit: NSMaxRange(selection))
            let trailing = run(from: NSMaxRange(selection) - 1, step: -1, limit: selection.location)
            if leading < selection.length, isWrapper(leading), isWrapper(trailing) {
                let inner = NSRange(location: selection.location + width, length: selection.length - 2 * width)
                replace(selection, with: text.substring(with: inner), in: textView,
                        select: NSRange(location: selection.location, length: inner.length))
                return
            }
        }

        // Wrapper direkt außerhalb der Auswahl: wort markiert in **wort**
        let before = run(from: selection.location - 1, step: -1, limit: 0)
        let after = run(from: NSMaxRange(selection), step: 1, limit: text.length)
        if isWrapper(before), isWrapper(after) {
            let outer = NSRange(location: selection.location - width, length: selection.length + 2 * width)
            replace(outer, with: text.substring(with: selection), in: textView,
                    select: NSRange(location: outer.location, length: selection.length))
            return
        }

        // Hinzufügen; ohne Auswahl steht der Cursor danach zwischen den Zeichen.
        let selected = text.substring(with: selection)
        replace(selection, with: wrapper + selected + wrapper, in: textView,
                select: NSRange(location: selection.location + width, length: selection.length))
    }

    // MARK: Überschriften und Listen

    /// Setzt das Präfix an den Anfang jeder ausgewählten Zeile (ein Undo-Schritt).
    private func prefixLines(_ formatting: MarkdownFormatting, in textView: NSTextView) {
        let text = textView.string as NSString
        let selection = textView.selectedRange()
        let lineRange = text.lineRange(for: selection)
        let block = text.substring(with: lineRange)

        var lines = block.components(separatedBy: "\n")
        let hasTrailingNewline = block.hasSuffix("\n")
        if hasTrailingNewline { lines.removeLast() }
        let singleLine = lines.count <= 1

        var number = 1
        let transformed = lines.map { line -> String in
            if !singleLine, line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return line
            }
            switch formatting {
            case .heading(let level):
                let content = LinePattern.remove(LinePattern.heading, from: line)
                return String(repeating: "#", count: level) + " " + content
            case .unorderedList, .orderedList, .checkList:
                let indent = String(line.prefix { $0 == " " || $0 == "\t" })
                let content = LinePattern.remove(LinePattern.listMarker, from: String(line.dropFirst(indent.count)))
                let marker: String
                switch formatting {
                case .orderedList:
                    marker = "\(number). "
                    number += 1
                case .checkList:
                    marker = "- [ ] "
                default:
                    marker = "- "
                }
                return indent + marker + content
            default:
                return line
            }
        }

        let replacement = transformed.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")
        let newSelection: NSRange
        if singleLine {
            // Cursor ans Ende der bearbeiteten Zeile
            newSelection = NSRange(location: lineRange.location + ((transformed.first ?? "") as NSString).length, length: 0)
        } else {
            let length = (replacement as NSString).length - (hasTrailingNewline ? 1 : 0)
            newSelection = NSRange(location: lineRange.location, length: length)
        }
        replace(lineRange, with: replacement, in: textView, select: newSelection)
    }

    // MARK: Codeblock

    private func insertCodeBlock(in textView: NSTextView) {
        let text = textView.string as NSString
        let selection = textView.selectedRange()
        let end = NSMaxRange(selection)
        let atLineStart = selection.location == 0 || text.character(at: selection.location - 1) == 0x0A
        let atLineEnd = end == text.length || text.character(at: end) == 0x0A

        var content = text.substring(with: selection)
        var trailing = atLineEnd ? "" : "\n"
        if content.hasSuffix("\n") {
            content.removeLast()
            trailing = "\n"
        }
        let opening = (atLineStart ? "" : "\n") + "```\n"
        let replacement = opening + content + "\n```" + trailing

        // Mit Auswahl bleibt der Inhalt markiert, ohne Auswahl steht der Cursor in der leeren Zeile.
        let contentStart = selection.location + (opening as NSString).length
        replace(selection, with: replacement, in: textView,
                select: NSRange(location: contentStart, length: (content as NSString).length))
    }

    // MARK: Link und Bild

    private func insertLink(image: Bool, in textView: NSTextView) {
        let text = textView.string as NSString
        let selection = textView.selectedRange()
        let prefix = image ? "![" : "["
        let prefixLength = (prefix as NSString).length

        if selection.length > 0 {
            // [Auswahl](url) – danach ist "url" markiert
            let label = text.substring(with: selection)
            let replacement = prefix + label + "](url)"
            let urlLocation = selection.location + prefixLength + (label as NSString).length + 2
            replace(selection, with: replacement, in: textView,
                    select: NSRange(location: urlLocation, length: 3))
        } else {
            // Ohne Auswahl: Platzhalter einfügen, der Text in den eckigen Klammern ist markiert
            let label = image ? "alt text" : "link text"
            let target = image ? "./logo.png" : "https://example.com"
            let replacement = prefix + label + "](" + target + ")"
            replace(selection, with: replacement, in: textView,
                    select: NSRange(location: selection.location + prefixLength, length: (label as NSString).length))
        }
    }
}

/// Muster für vorhandene Zeilen-Präfixe, die beim Formatieren ersetzt werden.
private enum LinePattern {
    static let heading = try! NSRegularExpression(pattern: #"^#{1,6}(?:[ \t]+|$)"#)
    static let listMarker = try! NSRegularExpression(pattern: #"^(?:[-*+]|\d{1,9}[.)])[ \t]+(?:\[[ xX]\][ \t]+)?"#)

    static func remove(_ pattern: NSRegularExpression, from line: String) -> String {
        let range = NSRange(location: 0, length: (line as NSString).length)
        return pattern.stringByReplacingMatches(in: line, range: range, withTemplate: "")
    }
}
