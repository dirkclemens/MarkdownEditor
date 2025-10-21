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

    var logger = Logger(subsystem: "de.adcore.Markdown", category: "ContentView")
    
    var body: some View {
        NavigationStack {
            HStack(){
                MarkdownEditor(text: $document.text, gutterWidth: 30, fontSize: 16)
                    .padding()
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
                }
                
                ToolbarSpacer(.flexible)

                ToolbarItemGroup() {
                    
                    Button("A-", systemImage: "textformat.size.smaller") {
//                        fontSizeManager.decreaseFontSize()
                    }
                    .keyboardShortcut("-", modifiers: [.command])
                    .help("Decrease font size")

                    Button("Aa", systemImage: "textformat.size") {
//                        fontSizeManager.setFontSize(14) // Reset to default font size
                    }
                    .keyboardShortcut("0", modifiers: [.command])
                    .help("Default font size")

                    Button("A+", systemImage: "textformat.size.larger") {
//                        fontSizeManager.increaseFontSize()
                    }
                    .keyboardShortcut("+", modifiers: [.command])
                    .help("Increase font size")

//                    Slider(value: $fontSizeManager.fontSize, in: 8...72) {
//                        Text("Font Size")
//                    }.frame(width: 100)
                }

//                ToolbarSpacer()

//                ToolbarItemGroup() {
//
//                    Toggle(.showEditor, systemImage: "square.and.pencil", isOn: $showEditor)
//                        .keyboardShortcut("e", modifiers: .command)
//                        .disabled(!showPreview)
//                        .help("Show/hide editor (⌘E)")
//
//                    Toggle(.showPreview, systemImage: "square.text.square", isOn: $showPreview)
//                        .keyboardShortcut("r", modifiers: .command)
//                        .disabled(!showEditor)
//                        .help("Show/hide preview (⌘R)")
//
//                    // Theme toggle
//                    Button(action: {
//                        useDarkTheme.toggle()
//                    }) {
//                        Image(systemName: useDarkTheme ? "sun.max" : "moon")
//                    }
//                    .help("Toggle theme")
//                }
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
        case unorderedList, orderedList, link
        
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
        // Store the current text to ensure we can detect changes
        let originalText = document.text
        
        logger.debug("Applying formatting: \(document.text.count) characters before formatting - formatting: \(formatting.hashValue)")
        
        if let wrapper = formatting.wrapper {
            let placeholder = "text"
            let formatted = wrapper + placeholder + wrapper
            document.text += formatted
        } else if let prefix = formatting.prefix {
            if formatting == .codeBlock {
                document.text += "\n```\ncode\n```\n"
            } else {
                document.text += "\n" + prefix + "text"
            }
        } else if formatting == .link {
            document.text += "[link text](https://example.com)"
        }
        
        // Force the document to recognize the change
        if document.text != originalText {
            // Trigger a UI update by slightly modifying and restoring a property
            let currentText = document.text
            document.text = currentText
        }
    }
}
