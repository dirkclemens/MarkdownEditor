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
    var fontSize: CGFloat
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
        textView.textContainerInset = NSSize(width: 0, height: 0) // set padding to zero
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
        context.coordinator.parent = self // keep coordinator in sync!
        guard let textView = context.coordinator.textView else { return }
        //print("[updateNSView] Setting font size to", fontSize)
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.backgroundColor = theme.backgroundColor
        textView.textColor = theme.textColor
        if textView.string != text {
            textView.string = text
            context.coordinator.updateLineNumbers()
        }
        context.coordinator.applyMarkdownSyntaxHighlighting(to: textView)
        textView.setNeedsDisplay(textView.bounds)
        if let textContainer = textView.textContainer {
            textView.layoutManager?.ensureLayout(for: textContainer)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
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
            //print("[applyMarkdownSyntaxHighlighting] Using font size", parent.fontSize)
            // Remove all font and color attributes before applying new ones
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
                        x: bounds.width - stringSize.width - 15, // Right align with some padding
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

let monokaiDarkTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.152, green: 0.157, blue: 0.137, alpha: 1), // #272822
    textColor: NSColor(calibratedRed: 0.972, green: 0.972, blue: 0.949, alpha: 1), // #F8F8F2
    headerColors: [
        NSColor(calibratedRed: 0.651, green: 0.886, blue: 0.180, alpha: 1), // #A6E22E
        NSColor(calibratedRed: 0.976, green: 0.149, blue: 0.447, alpha: 1), // #F92672
        NSColor(calibratedRed: 0.992, green: 0.592, blue: 0.122, alpha: 1), // #FD971F
        NSColor(calibratedRed: 0.400, green: 0.851, blue: 0.937, alpha: 1), // #66D9EF
        NSColor(calibratedRed: 0.682, green: 0.506, blue: 1.0, alpha: 1),   // #AE81FF
        NSColor(calibratedRed: 0.972, green: 0.972, blue: 0.949, alpha: 1) // #F8F8F2
    ],
    boldColor: NSColor(calibratedRed: 0.976, green: 0.149, blue: 0.447, alpha: 1), // #F92672
    italicColor: NSColor(calibratedRed: 0.992, green: 0.592, blue: 0.122, alpha: 1), // #FD971F
    strikethroughColor: NSColor(calibratedRed: 0.462, green: 0.443, blue: 0.369, alpha: 1), // #75715E
    codeColor: NSColor(calibratedRed: 0.902, green: 0.859, blue: 0.455, alpha: 1), // #E6DB74
    codeBackgroundColor: NSColor(calibratedRed: 0.243, green: 0.239, blue: 0.196, alpha: 1), // #3E3D32
    blockquoteColor: NSColor(calibratedRed: 0.462, green: 0.443, blue: 0.369, alpha: 1), // #75715E
    blockquoteSymbolColor: NSColor(calibratedRed: 0.682, green: 0.506, blue: 1.0, alpha: 1), // #AE81FF
    tableColor: NSColor(calibratedRed: 0.400, green: 0.851, blue: 0.937, alpha: 1), // #66D9EF
    imageColor: NSColor(calibratedRed: 0.651, green: 0.886, blue: 0.180, alpha: 1), // #A6E22E
    imageSymbolColor: NSColor(calibratedRed: 0.976, green: 0.149, blue: 0.447, alpha: 1), // #F92672
    linkColor: NSColor(calibratedRed: 0.400, green: 0.851, blue: 0.937, alpha: 1), // #66D9EF
    listColor: NSColor(calibratedRed: 0.651, green: 0.886, blue: 0.180, alpha: 1) // #A6E22E
)

let pastelTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 1.0, green: 0.97, blue: 0.94, alpha: 1), // #FFF7F0
    textColor: NSColor(calibratedRed: 0.36, green: 0.36, blue: 0.36, alpha: 1), // #5D5D5D
    headerColors: [
        NSColor(calibratedRed: 0.64, green: 0.79, blue: 0.66, alpha: 1), // #A3C9A8
        NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.88, alpha: 1), // #FFD6E0
        NSColor(calibratedRed: 0.71, green: 0.92, blue: 0.84, alpha: 1), // #B5EAD7
        NSColor(calibratedRed: 0.80, green: 0.89, blue: 0.99, alpha: 1), // #CCE7FF (pastel blue)
        NSColor(calibratedRed: 0.78, green: 0.81, blue: 0.92, alpha: 1), // #C7CEEA
        NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.70, alpha: 1)  // #FFB7B2
    ],
    boldColor: NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.70, alpha: 1), // #FFB7B2
    italicColor: NSColor(calibratedRed: 0.71, green: 0.92, blue: 0.84, alpha: 1), // #B5EAD7
    strikethroughColor: NSColor(calibratedRed: 0.78, green: 0.81, blue: 0.92, alpha: 1), // #C7CEEA
    codeColor: NSColor(calibratedRed: 0.1, green: 0.14, blue: 0.88, alpha: 1), // #1A23E0
    codeBackgroundColor: NSColor(calibratedRed: 0.95, green: 0.91, blue: 1.0, alpha: 1), // #F3E8FF
    blockquoteColor: NSColor(calibratedRed: 0.64, green: 0.79, blue: 0.66, alpha: 1), // #A3C9A8
    blockquoteSymbolColor: NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.76, alpha: 1), // #FFDAC1
    tableColor: NSColor(calibratedRed: 0.78, green: 0.81, blue: 0.92, alpha: 1), // #C7CEEA
    imageColor: NSColor(calibratedRed: 0.71, green: 0.92, blue: 0.84, alpha: 1), // #B5EAD7
    imageSymbolColor: NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.70, alpha: 1), // #FFB7B2
    linkColor: NSColor(calibratedRed: 0.64, green: 0.79, blue: 0.66, alpha: 1), // #A3C9A8
    listColor: NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.88, alpha: 1) // #FFD6E0
)

// Solarized Light Theme
let solarizedLightTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.992, green: 0.965, blue: 0.890, alpha: 1), // base3 #fdf6e3
    textColor: NSColor(calibratedRed: 0.345, green: 0.431, blue: 0.459, alpha: 1), // base00 #657b83
    headerColors: [
        NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1), // yellow #b58900
        NSColor(calibratedRed: 0.796, green: 0.294, blue: 0.086, alpha: 1), // orange #cb4b16
        NSColor(calibratedRed: 0.796, green: 0.0, blue: 0.086, alpha: 1), // red #dc322f
        NSColor(calibratedRed: 0.522, green: 0.0, blue: 0.522, alpha: 1), // magenta #d33682
        NSColor(calibratedRed: 0.345, green: 0.431, blue: 0.459, alpha: 1), // base00 #657b83
        NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1) // cyan #2aa198
    ],
    boldColor: NSColor(calibratedRed: 0.796, green: 0.0, blue: 0.086, alpha: 1), // red #dc322f
    italicColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    strikethroughColor: NSColor(calibratedRed: 0.345, green: 0.431, blue: 0.459, alpha: 1), // base00 #657b83
    codeColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    codeBackgroundColor: NSColor(calibratedRed: 0.933, green: 0.910, blue: 0.792, alpha: 1), // base2 #eee8d5
    blockquoteColor: NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1), // yellow #b58900
    blockquoteSymbolColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    tableColor: NSColor(calibratedRed: 0.345, green: 0.431, blue: 0.459, alpha: 1), // base00 #657b83
    imageColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    imageSymbolColor: NSColor(calibratedRed: 0.796, green: 0.0, blue: 0.086, alpha: 1), // red #dc322f
    linkColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    listColor: NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1) // yellow #b58900
)

// Solarized Dark Theme
let solarizedDarkTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.0, green: 0.168, blue: 0.211, alpha: 1), // base03 #002b36
    textColor: NSColor(calibratedRed: 0.514, green: 0.580, blue: 0.588, alpha: 1), // base0 #839496
    headerColors: [
        NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1), // yellow #b58900
        NSColor(calibratedRed: 0.796, green: 0.294, blue: 0.086, alpha: 1), // orange #cb4b16
        NSColor(calibratedRed: 0.796, green: 0.0, blue: 0.086, alpha: 1), // red #dc322f
        NSColor(calibratedRed: 0.522, green: 0.0, blue: 0.522, alpha: 1), // magenta #d33682
        NSColor(calibratedRed: 0.345, green: 0.431, blue: 0.459, alpha: 1), // base00 #657b83
        NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1) // cyan #2aa198
    ],
    boldColor: NSColor(calibratedRed: 0.796, green: 0.0, blue: 0.086, alpha: 1), // red #dc322f
    italicColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    strikethroughColor: NSColor(calibratedRed: 0.514, green: 0.580, blue: 0.588, alpha: 1), // base0 #839496
    codeColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    codeBackgroundColor: NSColor(calibratedRed: 0.027, green: 0.212, blue: 0.258, alpha: 1), // base02 #073642
    blockquoteColor: NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1), // yellow #b58900
    blockquoteSymbolColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    tableColor: NSColor(calibratedRed: 0.514, green: 0.580, blue: 0.588, alpha: 1), // base0 #839496
    imageColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    imageSymbolColor: NSColor(calibratedRed: 0.796, green: 0.0, blue: 0.086, alpha: 1), // red #dc322f
    linkColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    listColor: NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1) // yellow #b58900
)

