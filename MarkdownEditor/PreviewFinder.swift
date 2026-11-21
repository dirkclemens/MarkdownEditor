//
//  PreviewFinder.swift
//  MarkdownEditor
//
//  Suchen in der Vorschau. Die Treffer werden per JavaScript im gerenderten HTML gesucht
//  und mit der CSS Custom Highlight API markiert – das DOM bleibt dabei unverändert.
//

import AppKit
import SwiftUI
import WebKit

@MainActor
@Observable
final class PreviewFinder {
    /// Suchleiste über der Vorschau eingeblendet.
    var isVisible = false
    var query = "" {
        didSet { if query != oldValue { search() } }
    }
    var caseSensitive = false {
        didSet { if caseSensitive != oldValue { search() } }
    }
    private(set) var matchCount = 0
    /// Index des aktuellen Treffers, -1 ohne Treffer.
    private(set) var currentIndex = -1
    /// Wird erhöht, wenn das Suchfeld den Fokus bekommen soll.
    private(set) var focusRequest = 0

    @ObservationIgnored weak var webView: WKWebView?
    /// Das Suchfeld der Vorschau hat den Fokus.
    @ObservationIgnored var isFieldFocused = false

    var hasQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Menübefehl aus Bearbeiten › Suchen ausführen.
    func perform(_ action: NSTextFinder.Action) {
        switch action {
        case .nextMatch:
            isVisible && matchCount > 0 ? next() : show()
        case .previousMatch:
            isVisible && matchCount > 0 ? previous() : show()
        case .setSearchString:
            useSelection()
        case .hideFindInterface:
            hide()
        default:
            show()
        }
    }

    func show() {
        let wasVisible = isVisible
        isVisible = true
        focusRequest += 1
        if !wasVisible { search() }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        isFieldFocused = false
        evaluate("clear(); return { count: 0, index: -1 };")
        if let webView {
            webView.window?.makeFirstResponder(webView)
        }
    }

    func next() { step(1) }
    func previous() { step(-1) }

    /// Neu suchen; der aktuelle Treffer ist der erste im sichtbaren Bereich.
    func search() {
        guard isVisible else { return }
        guard hasQuery else {
            evaluate("clear(); return { count: 0, index: -1 };")
            return
        }
        evaluate("return search(query, caseSensitive, false);",
                 arguments: ["query": query, "caseSensitive": caseSensitive])
    }

    /// Nach einer Aktualisierung der Vorschau die Treffer neu markieren, ohne zu scrollen.
    func contentDidChange() {
        guard isVisible, hasQuery else { return }
        evaluate("return search(query, caseSensitive, true);",
                 arguments: ["query": query, "caseSensitive": caseSensitive])
    }

    private func step(_ delta: Int) {
        guard matchCount > 0 else { return }
        evaluate("return step(delta);", arguments: ["delta": delta])
    }

    /// Markierten Text der Vorschau als Suchbegriff übernehmen.
    private func useSelection() {
        guard let webView else { return }
        webView.callAsyncJavaScript("return window.getSelection().toString();",
                                    arguments: [:], in: nil, in: .defaultClient) { [weak self] result in
            guard let self else { return }
            let selection = (try? result.get()) as? String ?? ""
            let firstLine = selection.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            if !firstLine.isEmpty { self.query = firstLine }
            self.show()
        }
    }

    private func evaluate(_ body: String, arguments: [String: Any] = [:]) {
        guard let webView else {
            matchCount = 0
            currentIndex = -1
            return
        }
        webView.callAsyncJavaScript(Self.script + body, arguments: arguments,
                                    in: nil, in: .defaultClient) { [weak self] result in
            guard let self, case .success(let value) = result,
                  let state = value as? [String: Any]
            else { return }
            self.matchCount = (state["count"] as? NSNumber)?.intValue ?? 0
            self.currentIndex = (state["index"] as? NSNumber)?.intValue ?? -1
        }
    }

    /// Suchfunktionen; der Zustand bleibt zwischen den Aufrufen in `window.__mdFind` erhalten.
    private static let script = #"""
    const F = (window.__mdFind ??= { ranges: [], index: -1 });
    const BLOCKS = 'p, li, h1, h2, h3, h4, h5, h6, pre, blockquote, td, th, dt, dd, caption';

    function clear() {
      CSS.highlights.delete('md-find');
      CSS.highlights.delete('md-find-current');
      F.ranges = [];
      F.index = -1;
    }

