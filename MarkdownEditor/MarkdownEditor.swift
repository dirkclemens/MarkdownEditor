//
//  MarkdownEditor.swift
//  MarkdownEditor
//
//  Created by Dirk Clemens on 20.10.25.
//

import SwiftUI
import AppKit

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.string = text
        
        // Enable syntax highlighting
        context.coordinator.applyMarkdownSyntaxHighlighting(to: textView)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
            context.coordinator.applyMarkdownSyntaxHighlighting(to: textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MarkdownEditor
        
        init(_ parent: MarkdownEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyMarkdownSyntaxHighlighting(to: textView)
        }
        
        func applyMarkdownSyntaxHighlighting(to textView: NSTextView) {
            let text = textView.string
            let range = NSRange(location: 0, length: text.count)
            
            // Reset formatting
            textView.textStorage?.removeAttribute(.foregroundColor, range: range)
            textView.textStorage?.removeAttribute(.font, range: range)
            
            // Base font
            let baseFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            textView.textStorage?.addAttribute(.font, value: baseFont, range: range)
            textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
            
            // Apply syntax highlighting
            highlightHeaders(in: textView, text: text)
            highlightBold(in: textView, text: text)
            highlightItalic(in: textView, text: text)
            highlightStrikethrough(in: textView, text: text)
            highlightCode(in: textView, text: text)
            highlightBlockquotes(in: textView, text: text)
            highlightTables(in: textView, text: text)
            highlightImages(in: textView, text: text)
            highlightLinks(in: textView, text: text)
            highlightLists(in: textView, text: text)
        }
        
        private func highlightHeaders(in textView: NSTextView, text: String) {
            let headerPattern = "^(#{1,6})\\s+(.*)$"
            let regex = try! NSRegularExpression(pattern: headerPattern, options: [.anchorsMatchLines])
            
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                
                let headerLevel = match.range(at: 1).length
                let fontSize: CGFloat = max(18 - CGFloat(headerLevel) * 2, 14)
                let headerFont = NSFont.boldSystemFont(ofSize: fontSize)
                
                textView.textStorage?.addAttribute(.font, value: headerFont, range: match.range)
                textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
            }
        }
        
        private func highlightBold(in textView: NSTextView, text: String) {
            let boldPattern = "\\*\\*(.*?)\\*\\*"
            let regex = try! NSRegularExpression(pattern: boldPattern)
            
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                let boldFont = NSFont.boldSystemFont(ofSize: 14)
                textView.textStorage?.addAttribute(.font, value: boldFont, range: match.range)
            }
        }
        
        private func highlightItalic(in textView: NSTextView, text: String) {
            let italicPattern = "\\*(.*?)\\*"
            let regex = try! NSRegularExpression(pattern: italicPattern)
            
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                let italicFont = NSFont.systemFont(ofSize: 14).withTraits([.italic])
                textView.textStorage?.addAttribute(.font, value: italicFont, range: match.range)
            }
        }
        
        private func highlightStrikethrough(in textView: NSTextView, text: String) {
            let strikethroughPattern = "~~(.*?)~~"
            let regex = try! NSRegularExpression(pattern: strikethroughPattern)
            
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                textView.textStorage?.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemGray, range: match.range)
            }
        }
        
        private func highlightCode(in textView: NSTextView, text: String) {
            // Inline code first (to avoid conflicts with code blocks)
            let inlineCodePattern = "`([^`\n]+)`"
            let inlineRegex = try! NSRegularExpression(pattern: inlineCodePattern)
            
            inlineRegex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                let codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                textView.textStorage?.addAttribute(.font, value: codeFont, range: match.range)
                textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemRed, range: match.range)
                textView.textStorage?.addAttribute(.backgroundColor, value: NSColor.controlBackgroundColor, range: match.range)
            }
            
            // Code blocks - handle multiline properly
            let lines = text.components(separatedBy: .newlines)
            var inCodeBlock = false
            var codeBlockStart = 0
            var currentLine = 0
            
            for (_, line) in lines.enumerated() {
                let lineStart = text.distance(from: text.startIndex, to: text.index(text.startIndex, offsetBy: currentLine))
                
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    if !inCodeBlock {
                        // Start of code block
                        inCodeBlock = true
                        codeBlockStart = lineStart
                    } else {
                        // End of code block
                        inCodeBlock = false
                        let lineEnd = lineStart + line.count
                        let codeBlockRange = NSRange(location: codeBlockStart, length: lineEnd - codeBlockStart)
                        
                        let codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                        textView.textStorage?.addAttribute(.font, value: codeFont, range: codeBlockRange)
                        textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemRed, range: codeBlockRange)
                        textView.textStorage?.addAttribute(.backgroundColor, value: NSColor.controlBackgroundColor, range: codeBlockRange)
                    }
                }
                
                currentLine += line.count + 1 // +1 for newline character
                if currentLine > text.count { break }
            }
        }
        
        private func highlightBlockquotes(in textView: NSTextView, text: String) {
            let blockquotePattern = "^(\\s*>+\\s?)(.*)"
            let regex = try! NSRegularExpression(pattern: blockquotePattern, options: [.anchorsMatchLines])
            
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                
                // Highlight the entire blockquote line
                textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemGray, range: match.range)
                
                // Make the > symbol more prominent
                let symbolRange = match.range(at: 1)
                textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: symbolRange)
                textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: symbolRange)
            }
        }
        
        private func highlightTables(in textView: NSTextView, text: String) {
            let lines = text.components(separatedBy: .newlines)
            var currentPosition = 0
            
            for (index, line) in lines.enumerated() {
                let lineStart = currentPosition
                let lineEnd = currentPosition + line.count
                
                // Check if line contains table syntax (has at least one |)
                if line.contains("|") {
                    let lineRange = NSRange(location: lineStart, length: line.count)
                    
                    // Check if this is a table separator line (contains dashes and pipes)
                    let separatorPattern = "^\\s*\\|?\\s*[-:]+\\s*(\\|\\s*[-:]+\\s*)*\\|?\\s*$"
                    let separatorRegex = try! NSRegularExpression(pattern: separatorPattern)
                    
                    if separatorRegex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) != nil {
                        // This is a table separator line - highlight it differently
                        textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: lineRange)
                        textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: lineRange)
                    } else {
                        // This is a regular table row - highlight the pipes
                        let pipePattern = "\\|"
                        let pipeRegex = try! NSRegularExpression(pattern: pipePattern)
                        
                        pipeRegex.enumerateMatches(in: line, range: NSRange(location: 0, length: line.count)) { match, _, _ in
                            guard let match = match else { return }
                            let globalRange = NSRange(location: lineStart + match.range.location, length: match.range.length)
                            textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: globalRange)
                            textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: globalRange)
                        }
                        
                        // Check if this looks like a header row (previous or next line is separator)
                        let isHeader = (index > 0 && lines[index - 1].range(of: "[-:]", options: .regularExpression) != nil) ||
                                      (index < lines.count - 1 && lines[index + 1].range(of: "[-:]", options: .regularExpression) != nil)
                        
                        if isHeader {
                            textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: lineRange)
                        }
                    }
                }
                
                currentPosition = lineEnd + 1 // +1 for newline
                if currentPosition > text.count { break }
            }
        }
        
        private func highlightImages(in textView: NSTextView, text: String) {
            let imagePattern = "!\\[([^\\]]*)\\]\\(([^\\)]+)\\)"
            let regex = try! NSRegularExpression(pattern: imagePattern)
            
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                
                // Highlight the entire image syntax in blue (consistent with links)
                textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
                
                // Make the ! symbol more prominent with red color
                let exclamationRange = NSRange(location: match.range.location, length: 1)
                textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemRed, range: exclamationRange)
                textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: exclamationRange)
                
                // Highlight alt text in italic (only if not empty)
                let altTextRange = match.range(at: 1)
                if altTextRange.length > 0 {
                    let italicFont = NSFont.systemFont(ofSize: 14).withTraits([.italic])
                    textView.textStorage?.addAttribute(.font, value: italicFont, range: altTextRange)
                }
            }
        }
        
        private func highlightLinks(in textView: NSTextView, text: String) {
            let linkPattern = "\\[([^\\]]+)\\]\\(([^\\)]+)\\)"
            let regex = try! NSRegularExpression(pattern: linkPattern)
            
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
                textView.textStorage?.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
            }
        }
        
        private func highlightLists(in textView: NSTextView, text: String) {
            let listPattern = "^(\\s*)([-*+]|\\d+\\.)\\s+"
            let regex = try! NSRegularExpression(pattern: listPattern, options: [.anchorsMatchLines])
            
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: match.range)
            }
        }
    }
}

extension NSFont {
    func withTraits(_ traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
