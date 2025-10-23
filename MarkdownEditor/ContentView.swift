//
//  ContentView.swift
//  MarkdownEditor
//
//  Created by Dirk Clemens on 20.10.25.
//

import SwiftUI
import os

struct ContentView: View {
    @Binding var document: MarkdownEditorDocument
    @State private var cursorPosition: Int? = nil
    @State private var selectionRange: NSRange? = nil
    @State private var fontSizeInt: Int = 16
    @State private var fontSize: CGFloat = 16
    @State private var selectedTheme: String = "Light"
    @State private var showPreview: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var showTablePicker: Bool = false
    @State private var selectedHeader: Int = 1
    
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
                    MarkdownEditor(text: $document.text, gutterWidth: 50, fontSize: fontSize, separatorWidth: 1.0, theme: theme, onCursorPositionChanged: { pos in
                        DispatchQueue.main.async { cursorPosition = pos }
                    }, onSelectionChanged: { range in
                        DispatchQueue.main.async { selectionRange = range }
                    })
                    .id("\(fontSize) - \(selectedTheme)")
                    .padding()
                }
            }
            .onAppear {
                if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"), themes.keys.contains(savedTheme) {
                    selectedTheme = savedTheme
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
                    Picker("Heading", selection: $selectedHeader) {
                        ForEach(1...6, id: \ .self) { level in
                            Text("H\(level)").tag(level)
                        }
                    }
                    .help("Insert Markdown heading")
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 60)
                    .onChange(of: selectedHeader) { _, newValue in
                        switch newValue {
                        case 1: applyMarkdownFormatting(.header1)
                        case 2: applyMarkdownFormatting(.header2)
                        case 3: applyMarkdownFormatting(.header3)
                        case 4: applyMarkdownFormatting(.header4)
                        case 5: applyMarkdownFormatting(.header5)
                        case 6: applyMarkdownFormatting(.header6)
                        default: break
                        }
                    }
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
                    Button("Link", systemImage: "link") {
                        applyMarkdownFormatting(.link)
                    } .help("Insert link")
                    Button("Image", systemImage: "photo") {
                        applyMarkdownFormatting(.image)
                    } .help("Insert image")
                    Button("Image Picker", systemImage: "photo.on.rectangle") {
                        showImagePicker = true
                    } .help("Insert emoji icon")
                    Button("Table Picker", systemImage: "tablecells") {
                        showTablePicker = true
                    } .help("Insert Markdown table")
                }
                
                ToolbarSpacer(.flexible)

                ToolbarItemGroup() {
                    
                    Button("A-", systemImage: "textformat.size.smaller") {
                        fontSizeInt = max(8, fontSizeInt - 1)
                    }
                    .keyboardShortcut("-", modifiers: [.command])
                    .help("Decrease font size")
                    Button("Aa", systemImage: "textformat.size") {
                        fontSizeInt = 16
                    }
                    .keyboardShortcut("0", modifiers: [.command])
                    .help("Default font size")
                    Button("A+", systemImage: "textformat.size.larger") {
                        fontSizeInt = min(36, fontSizeInt + 1)
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
                    .onChange(of: fontSizeInt) { _, newValue in
                        fontSize = CGFloat(newValue)
                        logger.debug("Font size changed to \(fontSize, format: .fixed(precision: 0))")
                    }
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
                    .onChange(of: selectedTheme) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "selectedTheme")
                        logger.debug("Theme changed to \(newValue)")
                    }
                }
            } // toolbar
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerSheet { emoji in
                let pos = cursorPosition ?? document.text.count
                document.text.insert(contentsOf: emoji, at: document.text.index(document.text.startIndex, offsetBy: pos))
                logger.debug("Inserted emoji/image: \(emoji), at position: \(pos)")
                showImagePicker = false
            }
        }
        .sheet(isPresented: $showTablePicker) {
            TableSelectorSheet { columns, rows in
                let header = (0..<columns).map { "Header\($0+1)" }.joined(separator: " | ")
                let separator = Array(repeating: " :--- ", count: columns).joined(separator: " | ")
                let body = (0..<rows-1).map { _ in Array(repeating: "Cell", count: columns).joined(separator: " | ") }.joined(separator: "\n")
                let markdownTable = "| " + header + " |\n| " + separator + " |\n" + (body.isEmpty ? "" : "| " + body + " |\n")
                let pos = cursorPosition ?? document.text.count
                document.text.insert(contentsOf: markdownTable, at: document.text.index(document.text.startIndex, offsetBy: pos))
                logger.debug("Inserted Markdown table: \(columns)x\(rows) at position: \(pos)")
                showTablePicker = false
            }
        }
    }
}

#Preview {
    ContentView(document: .constant(MarkdownEditorDocument()))
}

extension ContentView {
    
    enum MarkdownFormatting {
        case italic, bold, strikethrough, inlineCode, codeBlock
        case header1, header2, header3, header4, header5, header6
        case unorderedList, orderedList, link, image
        
        var wrapper: String? {
            switch self {
            case .italic: return "*"
            case .bold: return "**"
            case .strikethrough: return "~~"
            case .inlineCode: return "`"
            default: return nil
            }
        }
        
        var prefix: String? {
            switch self {
            case .header1: return "# "
            case .header2: return "## "
            case .header3: return "### "
            case .header4: return "#### "
            case .header5: return "##### "
            case .header6: return "###### "
            case .unorderedList: return "- "
            case .orderedList: return "1. "
            case .codeBlock: return "```"
            default: return nil
            }
        }
    }
    
    private func applyMarkdownFormatting(_ formatting: MarkdownFormatting) {
        let text = document.text
        if let range = selectionRange, range.length > 0 {
            let nsText = text as NSString
            let selected = nsText.substring(with: range)
            var replacement = selected
            if let wrapper = formatting.wrapper {
                replacement = wrapper + selected + wrapper
            } else if let prefix = formatting.prefix {
                replacement = prefix + selected
            } else if formatting == .link {
                replacement = "[link text: " + selected + "](" + selected + ")"
            } else if formatting == .image {
                replacement = "![alt text: " + selected + "](" + selected + ")"
            }
            let newText = nsText.replacingCharacters(in: range, with: replacement)
            document.text = newText
        } else {
            let pos = cursorPosition ?? text.count
            var newText = text
            if let wrapper = formatting.wrapper {
                let placeholder = "text"
                let formatted = wrapper + placeholder + wrapper
                newText.insert(contentsOf: formatted, at: newText.index(newText.startIndex, offsetBy: pos))
            } else if let prefix = formatting.prefix {
                let line = prefix + "text"
                newText.insert(contentsOf: line, at: newText.index(newText.startIndex, offsetBy: pos))
            } else if formatting == .link {
                let link = "[link text](https://example.com)"
                newText.insert(contentsOf: link, at: newText.index(newText.startIndex, offsetBy: pos))
            } else if formatting == .image {
                let image = "![alt text](./logo.png)"
                newText.insert(contentsOf: image, at: newText.index(newText.startIndex, offsetBy: pos))
            }
            document.text = newText
        }
    }
}