    function collect(query, caseSensitive) {
      const root = document.getElementById('content');
      const parts = query.trim().split(/\s+/).filter(Boolean)
        .map(part => part.replace(/[\\^$.*+?()[\]{}|\/]/g, '\\$&'));
      if (!root || !parts.length) return [];
      // Leerraum im Suchbegriff passt auf beliebigen Leerraum (HTML bricht Zeilen um).
      const regex = new RegExp(parts.join('\\s+'), caseSensitive ? 'gu' : 'giu');

      // Text aller Textknoten; zwischen Blöcken ein Trenner, damit Treffer nicht über
      // Absatz- oder Zellgrenzen hinweg entstehen.
      const nodes = [];
      let text = '';
      let lastBlock;
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      while (walker.nextNode()) {
        const node = walker.currentNode;
        const block = node.parentElement?.closest(BLOCKS) ?? null;
        if (nodes.length && block !== lastBlock) text += '\u0000';
        lastBlock = block;
        nodes.push({ node, start: text.length });
        text += node.data;
      }

      function locate(offset, isEnd) {
        let low = 0, high = nodes.length - 1;
        while (low < high) {
          const mid = (low + high + 1) >> 1;
          if (isEnd ? nodes[mid].start < offset : nodes[mid].start <= offset) low = mid;
          else high = mid - 1;
        }
        return [nodes[low].node, offset - nodes[low].start];
      }

      const ranges = [];
      for (const match of text.matchAll(regex)) {
        if (!match[0].length) continue;
        const range = new Range();
        range.setStart(...locate(match.index, false));
        range.setEnd(...locate(match.index + match[0].length, true));
        ranges.push(range);
      }
      return ranges;
    }

    function reveal(range) {
      let rect = range.getBoundingClientRect();
      // Codeblöcke und Tabellen scrollen waagerecht.
      const box = range.startContainer.parentElement?.closest('pre, table');
      if (box) {
        const bounds = box.getBoundingClientRect();
        if (rect.left < bounds.left || rect.right > bounds.right) {
          box.scrollLeft += rect.left - bounds.left - bounds.width / 3;
          rect = range.getBoundingClientRect();
        }
      }
      if (rect.top < 0 || rect.bottom > innerHeight) {
        window.scrollBy(0, rect.top - innerHeight / 3);
      }
    }

    function paint(scroll) {
      CSS.highlights.set('md-find', new Highlight(...F.ranges));
      const current = F.ranges[F.index];
      if (current) {
        const highlight = new Highlight(current);
        highlight.priority = 1;
        CSS.highlights.set('md-find-current', highlight);
        if (scroll) reveal(current);
      } else {
        CSS.highlights.delete('md-find-current');
      }
      return { count: F.ranges.length, index: F.index };
    }

    function search(query, caseSensitive, keepPosition) {
      const previous = F.index;
      clear();
      F.ranges = collect(query, caseSensitive);
      if (!F.ranges.length) return paint(false);
      if (keepPosition) {
        F.index = Math.min(Math.max(previous, 0), F.ranges.length - 1);
        return paint(false);
      }
      F.index = F.ranges.findIndex(range => range.getBoundingClientRect().bottom > 0);
      if (F.index < 0) F.index = 0;
      return paint(true);
    }

    function step(delta) {
      const count = F.ranges.length;
      if (count) F.index = ((F.index + delta) % count + count) % count;
      return paint(true);
    }

    """#
}

/// Suchleiste über der Vorschau, im Stil der Suchleiste des Editors.
struct PreviewFindBar: View {
    @Bindable var finder: PreviewFinder
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $finder.query)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onKeyPress(.return, phases: .down) { press in
                        press.modifiers.contains(.shift) ? finder.previous() : finder.next()
                        return .handled
                    }
                    .onExitCommand { finder.hide() }
                if finder.hasQuery {
                    Text(status)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor)))

            ControlGroup {
                Button("Previous", systemImage: "chevron.left") { finder.previous() }
                    .help("Previous match (⇧⌘G)")
                Button("Next", systemImage: "chevron.right") { finder.next() }
                    .help("Next match (⌘G)")
            }
            .labelStyle(.iconOnly)
            .fixedSize()
            .disabled(finder.matchCount == 0)

            Toggle("Aa", isOn: $finder.caseSensitive)
                .toggleStyle(.button)
                .help("Match case")

            Button("Done") { finder.hide() }
        }
        .controlSize(.small)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.bar)
        .onAppear { fieldFocused = true }
        .onChange(of: finder.focusRequest) { fieldFocused = true }
        .onChange(of: fieldFocused) { finder.isFieldFocused = fieldFocused }
    }

    private var status: String {
        finder.matchCount == 0 ? "Not found" : "\(finder.currentIndex + 1) of \(finder.matchCount)"
    }
}
