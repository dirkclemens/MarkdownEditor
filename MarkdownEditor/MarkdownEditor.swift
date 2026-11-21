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
    var onTextViewReady: ((NSTextView) -> Void)? = nil

    init(text: Binding<String>, gutterWidth: CGFloat = 50, fontSize: CGFloat = 14, separatorWidth: CGFloat = 1.0, theme: MarkdownEditorTheme, onTextViewReady: ((NSTextView) -> Void)? = nil) {
        self._text = text
        self.gutterWidth = gutterWidth
        self.fontSize = fontSize
        self.separatorWidth = separatorWidth
        self.theme = theme
        self.onTextViewReady = onTextViewReady
    }

    func makeNSView(context: Context) -> NSView {
        let coordinator = context.coordinator
        let containerView = NSView()

        let lineNumberView = LineNumberView(separatorWidth: separatorWidth)
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        // Suchen und Ersetzen über die systemeigene Suchleiste (⌘F, ⌥⌘F, ⌘G, ⇧⌘G, ⌘E).
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        containerView.addSubview(lineNumberView)
        containerView.addSubview(scrollView)

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

        coordinator.textView = textView
        coordinator.lineNumberView = lineNumberView
        coordinator.scrollView = scrollView
        lineNumberView.textView = textView
        lineNumberView.scrollView = scrollView

        textView.delegate = coordinator
        textView.textStorage?.delegate = coordinator

        textView.string = text
        coordinator.applyStyle(to: textView)
        coordinator.highlightNow()

        // Zeilennummern bei jeder Scroll-Bewegung neu zeichnen (Maus, Tastatur, programmatisch)
        // und wenn die Suchleiste den sichtbaren Bereich verschiebt.
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.contentView.postsFrameChangedNotifications = true
        coordinator.observers = [NSView.boundsDidChangeNotification, NSView.frameDidChangeNotification].map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: scrollView.contentView,
                queue: .main
            ) { [weak lineNumberView] _ in
                MainActor.assumeIsolated {
                    lineNumberView?.needsDisplay = true
                }
            }
        }

        onTextViewReady?(textView)
        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }

        // Nur Änderungen von außen übernehmen (Öffnen, Zurücksetzen). Ein Vergleich mit
        // textView.string wäre falsch: Während einer Tottasten-Eingabe (` ^ ´ auf deutscher
        // Tastatur) enthält die Text View vorläufigen Text, der noch nicht im Binding steht.
        var needsHighlight = false
        if text != coordinator.syncedText {
            coordinator.syncedText = text
            if textView.string != text {
                let selection = textView.selectedRange()
                textView.unmarkText()
                textView.string = text
                let length = (text as NSString).length
                textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
                needsHighlight = true
            }
        }
        if coordinator.appliedTheme != theme || coordinator.appliedFontSize != fontSize {
            coordinator.applyStyle(to: textView)
            needsHighlight = true
        }
        if needsHighlight {
            coordinator.highlightNow()
            coordinator.lineNumberView?.needsDisplay = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: MarkdownEditor
        var textView: NSTextView?
        var lineNumberView: LineNumberView?
        var scrollView: NSScrollView?
        nonisolated(unsafe) var observers: [NSObjectProtocol] = []
        private var pendingHighlight: DispatchWorkItem?
        var appliedTheme: MarkdownEditorTheme?
        var appliedFontSize: CGFloat?
        /// Tokens des letzten Highlight-Durchlaufs (Grundlage für das inkrementelle Einfärben).
        private var lastTokens: [MarkdownToken]?
        /// Seit dem letzten Durchlauf geänderter Bereich (heutige Koordinaten) und Längenänderung.
        private var pendingEdit: (range: NSRange, delta: Int)?
        /// Text, der zuletzt zwischen Text View und Binding ausgetauscht wurde.
        var syncedText: String

        init(_ parent: MarkdownEditor) {
            self.parent = parent
            self.syncedText = parent.text
        }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            syncedText = textView.string
            parent.text = syncedText
            lineNumberView?.needsDisplay = true
        }

        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            recordEdit(editedRange, delta: delta)
            scheduleHighlight()
        }

        /// Verhindert Gedankenstriche überall und typografische Ersetzungen (Anführungszeichen,
        /// Textersetzungen, Autokorrektur) in Code-Blöcken und Inline-Code.
        func textView(_ textView: NSTextView, didCheckTextIn range: NSRange, types checkingTypes: NSTextCheckingTypes,
                      options: [NSSpellChecker.OptionKey: Any], results: [NSTextCheckingResult],
                      orthography: NSOrthography, wordCount: Int) -> [NSTextCheckingResult] {
            // Bindestrich-Folgen sind in Markdown Syntax (---, | --- |, Setext, Front Matter, Listen),
            // deshalb werden Gedankenstriche nirgends ersetzt – auch nicht im Fließtext.
            let results = results.filter { !$0.resultType.contains(.dash) }

            let substitutions: NSTextCheckingResult.CheckingType = [.quote, .replacement, .correction]
            func isSubstitution(_ result: NSTextCheckingResult) -> Bool {
                !result.resultType.intersection(substitutions).isEmpty
            }
            guard results.contains(where: isSubstitution) else { return results }

            // lastTokens kennt den gerade getippten Text noch nicht (Highlight folgt erst nach 20 ms).
            // Die Attribute dürfen hier nicht geändert werden, sonst verwirft die Text View
            // auch die erlaubten Ersetzungen – deshalb nur tokenisieren, nicht einfärben.
            let tokens: [MarkdownToken]
            if pendingEdit == nil, let lastTokens {
                tokens = lastTokens
            } else {
                tokens = MarkdownTokenizer.tokenize(textView.string)
            }
            let text = textView.string as NSString
            // Die Ranges der Ergebnisse sind relativ zum geprüften Bereich, nicht zum Dokument.
            return results.filter { result in
                !isSubstitution(result)
                    || !MarkdownTokenizer.isCode(at: range.location + result.range.location, in: text, tokens: tokens)
            }
        }

        /// Färbt den gesamten Text neu ein (Start, Theme- oder Schriftwechsel, Text von außen ersetzt).
        func highlightNow() {
            pendingHighlight?.cancel()
            pendingEdit = nil
            guard let storage = textView?.textStorage else { return }
            lastTokens = MarkdownHighlighter(theme: parent.theme, fontSize: parent.fontSize).apply(to: storage)
        }

        /// Färbt nach Texteingaben nur die geänderten Zeilen neu ein.
        func highlightChanges() {
            pendingHighlight?.cancel()
            guard let storage = textView?.textStorage else { return }
            guard let previous = lastTokens, let edit = pendingEdit else {
                highlightNow()
                return
            }
            pendingEdit = nil
            lastTokens = MarkdownHighlighter(theme: parent.theme, fontSize: parent.fontSize)
                .apply(to: storage, previous: previous, edit: edit)
        }

        func scheduleHighlight() {
            pendingHighlight?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.highlightChanges() }
            pendingHighlight = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: work)
        }

        /// Fasst mehrere Änderungen zwischen zwei Durchläufen zu einem Bereich zusammen.
        private func recordEdit(_ range: NSRange, delta: Int) {
            guard let pending = pendingEdit else {
                pendingEdit = (range, delta)
                return
            }
            // Bisherigen Bereich in die Koordinaten nach dieser Änderung übertragen.
            let oldEditEnd = NSMaxRange(range) - delta
            var shifted = pending.range
            if NSMaxRange(shifted) <= range.location {
                // liegt vor der Änderung – unverändert
            } else if shifted.location >= oldEditEnd {
                shifted.location += delta
            } else {
                let start = min(shifted.location, range.location)
                let end = max(NSMaxRange(shifted) + delta, NSMaxRange(range))
                shifted = NSRange(location: start, length: max(0, end - start))
            }
            pendingEdit = (NSUnionRange(shifted, range), pending.delta + delta)
        }

        /// Setzt alle themenabhängigen Eigenschaften der Text View und der Zeilennummern.
        func applyStyle(to textView: NSTextView) {
            let theme = parent.theme
            let font = NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)
            textView.backgroundColor = theme.backgroundColor
            textView.insertionPointColor = theme.insertionPointColor
            textView.selectedTextAttributes = [.backgroundColor: theme.selectionColor]
            textView.typingAttributes = [.font: font, .foregroundColor: theme.textColor]
            lineNumberView?.backgroundColor = theme.gutterBackgroundColor
            lineNumberView?.textColor = theme.gutterTextColor
            lineNumberView?.fontSize = parent.fontSize
            appliedTheme = theme
            appliedFontSize = parent.fontSize
        }
    }
}