// Dracula Theme
let draculaTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.157, green: 0.165, blue: 0.212, alpha: 1), // #282a36
    textColor: NSColor(calibratedRed: 0.972, green: 0.972, blue: 0.949, alpha: 1), // #f8f8f2
    headerColors: [
        NSColor(calibratedRed: 0.545, green: 0.914, blue: 0.992, alpha: 1), // cyan #8be9fd
        NSColor(calibratedRed: 0.314, green: 0.980, blue: 0.482, alpha: 1), // green #50fa7b
        NSColor(calibratedRed: 1.0, green: 0.722, blue: 0.424, alpha: 1), // orange #ffb86c
        NSColor(calibratedRed: 1.0, green: 0.475, blue: 0.776, alpha: 1), // pink #ff79c6
        NSColor(calibratedRed: 0.741, green: 0.576, blue: 0.976, alpha: 1), // purple #bd93f9
        NSColor(calibratedRed: 0.945, green: 0.980, blue: 0.549, alpha: 1) // yellow #f1fa8c
    ],
    boldColor: NSColor(calibratedRed: 1.0, green: 0.333, blue: 0.333, alpha: 1), // red #ff5555
    italicColor: NSColor(calibratedRed: 1.0, green: 0.475, blue: 0.776, alpha: 1), // pink #ff79c6
    strikethroughColor: NSColor(calibratedRed: 0.384, green: 0.447, blue: 0.643, alpha: 1), // comment #6272a4
    codeColor: NSColor(calibratedRed: 0.545, green: 0.914, blue: 0.992, alpha: 1), // cyan #8be9fd
    codeBackgroundColor: NSColor(calibratedRed: 0.267, green: 0.278, blue: 0.353, alpha: 1), // selection #44475a
    blockquoteColor: NSColor(calibratedRed: 0.741, green: 0.576, blue: 0.976, alpha: 1), // purple #bd93f9
    blockquoteSymbolColor: NSColor(calibratedRed: 1.0, green: 0.722, blue: 0.424, alpha: 1), // orange #ffb86c
    tableColor: NSColor(calibratedRed: 0.545, green: 0.914, blue: 0.992, alpha: 1), // cyan #8be9fd
    imageColor: NSColor(calibratedRed: 0.314, green: 0.980, blue: 0.482, alpha: 1), // green #50fa7b
    imageSymbolColor: NSColor(calibratedRed: 1.0, green: 0.333, blue: 0.333, alpha: 1), // red #ff5555
    linkColor: NSColor(calibratedRed: 0.545, green: 0.914, blue: 0.992, alpha: 1), // cyan #8be9fd
    listColor: NSColor(calibratedRed: 0.945, green: 0.980, blue: 0.549, alpha: 1) // yellow #f1fa8c
)

// Gruvbox Dark Theme
let gruvboxDarkTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.157, green: 0.157, blue: 0.157, alpha: 1), // #282828
    textColor: NSColor(calibratedRed: 0.922, green: 0.859, blue: 0.698, alpha: 1), // #ebdbb2
    headerColors: [
        NSColor(calibratedRed: 0.800, green: 0.141, blue: 0.114, alpha: 1), // red #cc241d
        NSColor(calibratedRed: 0.600, green: 0.592, blue: 0.129, alpha: 1), // yellow #d79921
        NSColor(calibratedRed: 0.596, green: 0.592, blue: 0.129, alpha: 1), // yellow #d79921
        NSColor(calibratedRed: 0.271, green: 0.533, blue: 0.533, alpha: 1), // blue #458588
        NSColor(calibratedRed: 0.698, green: 0.616, blue: 0.525, alpha: 1), // gray #bdae93
        NSColor(calibratedRed: 0.922, green: 0.859, blue: 0.698, alpha: 1) // #ebdbb2
    ],
    boldColor: NSColor(calibratedRed: 0.800, green: 0.141, blue: 0.114, alpha: 1), // red #cc241d
    italicColor: NSColor(calibratedRed: 0.600, green: 0.592, blue: 0.129, alpha: 1), // yellow #d79921
    strikethroughColor: NSColor(calibratedRed: 0.698, green: 0.616, blue: 0.525, alpha: 1), // gray #bdae93
    codeColor: NSColor(calibratedRed: 0.271, green: 0.533, blue: 0.533, alpha: 1), // blue #458588
    codeBackgroundColor: NSColor(calibratedRed: 0.212, green: 0.200, blue: 0.176, alpha: 1), // #3c3836
    blockquoteColor: NSColor(calibratedRed: 0.698, green: 0.616, blue: 0.525, alpha: 1), // gray #bdae93
    blockquoteSymbolColor: NSColor(calibratedRed: 0.600, green: 0.592, blue: 0.129, alpha: 1), // yellow #d79921
    tableColor: NSColor(calibratedRed: 0.271, green: 0.533, blue: 0.533, alpha: 1), // blue #458588
    imageColor: NSColor(calibratedRed: 0.596, green: 0.592, blue: 0.129, alpha: 1), // yellow #d79921
    imageSymbolColor: NSColor(calibratedRed: 0.800, green: 0.141, blue: 0.114, alpha: 1), // red #cc241d
    linkColor: NSColor(calibratedRed: 0.271, green: 0.533, blue: 0.533, alpha: 1), // blue #458588
    listColor: NSColor(calibratedRed: 0.600, green: 0.592, blue: 0.129, alpha: 1) // yellow #d79921
)

