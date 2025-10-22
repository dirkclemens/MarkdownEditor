import SwiftUI
import os

struct ContentView: View {
    @Binding var document: MarkdownEditorDocument
    @State private var cursorPosition: Int? = nil
    @State private var selectionRange: NSRange? = nil
    @State private var fontSizeInt: Int = 16
    @State private var fontSize: CGFloat = 16
    @State private var selectedTheme: String = "Light"
    
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
                MarkdownEditor(text: $document.text, gutterWidth: 50, fontSize: fontSize, separatorWidth: 1.0, theme: theme, onCursorPositionChanged: { pos in
                    DispatchQueue.main.async { cursorPosition = pos }
                }, onSelectionChanged: { range in
                    DispatchQueue.main.async { selectionRange = range }
                })
                .id("\(fontSize) - \(selectedTheme)")
                .padding()
            }
            .onAppear {
                if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"), themes.keys.contains(savedTheme) {
                    selectedTheme = savedTheme
                }
            }
            .toolbar {
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
                }
                
                ToolbarItemGroup() {
                    Button("H1") {
                        applyMarkdownFormatting(.header1)
                    }
                    Button("H2") {
                        applyMarkdownFormatting(.header2)
                    }
                    Button("H3") {
                        applyMarkdownFormatting(.header3)
                    }
                    Button("H4") {
                        applyMarkdownFormatting(.header4)
                    }
                    Button("H5") {
                        applyMarkdownFormatting(.header5)
                    }
                }
                
                ToolbarItemGroup() {
                    Button("Code", systemImage: "chevron.left.forwardslash.chevron.right") {
                        applyMarkdownFormatting(.inlineCode)
                    }
                    Button("Block", systemImage: "curlybraces") {
                        applyMarkdownFormatting(.codeBlock)
                    }
                    Button("List", systemImage: "list.bullet") {
                        applyMarkdownFormatting(.unorderedList)
                    }
                    Button("Numbers", systemImage: "list.number") {
                        applyMarkdownFormatting(.orderedList)
                    }
                    Button("Link", systemImage: "link") {
                        applyMarkdownFormatting(.link)
                    }
                    Button("Image", systemImage: "photo") {
                        applyMarkdownFormatting(.image)
                    }
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
                        ForEach(Array(themes.keys), id: \ .self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 120)
                    .onChange(of: selectedTheme) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "selectedTheme")
                        logger.debug("Theme changed to \(newValue)")
                    }
                }
                
            } // toolbar
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