final class LineNumberView: NSView {
    weak var textView: NSTextView?
    weak var scrollView: NSScrollView?
    let separatorWidth: CGFloat

    var backgroundColor: NSColor = .controlBackgroundColor {
        didSet { needsDisplay = true }
    }
    var textColor: NSColor = .secondaryLabelColor {
        didSet { needsDisplay = true }
    }
    var fontSize: CGFloat = 14 {
        didSet { needsDisplay = true }
    }

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

    // Oben links als Ursprung – entspricht dem Koordinatensystem der Text View.
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        dirtyRect.fill()

        NSColor.separatorColor.setStroke()
        let separatorPath = NSBezierPath()
        let separatorX = bounds.maxX - separatorWidth / 2.0
        separatorPath.move(to: NSPoint(x: separatorX, y: bounds.minY))
        separatorPath.line(to: NSPoint(x: separatorX, y: bounds.maxY))
        separatorPath.lineWidth = separatorWidth
        separatorPath.stroke()

        guard let textView,
              let scrollView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let storage = textView.textStorage
        else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: textColor
        ]
        let text = storage.string as NSString
        let visibleRect = scrollView.documentVisibleRect
        let origin = textView.textContainerOrigin
        let visibleContainerRect = visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)

        // Ist die Suchleiste eingeblendet, beginnt der Textbereich weiter unten:
        // Nummern nur neben dem sichtbaren Text zeichnen, nicht neben der Suchleiste.
        NSBezierPath.clip(convert(scrollView.contentView.frame, from: scrollView))

        func drawNumber(_ number: Int, in fragmentRect: NSRect) {
            let label = "\(number)" as NSString
            let size = label.size(withAttributes: attributes)
            let y = convert(NSPoint(x: 0, y: fragmentRect.minY + origin.y), from: textView).y
            label.draw(at: NSPoint(x: bounds.width - size.width - 10, y: y), withAttributes: attributes)
        }

        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleContainerRect, in: textContainer)
        if glyphRange.length > 0 {
            var lineNumber: Int? = nil
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, fragmentGlyphRange, _ in
                let charIndex = layoutManager.characterIndexForGlyph(at: fragmentGlyphRange.location)
                // Nummer der Zeile vor dem ersten sichtbaren Fragment – nur einmal zählen.
                var current = lineNumber ?? Self.countNewlines(in: text, upTo: charIndex)
                let startsLine = charIndex == 0 || text.character(at: charIndex - 1) == 0x0A
                if startsLine {
                    current += 1
                    drawNumber(current, in: rect)
                }
                lineNumber = current
            }
        }

        // Leere letzte Zeile nach einem abschließenden Zeilenumbruch (oder leeres Dokument).
        let extraRect = layoutManager.extraLineFragmentRect
        if extraRect.height > 0,
           text.length == 0 || text.character(at: text.length - 1) == 0x0A,
           extraRect.intersects(visibleContainerRect) {
            drawNumber(Self.countNewlines(in: text, upTo: text.length) + 1, in: extraRect)
        }
    }

    /// Anzahl der Zeilenumbrüche vor `index`.
    private static func countNewlines(in text: NSString, upTo index: Int) -> Int {
        var count = 0
        var buffer = [unichar](repeating: 0, count: 4096)
        var position = 0
        while position < index {
            let length = min(buffer.count, index - position)
            text.getCharacters(&buffer, range: NSRange(location: position, length: length))
            for i in 0..<length where buffer[i] == 0x0A {
                count += 1
            }
            position += length
        }
        return count
    }
}