// Nord Theme
let nordTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.180, green: 0.204, blue: 0.251, alpha: 1), // #2e3440
    textColor: NSColor(calibratedRed: 0.847, green: 0.871, blue: 0.914, alpha: 1), // #d8dee9
    headerColors: [
        NSColor(calibratedRed: 0.561, green: 0.737, blue: 0.733, alpha: 1), // frost #8fbcbb
        NSColor(calibratedRed: 0.749, green: 0.380, blue: 0.416, alpha: 1), // aurora #bf616a
        NSColor(calibratedRed: 0.816, green: 0.529, blue: 0.439, alpha: 1), // aurora #d08770
        NSColor(calibratedRed: 0.922, green: 0.796, blue: 0.545, alpha: 1), // aurora #ebcb8b
        NSColor(calibratedRed: 0.639, green: 0.745, blue: 0.549, alpha: 1), // aurora #a3be8c
        NSColor(calibratedRed: 0.706, green: 0.557, blue: 0.737, alpha: 1) // aurora #b48ead
    ],
    boldColor: NSColor(calibratedRed: 0.749, green: 0.380, blue: 0.416, alpha: 1), // aurora #bf616a
    italicColor: NSColor(calibratedRed: 0.561, green: 0.737, blue: 0.733, alpha: 1), // frost #8fbcbb
    strikethroughColor: NSColor(calibratedRed: 0.561, green: 0.737, blue: 0.733, alpha: 1), // frost #8fbcbb
    codeColor: NSColor(calibratedRed: 0.561, green: 0.737, blue: 0.733, alpha: 1), // frost #8fbcbb
    codeBackgroundColor: NSColor(calibratedRed: 0.212, green: 0.243, blue: 0.302, alpha: 1), // #3b4252
    blockquoteColor: NSColor(calibratedRed: 0.922, green: 0.796, blue: 0.545, alpha: 1), // aurora #ebcb8b
    blockquoteSymbolColor: NSColor(calibratedRed: 0.639, green: 0.745, blue: 0.549, alpha: 1), // aurora #a3be8c
    tableColor: NSColor(calibratedRed: 0.561, green: 0.737, blue: 0.733, alpha: 1), // frost #8fbcbb
    imageColor: NSColor(calibratedRed: 0.639, green: 0.745, blue: 0.549, alpha: 1), // aurora #a3be8c
    imageSymbolColor: NSColor(calibratedRed: 0.749, green: 0.380, blue: 0.416, alpha: 1), // aurora #bf616a
    linkColor: NSColor(calibratedRed: 0.561, green: 0.737, blue: 0.733, alpha: 1), // frost #8fbcbb
    listColor: NSColor(calibratedRed: 0.922, green: 0.796, blue: 0.545, alpha: 1) // aurora #ebcb8b
)

