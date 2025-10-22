//
//  MarkdownEditor.swift
//  MarkdownEditor
//
//  Created by Dirk Clemens on 20.10.25.
//

import SwiftUI
import AppKit

struct MarkdownEditorTheme {
    let backgroundColor: NSColor
    let textColor: NSColor
    let headerColors: [NSColor]
    let boldColor: NSColor
    let italicColor: NSColor
    let strikethroughColor: NSColor
    let codeColor: NSColor
    let codeBackgroundColor: NSColor
    let blockquoteColor: NSColor
    let blockquoteSymbolColor: NSColor
    let tableColor: NSColor
    let imageColor: NSColor
    let imageSymbolColor: NSColor
    let linkColor: NSColor
    let listColor: NSColor
}

let lightTheme = MarkdownEditorTheme(
    backgroundColor: NSColor.textBackgroundColor,
    textColor: NSColor.textColor,
    headerColors: [NSColor.systemBlue, NSColor.systemIndigo, NSColor.systemPurple, NSColor.systemTeal, NSColor.systemGreen, NSColor.systemOrange],
    boldColor: NSColor.textColor,
    italicColor: NSColor.textColor,
    strikethroughColor: NSColor.systemGray,
    codeColor: NSColor.systemRed,
    codeBackgroundColor: NSColor.controlBackgroundColor,
    blockquoteColor: NSColor.systemGray,
    blockquoteSymbolColor: NSColor.systemOrange,
    tableColor: NSColor.systemPurple,
    imageColor: NSColor.systemBlue,
    imageSymbolColor: NSColor.systemRed,
    linkColor: NSColor.systemBlue,
    listColor: NSColor.systemGreen
)

let darkTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.22, alpha: 1), // #222
    textColor: NSColor(calibratedWhite: 0.97, alpha: 1), // #f8f8f8
    headerColors: [
        NSColor(calibratedRed: 0.27, green: 0.44, blue: 0.78, alpha: 1), // blue
        NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.86, alpha: 1), // cyan
        NSColor(calibratedRed: 0.36, green: 0.60, blue: 0.80, alpha: 1), // blue-gray
        NSColor(calibratedRed: 0.18, green: 0.36, blue: 0.60, alpha: 1), // dark blue
        NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.22, alpha: 1), // fallback
        NSColor.systemOrange
    ],
    boldColor: NSColor(calibratedWhite: 0.97, alpha: 1),
    italicColor: NSColor(calibratedWhite: 0.90, alpha: 1),
    strikethroughColor: NSColor(calibratedWhite: 0.60, alpha: 1),
    codeColor: NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.86, alpha: 1), // cyan
    codeBackgroundColor: NSColor(calibratedRed: 0.18, green: 0.18, blue: 0.28, alpha: 1), // slightly lighter than bg
    blockquoteColor: NSColor(calibratedRed: 0.36, green: 0.60, blue: 0.80, alpha: 1), // blue-gray
    blockquoteSymbolColor: NSColor.systemOrange,
    tableColor: NSColor(calibratedRed: 0.27, green: 0.44, blue: 0.78, alpha: 1), // blue
    imageColor: NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.86, alpha: 1), // cyan
    imageSymbolColor: NSColor.systemRed,
    linkColor: NSColor(calibratedRed: 0.27, green: 0.44, blue: 0.78, alpha: 1), // blue
    listColor: NSColor.systemGreen
)

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let gutterWidth: CGFloat
    let fontSize: CGFloat
    let separatorWidth: CGFloat
    let theme: MarkdownEditorTheme
    var onCursorPositionChanged: ((Int) -> Void)? = nil
    var onSelectionChanged: ((NSRange) -> Void)? = nil
    
    init(text: Binding<String>, gutterWidth: CGFloat = 50, fontSize: CGFloat = 14, separatorWidth: CGFloat = 1.0, theme: MarkdownEditorTheme, onCursorPositionChanged: ((Int) -> Void)? = nil, onSelectionChanged: ((NSRange) -> Void)? = nil) {
        self._text = text
        self.gutterWidth = gutterWidth
        self.fontSize = fontSize
        self.separatorWidth = separatorWidth
        self.theme = theme
        self.onCursorPositionChanged = onCursorPositionChanged
        self.onSelectionChanged = onSelectionChanged
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
        textView.backgroundColor = theme.backgroundColor
        textView.textColor = theme.textColor
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
        textView.backgroundColor = theme.backgroundColor
        textView.textColor = theme.textColor
        if textView.string != text {
            textView.string = text
            context.coordinator.updateLineNumbers()
        }
        context.coordinator.applyMarkdownSyntaxHighlighting(to: textView)
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
        
        func textViewDidChangeSelection(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                let pos = textView.selectedRange().location
                parent.onCursorPositionChanged?(pos)
                
                // Notify about the selection change
                let selectedRange = textView.selectedRange()
                parent.onSelectionChanged?(NSRange(location: selectedRange.location, length: selectedRange.length))
            }
        }
        
        func getCursorPosition() -> Int? {
            return textView?.selectedRange().location
        }
        
        func applyMarkdownSyntaxHighlighting(to textView: NSTextView) {
            let text = textView.string
            let range = NSRange(location: 0, length: text.count)
            let baseFont = NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)
            textView.font = baseFont
            textView.textStorage?.removeAttribute(.foregroundColor, range: range)
            textView.textStorage?.removeAttribute(.font, range: range)
            textView.textStorage?.addAttribute(.font, value: baseFont, range: range)
            let fgColor = parent.theme.textColor
            textView.textStorage?.addAttribute(.foregroundColor, value: fgColor, range: range)
            
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
            let theme = parent.theme
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                let headerLevel = min(match.range(at: 1).length, theme.headerColors.count)
                let headerFont = NSFont.boldSystemFont(ofSize: parent.fontSize)
                let headerColor = theme.headerColors[headerLevel - 1]
                textView.textStorage?.addAttribute(.font, value: headerFont, range: match.range)
                textView.textStorage?.addAttribute(.foregroundColor, value: headerColor, range: match.range)
            }
        }
        private func highlightBold(in textView: NSTextView, text: String) {
            let boldPattern = "\\*\\*(.*?)\\*\\*"
            let regex = try! NSRegularExpression(pattern: boldPattern)
            let theme = parent.theme
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                let boldFont = NSFont.boldSystemFont(ofSize: parent.fontSize)
                textView.textStorage?.addAttribute(.font, value: boldFont, range: match.range)
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.boldColor, range: match.range)
            }
        }
        private func highlightItalic(in textView: NSTextView, text: String) {
            let italicPattern = "\\*(.*?)\\*"
            let regex = try! NSRegularExpression(pattern: italicPattern)
            let theme = parent.theme
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                let italicFont = NSFontManager.shared.convert(NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular), toHaveTrait: .italicFontMask)
                textView.textStorage?.addAttribute(.font, value: italicFont, range: match.range)
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.italicColor, range: match.range)
            }
        }
        private func highlightStrikethrough(in textView: NSTextView, text: String) {
            let strikethroughPattern = "~~(.*?)~~"
            let regex = try! NSRegularExpression(pattern: strikethroughPattern)
            let theme = parent.theme
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                textView.textStorage?.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.strikethroughColor, range: match.range)
            }
        }
        private func highlightCode(in textView: NSTextView, text: String) {
            let theme = parent.theme
            let inlineCodePattern = "`([^`\\n]+)`"
            let inlineRegex = try! NSRegularExpression(pattern: inlineCodePattern)
            inlineRegex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                let codeFont = NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)
                textView.textStorage?.addAttribute(.font, value: codeFont, range: match.range)
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.codeColor, range: match.range)
                textView.textStorage?.addAttribute(.backgroundColor, value: theme.codeBackgroundColor, range: match.range)
            }
            let lines = text.components(separatedBy: .newlines)
            var inCodeBlock = false
            var codeBlockStart = 0
            var currentLine = 0
            for (_, line) in lines.enumerated() {
                let lineStart = text.distance(from: text.startIndex, to: text.index(text.startIndex, offsetBy: currentLine))
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    if !inCodeBlock {
                        inCodeBlock = true
                        codeBlockStart = lineStart
                    } else {
                        inCodeBlock = false
                        let lineEnd = lineStart + line.count
                        let codeBlockRange = NSRange(location: codeBlockStart, length: lineEnd - codeBlockStart)
                        let codeFont = NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)
                        textView.textStorage?.addAttribute(.font, value: codeFont, range: codeBlockRange)
                        textView.textStorage?.addAttribute(.foregroundColor, value: theme.codeColor, range: codeBlockRange)
                        textView.textStorage?.addAttribute(.backgroundColor, value: theme.codeBackgroundColor, range: codeBlockRange)
                    }
                }
                currentLine += line.count + 1
                if currentLine > text.count { break }
            }
        }
        private func highlightBlockquotes(in textView: NSTextView, text: String) {
            let blockquotePattern = "^(\\s*>+\\s?)(.*)"
            let regex = try! NSRegularExpression(pattern: blockquotePattern, options: [.anchorsMatchLines])
            let theme = parent.theme
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.blockquoteColor, range: match.range)
                let symbolRange = match.range(at: 1)
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.blockquoteSymbolColor, range: symbolRange)
                textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: parent.fontSize), range: symbolRange)
            }
        }
        private func highlightTables(in textView: NSTextView, text: String) {
            let lines = text.components(separatedBy: .newlines)
            var currentPosition = 0
            let theme = parent.theme
            for (index, line) in lines.enumerated() {
                let lineStart = currentPosition
                let lineEnd = currentPosition + line.count
                if line.contains("|") {
                    let lineRange = NSRange(location: lineStart, length: line.count)
                    let separatorPattern = "^\\s*\\|?\\s*[-:]+\\s*(\\|\\s*[-:]+\\s*)*\\|?\\s*$"
                    let separatorRegex = try! NSRegularExpression(pattern: separatorPattern)
                    if separatorRegex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) != nil {
                        textView.textStorage?.addAttribute(.foregroundColor, value: theme.tableColor, range: lineRange)
                        textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: parent.fontSize), range: lineRange)
                    } else {
                        let pipePattern = "\\|"
                        let pipeRegex = try! NSRegularExpression(pattern: pipePattern)
                        pipeRegex.enumerateMatches(in: line, range: NSRange(location: 0, length: line.count)) { match, _, _ in
                            guard let match = match else { return }
                            let globalRange = NSRange(location: lineStart + match.range.location, length: match.range.length)
                            textView.textStorage?.addAttribute(.foregroundColor, value: theme.tableColor, range: globalRange)
                            textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: parent.fontSize), range: globalRange)
                        }
                        let isHeader = (index > 0 && lines[index - 1].range(of: "[-:]", options: .regularExpression) != nil) ||
                                      (index < lines.count - 1 && lines[index + 1].range(of: "[-:]", options: .regularExpression) != nil)
                        if isHeader {
                            textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: parent.fontSize), range: lineRange)
                        }
                    }
                }
                currentPosition = lineEnd + 1
                if currentPosition > text.count { break }
            }
        }
        private func highlightImages(in textView: NSTextView, text: String) {
            let imagePattern = "!\\[([^\\]]*)\\]\\(([^\\)]+)\\)"
            let regex = try! NSRegularExpression(pattern: imagePattern)
            let theme = parent.theme
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.imageColor, range: match.range)
                let exclamationRange = NSRange(location: match.range.location, length: 1)
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.imageSymbolColor, range: exclamationRange)
                textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: parent.fontSize), range: exclamationRange)
                let altTextRange = match.range(at: 1)
                if altTextRange.length > 0 {
                    textView.textStorage?.addAttribute(.font, value: NSFontManager.shared.convert(NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular), toHaveTrait: .italicFontMask), range: altTextRange)
                }
            }
        }
        private func highlightLinks(in textView: NSTextView, text: String) {
            let linkPattern = "\\[([^\\]]+)\\]\\(([^\\)]+)\\)"
            let regex = try! NSRegularExpression(pattern: linkPattern)
            let theme = parent.theme
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.linkColor, range: match.range)
                textView.textStorage?.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
            }
        }
        private func highlightLists(in textView: NSTextView, text: String) {
            let listPattern = "^(\\s*)([-*+]|\\d+\\.)\\s+"
            let regex = try! NSRegularExpression(pattern: listPattern, options: [.anchorsMatchLines])
            let theme = parent.theme
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let match = match else { return }
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.listColor, range: match.range)
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
