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
    let gutterWidth: CGFloat
    let fontSize: CGFloat
    let separatorWidth: CGFloat
    
    init(text: Binding<String>, gutterWidth: CGFloat = 50, fontSize: CGFloat = 14, separatorWidth: CGFloat = 1.0) {
        self._text = text
        self.gutterWidth = gutterWidth
        self.fontSize = fontSize
        self.separatorWidth = separatorWidth
    }
    
    func makeNSView(context: Context) -> NSView {
        // Create container view
        let containerView = NSView()
        
        // Create line number view
        let lineNumberView = LineNumberView(separatorWidth: separatorWidth)
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create scroll view with text view
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.string = text
        
        // Configure text view
        textView.textContainerInset = NSSize(width: 5, height: 5)
        textView.textContainer?.lineFragmentPadding = 0
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add views to container
        containerView.addSubview(lineNumberView)
        containerView.addSubview(scrollView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            lineNumberView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            lineNumberView.topAnchor.constraint(equalTo: containerView.topAnchor),
            lineNumberView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            lineNumberView.widthAnchor.constraint(equalToConstant: gutterWidth),
            
            scrollView.leadingAnchor.constraint(equalTo: lineNumberView.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Store references for coordinator
        context.coordinator.textView = textView
        context.coordinator.lineNumberView = lineNumberView
        context.coordinator.scrollView = scrollView
        
        // Connect line number view to text view
        lineNumberView.textView = textView
        lineNumberView.scrollView = scrollView
        
        // Add scroll notification observer
        NotificationCenter.default.addObserver(
            forName: NSScrollView.didLiveScrollNotification,
            object: scrollView,
            queue: .main
        ) { _ in
            lineNumberView.needsDisplay = true
        }
        
        // Enable syntax highlighting
        context.coordinator.applyMarkdownSyntaxHighlighting(to: textView)
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.applyMarkdownSyntaxHighlighting(to: textView)
            context.coordinator.updateLineNumbers()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MarkdownEditor
        var textView: NSTextView?
        var lineNumberView: LineNumberView?
        var scrollView: NSScrollView?
        
        init(_ parent: MarkdownEditor) {
            self.parent = parent
        }
        
        func updateLineNumbers() {
            lineNumberView?.setNeedsDisplay(lineNumberView?.bounds ?? .zero)
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
            let baseFont = NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)
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
                
                // Use consistent font size for proper line alignment
                let headerFont = NSFont.boldSystemFont(ofSize: parent.fontSize)
                
                // Different colors for different header levels to maintain visual hierarchy
                let headerColor: NSColor = {
                    switch headerLevel {
                    case 1: return NSColor.systemBlue
                    case 2: return NSColor.systemIndigo
                    case 3: return NSColor.systemPurple
                    case 4: return NSColor.systemTeal
                    case 5: return NSColor.systemGreen
                    case 6: return NSColor.systemOrange
                    default: return NSColor.systemBlue
                    }
                }()
                
                textView.textStorage?.addAttribute(.font, value: headerFont, range: match.range)
                textView.textStorage?.addAttribute(.foregroundColor, value: headerColor, range: match.range)
            }
        }
        
        private func highlightBold(in textView: NSTextView, text: String) {
            let boldPattern = "\\*\\*(.*?)\\*\\*"
            let regex = try! NSRegularExpression(pattern: boldPattern)
            
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                let boldFont = NSFont.boldSystemFont(ofSize: parent.fontSize)
                textView.textStorage?.addAttribute(.font, value: boldFont, range: match.range)
            }
        }
        
        private func highlightItalic(in textView: NSTextView, text: String) {
            let italicPattern = "\\*(.*?)\\*"
            let regex = try! NSRegularExpression(pattern: italicPattern)
            
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                let italicFont = NSFont.systemFont(ofSize: parent.fontSize).withTraits([.italic])
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
                let codeFont = NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)
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
                        
                        let codeFont = NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)
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
                textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: parent.fontSize), range: symbolRange)
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
                        textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: parent.fontSize), range: lineRange)
                    } else {
                        // This is a regular table row - highlight the pipes
                        let pipePattern = "\\|"
                        let pipeRegex = try! NSRegularExpression(pattern: pipePattern)
                        
                        pipeRegex.enumerateMatches(in: line, range: NSRange(location: 0, length: line.count)) { match, _, _ in
                            guard let match = match else { return }
                            let globalRange = NSRange(location: lineStart + match.range.location, length: match.range.length)
                            textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: globalRange)
                            textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: parent.fontSize), range: globalRange)
                        }
                        
                        // Check if this looks like a header row (previous or next line is separator)
                        let isHeader = (index > 0 && lines[index - 1].range(of: "[-:]", options: .regularExpression) != nil) ||
                                      (index < lines.count - 1 && lines[index + 1].range(of: "[-:]", options: .regularExpression) != nil)
                        
                        if isHeader {
                            textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: parent.fontSize), range: lineRange)
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
                textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: parent.fontSize), range: exclamationRange)
                
                // Highlight alt text in italic (only if not empty)
                let altTextRange = match.range(at: 1)
                if altTextRange.length > 0 {
                    let italicFont = NSFont.systemFont(ofSize: parent.fontSize).withTraits([.italic])
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

class LineNumberView: NSView {
    weak var textView: NSTextView?
    weak var scrollView: NSScrollView?
    let separatorWidth: CGFloat
    
    init(separatorWidth: CGFloat = 1.0) {
        self.separatorWidth = separatorWidth
        super.init(frame: .zero)
    }
    
    override init(frame frameRect: NSRect) {
        self.separatorWidth = 1.0
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        self.separatorWidth = 1.0
        super.init(coder: coder)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Clear background with default system color
        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()
        
        // Draw separator line on the right
        NSColor.separatorColor.setStroke()
        let separatorPath = NSBezierPath()
        let separatorOffset = separatorWidth / 2.0
        separatorPath.move(to: NSPoint(x: bounds.maxX - separatorOffset, y: bounds.minY))
        separatorPath.line(to: NSPoint(x: bounds.maxX - separatorOffset, y: bounds.maxY))
        separatorPath.lineWidth = separatorWidth
        separatorPath.stroke()
        
        guard let textView = textView,
              let scrollView = scrollView,
              let layoutManager = textView.layoutManager//,
              //let textContainer = textView.textContainer
        else {
            return
        }
        
        let font = NSFont.monospacedSystemFont(ofSize: textView.font?.pointSize ?? 14, weight: .regular)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        // Get visible rect and text info
        let visibleRect = scrollView.documentVisibleRect
        let text = textView.string as NSString
        let textLength = text.length
        
        // Split text into lines and calculate positions
        let lines = text.components(separatedBy: .newlines)
        var currentCharIndex = 0
        
        for (lineIndex, line) in lines.enumerated() {
            let lineNumber = lineIndex + 1
            
            // Get the line fragment rect for this line's character position
            if currentCharIndex < textLength {
                let glyphIndex = layoutManager.glyphIndexForCharacter(at: currentCharIndex)
                let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                
                // Convert to document coordinates (accounting for text container inset)
                let lineY = lineFragmentRect.minY + textView.textContainerInset.height
                
                // Check if this line is visible in the scroll view
                if lineY >= visibleRect.minY - 50 && lineY <= visibleRect.maxY + 50 {
                    // Use the same line fragment rect approach as the text view
                    let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                    
                    // Calculate Y position relative to the visible area, accounting for text container inset
                    let textLineY = lineFragmentRect.minY + textView.textContainerInset.height
                    let relativeY = textLineY - visibleRect.minY
                    
                    // Position line number to align with text line (flip coordinate system)
                    let drawY = bounds.maxY - relativeY - lineFragmentRect.height
                    
                    let numberString = "\(lineNumber)"
                    let stringSize = numberString.size(withAttributes: textAttributes)
                    
                    let drawRect = NSRect(
                        x: bounds.width - stringSize.width - 5,
                        y: drawY,
                        width: stringSize.width,
                        height: stringSize.height
                    )
                    
                    // Only draw if within our visible bounds
                    if drawRect.intersects(bounds) {
                        numberString.draw(in: drawRect, withAttributes: textAttributes)
                    }
                }
            }
            
            // Move to next line
            currentCharIndex += line.count + 1 // +1 for the newline character
        }
    }
}