// One Dark Theme
let oneDarkTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.157, green: 0.173, blue: 0.204, alpha: 1), // #282c34
    textColor: NSColor(calibratedRed: 0.671, green: 0.698, blue: 0.749, alpha: 1), // #abb2bf
    headerColors: [
        NSColor(calibratedRed: 0.380, green: 0.686, blue: 0.937, alpha: 1), // blue #61afef
        NSColor(calibratedRed: 0.337, green: 0.714, blue: 0.761, alpha: 1), // cyan #56b6c2
        NSColor(calibratedRed: 0.596, green: 0.765, blue: 0.475, alpha: 1), // green #98c379
        NSColor(calibratedRed: 0.820, green: 0.604, blue: 0.400, alpha: 1), // orange #d19a66
        NSColor(calibratedRed: 0.780, green: 0.420, blue: 0.867, alpha: 1), // purple #c678dd
        NSColor(calibratedRed: 0.878, green: 0.424, blue: 0.459, alpha: 1) // red #e06c75
    ],
    boldColor: NSColor(calibratedRed: 0.878, green: 0.424, blue: 0.459, alpha: 1), // red #e06c75
    italicColor: NSColor(calibratedRed: 0.337, green: 0.714, blue: 0.761, alpha: 1), // cyan #56b6c2
    strikethroughColor: NSColor(calibratedRed: 0.671, green: 0.698, blue: 0.749, alpha: 1), // #abb2bf
    codeColor: NSColor(calibratedRed: 0.380, green: 0.686, blue: 0.937, alpha: 1), // blue #61afef
    codeBackgroundColor: NSColor(calibratedRed: 0.204, green: 0.220, blue: 0.251, alpha: 1), // #313640
    blockquoteColor: NSColor(calibratedRed: 0.820, green: 0.604, blue: 0.400, alpha: 1), // orange #d19a66
    blockquoteSymbolColor: NSColor(calibratedRed: 0.780, green: 0.420, blue: 0.867, alpha: 1), // purple #c678dd
    tableColor: NSColor(calibratedRed: 0.380, green: 0.686, blue: 0.937, alpha: 1), // blue #61afef
    imageColor: NSColor(calibratedRed: 0.596, green: 0.765, blue: 0.475, alpha: 1), // green #98c379
    imageSymbolColor: NSColor(calibratedRed: 0.878, green: 0.424, blue: 0.459, alpha: 1), // red #e06c75
    linkColor: NSColor(calibratedRed: 0.380, green: 0.686, blue: 0.937, alpha: 1), // blue #61afef
    listColor: NSColor(calibratedRed: 0.820, green: 0.604, blue: 0.400, alpha: 1) // orange #d19a66
)

// Tomorrow Night Theme
let tomorrowNightTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.114, green: 0.122, blue: 0.129, alpha: 1), // #1d1f21
    textColor: NSColor(calibratedRed: 0.773, green: 0.784, blue: 0.776, alpha: 1), // #c5c8c6
    headerColors: [
        NSColor(calibratedRed: 0.506, green: 0.635, blue: 0.745, alpha: 1), // blue #81a2be
        NSColor(calibratedRed: 0.710, green: 0.741, blue: 0.408, alpha: 1), // green #b5bd68
        NSColor(calibratedRed: 0.871, green: 0.576, blue: 0.373, alpha: 1), // orange #de935f
        NSColor(calibratedRed: 0.698, green: 0.580, blue: 0.733, alpha: 1), // purple #b294bb
        NSColor(calibratedRed: 0.800, green: 0.400, blue: 0.400, alpha: 1), // red #cc6666
        NSColor(calibratedRed: 0.941, green: 0.780, blue: 0.455, alpha: 1) // yellow #f0c674
    ],
    boldColor: NSColor(calibratedRed: 0.800, green: 0.400, blue: 0.400, alpha: 1), // red #cc6666
    italicColor: NSColor(calibratedRed: 0.710, green: 0.741, blue: 0.408, alpha: 1), // green #b5bd68
    strikethroughColor: NSColor(calibratedRed: 0.698, green: 0.580, blue: 0.733, alpha: 1), // purple #b294bb
    codeColor: NSColor(calibratedRed: 0.506, green: 0.635, blue: 0.745, alpha: 1), // blue #81a2be
    codeBackgroundColor: NSColor(calibratedRed: 0.200, green: 0.216, blue: 0.224, alpha: 1), // #323437
    blockquoteColor: NSColor(calibratedRed: 0.941, green: 0.780, blue: 0.455, alpha: 1), // yellow #f0c674
    blockquoteSymbolColor: NSColor(calibratedRed: 0.710, green: 0.741, blue: 0.408, alpha: 1), // green #b5bd68
    tableColor: NSColor(calibratedRed: 0.506, green: 0.635, blue: 0.745, alpha: 1), // blue #81a2be
    imageColor: NSColor(calibratedRed: 0.710, green: 0.741, blue: 0.408, alpha: 1), // green #b5bd68
    imageSymbolColor: NSColor(calibratedRed: 0.800, green: 0.400, blue: 0.400, alpha: 1), // red #cc6666
    linkColor: NSColor(calibratedRed: 0.506, green: 0.635, blue: 0.745, alpha: 1), // blue #81a2be
    listColor: NSColor(calibratedRed: 0.941, green: 0.780, blue: 0.455, alpha: 1) // yellow #f0c674
)
