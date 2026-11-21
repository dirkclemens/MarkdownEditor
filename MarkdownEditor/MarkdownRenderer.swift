//
//  MarkdownRenderer.swift
//  MarkdownEditor
//
//  Vorschau: wandelt Markdown mit MarkdownHTMLConverter in HTML um und zeigt es
//  in einer WKWebView an. Farben und Schriftgröße kommen aus dem Editor-Theme.
//

import AppKit
import SwiftUI
import WebKit
import MarkdownEditorKit

struct MarkdownRenderer: NSViewRepresentable {
    let markdown: String
    let theme: MarkdownEditorTheme
    var fontSize: CGFloat = 16
    /// Speicherort des Dokuments: Basis für relative Links und Bilder.
    var documentURL: URL? = nil
    /// Suche in der Vorschau; markiert die Treffer nach jeder Aktualisierung neu.
    var finder: PreviewFinder? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PreviewWebView {
        let configuration = WKWebViewConfiguration()
        // Skripte aus dem Dokument laufen nicht; die App selbst darf weiterhin JavaScript ausführen.
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = PreviewWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        let coordinator = context.coordinator
        webView.onAppearanceChange = { [weak coordinator] in
            coordinator?.refreshStyle()
        }
        webView.onCancel = { [weak finder] in
            guard let finder, finder.isVisible else { return false }
            finder.hide()
            return true
        }
        finder?.webView = webView
        coordinator.webView = webView
        coordinator.finder = finder
        coordinator.update(markdown: markdown, theme: theme, fontSize: fontSize, documentURL: documentURL)
        return webView
    }

    func updateNSView(_ webView: PreviewWebView, context: Context) {
        context.coordinator.update(markdown: markdown, theme: theme, fontSize: fontSize, documentURL: documentURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: PreviewWebView?
        weak var finder: PreviewFinder?
        private var markdown: String?
        private var theme: MarkdownEditorTheme?
        private var fontSize: CGFloat = 0
        private var documentURL: URL?
        private var html = ""
        /// Seite ist geladen; Änderungen werden per JavaScript eingesetzt (Scrollposition bleibt).
        private var isLoaded = false
        /// Ausstehende Aktualisierung des Inhalts. Beim Tippen (Editor und Vorschau
        /// nebeneinander) werden schnelle Änderungen zu einer Umwandlung zusammengefasst.
        private var contentUpdate: Task<Void, Never>?
        /// Dauer der letzten Umwandlung; große Dokumente werden seltener aktualisiert.
        private var conversionTime: Duration = .zero

        func update(markdown: String, theme: MarkdownEditorTheme, fontSize: CGFloat, documentURL: URL?) {
            let contentChanged = markdown != self.markdown || documentURL != self.documentURL
            let styleChanged = theme != self.theme || fontSize != self.fontSize
            guard contentChanged || styleChanged else { return }

            self.markdown = markdown
            self.theme = theme
            self.fontSize = fontSize
            self.documentURL = documentURL

            guard let webView else { return }
            webView.underPageBackgroundColor = theme.backgroundColor
            guard isLoaded else {
                if contentChanged { convert() }
                loadPage()
                return
            }
            if styleChanged {
                refreshStyle()
            }
            if contentChanged, contentUpdate == nil {
                let delay = min(max(.milliseconds(100), conversionTime * 3), .seconds(1))
                contentUpdate = Task { [weak self] in
                    try? await Task.sleep(for: delay)
                    guard let self, !Task.isCancelled else { return }
                    self.contentUpdate = nil
                    self.convert()
                    self.run("document.getElementById('content').innerHTML = html;", arguments: ["html": self.html])
                    self.finder?.contentDidChange()
                }
            }
        }

        /// Wandelt den aktuellen Markdown-Text in HTML um.
        private func convert() {
            contentUpdate?.cancel()
            contentUpdate = nil
            guard let markdown else { return }
            let start = ContinuousClock.now
            html = MarkdownHTMLConverter(resolveImage: { [documentURL] in
                Self.inlineImage($0, relativeTo: documentURL)
            }).convert(markdown)
            conversionTime = ContinuousClock.now - start
        }

        /// Farben neu berechnen, z. B. wenn macOS zwischen hell und dunkel wechselt
        /// (das Light-Theme nutzt dynamische Systemfarben).
        func refreshStyle() {
            guard isLoaded else { return }
            run("document.getElementById('theme').textContent = css;", arguments: ["css": css()])
        }

        private func run(_ script: String, arguments: [String: Any]) {
            webView?.callAsyncJavaScript(script, arguments: arguments, in: nil, in: .defaultClient) { [weak self] result in
                if case .failure = result {
                    self?.loadPage()
                }
            }
        }

        private func loadPage() {
            guard let webView else { return }
            isLoaded = false
            let page = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <style id="theme">\(css())</style>
            <style>\(Self.baseCSS)</style>
            </head>
            <body>
            <article id="content">\(html)</article>
            </body>
            </html>
            """
            webView.loadHTMLString(page, baseURL: documentURL)
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            // Beim ersten Laden hing die View evtl. noch nicht im Fenster; die Farben
            // wurden dann für die falsche Darstellung (hell/dunkel) berechnet.
            refreshStyle()
            finder?.contentDidChange()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url
            else {
                decisionHandler(.allow)
                return
            }
            // Sprungmarken innerhalb des Dokuments (Fußnoten, Überschriften) in der Vorschau öffnen.
            if url.fragment != nil, Self.withoutFragment(url) == webView.url.map({ Self.withoutFragment($0) }) {
                decisionHandler(.allow)
                return
            }
            // Alle anderen Links im Standardprogramm öffnen (Browser, Mail, Finder).
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }

        private static func withoutFragment(_ url: URL) -> String {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.fragment = nil
            return components?.string ?? url.absoluteString
        }

        // MARK: Bilder

        nonisolated private static let imageTypes = [
            "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif",
            "webp": "image/webp", "svg": "image/svg+xml", "bmp": "image/bmp", "ico": "image/x-icon",
            "tif": "image/tiff", "tiff": "image/tiff", "heic": "image/heic"
        ]

        /// Lokale Bilder als data:-URL einbetten. Die Web-Inhalte selbst dürfen keine
        /// Dateien lesen; ohne Zugriffsrecht der App (Sandbox) bleibt das Ziel unverändert.
        nonisolated private static func inlineImage(_ path: String, relativeTo documentURL: URL?) -> String? {
            let decoded = path.removingPercentEncoding ?? path
            let url: URL
            if decoded.hasPrefix("/") {
                url = URL(fileURLWithPath: decoded)
            } else if let directory = documentURL?.deletingLastPathComponent() {
                url = directory.appendingPathComponent(decoded)
            } else {
                return nil
            }
            guard let type = imageTypes[url.pathExtension.lowercased()],
                  let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size <= 20_000_000,
                  let data = try? Data(contentsOf: url)
            else { return nil }
            return "data:\(type);base64,\(data.base64EncodedString())"
        }

        // MARK: CSS

        /// Theme-Farben als CSS-Variablen, aufgelöst für die aktuelle Darstellung (hell/dunkel).
        private func css() -> String {
            guard let theme else { return "" }
            var result = ""
            let appearance = webView?.effectiveAppearance ?? NSApp.effectiveAppearance
            appearance.performAsCurrentDrawingAppearance {
                let headers = (0..<6).map { index in
                    theme.headerColors.isEmpty ? theme.textColor : theme.headerColors[min(index, theme.headerColors.count - 1)]
                }
                let stripe = theme.codeBackgroundColor.blended(withFraction: 0.5, of: theme.backgroundColor)
                    ?? theme.codeBackgroundColor
                let variables: [(String, NSColor)] = [
                    ("bg", theme.backgroundColor), ("text", theme.textColor), ("muted", theme.markupColor),
                    ("h1", headers[0]), ("h2", headers[1]), ("h3", headers[2]),
                    ("h4", headers[3]), ("h5", headers[4]), ("h6", headers[5]),
                    ("bold", theme.boldColor), ("italic", theme.italicColor), ("strike", theme.strikethroughColor),
                    ("code", theme.codeColor), ("code-bg", theme.codeBackgroundColor), ("stripe", stripe),
                    ("quote", theme.blockquoteColor), ("quote-bar", theme.blockquoteSymbolColor),
                    ("table", theme.tableColor), ("link", theme.linkColor), ("list", theme.listColor),
                    ("rule", theme.horizontalRuleColor), ("mark", theme.highlightBackgroundColor),
                    ("footnote", theme.footnoteColor), ("selection", theme.selectionColor),
                    ("image", theme.imageColor)
                ]
                let isDark = Self.luminance(theme.backgroundColor) < 0.5
                result = ":root {\n  color-scheme: \(isDark ? "dark" : "light");\n  --font-size: \(Int(fontSize))px;\n"
                for (name, color) in variables {
                    result += "  --\(name): \(Self.cssColor(color));\n"
                }
                result += "}\n"
            }
            return result
        }

        private static func cssColor(_ color: NSColor) -> String {
            guard let rgb = color.usingColorSpace(.sRGB) else { return "inherit" }
            func channel(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
            return "rgba(\(channel(rgb.redComponent)), \(channel(rgb.greenComponent)), \(channel(rgb.blueComponent)), \(String(format: "%.3f", rgb.alphaComponent)))"
        }

        private static func luminance(_ color: NSColor) -> CGFloat {
            guard let rgb = color.usingColorSpace(.sRGB) else { return 1 }
            return 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
        }

        private static let baseCSS = """
        html { background: var(--bg); }
        body {
          margin: 0; padding: 24px 32px 48px;
          color: var(--text); background: var(--bg);
          font: var(--font-size)/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
          -webkit-font-smoothing: antialiased; overflow-wrap: break-word;
        }
        #content { max-width: 860px; margin: 0 auto; }
        #content > :first-child { margin-top: 0; }
        ::selection { background: var(--selection); }

        h1, h2, h3, h4, h5, h6 { margin: 1.4em 0 0.6em; line-height: 1.25; font-weight: 600; }
        h1 { font-size: 2em; color: var(--h1); padding-bottom: .3em; border-bottom: 1px solid var(--rule); }
        h2 { font-size: 1.5em; color: var(--h2); padding-bottom: .3em; border-bottom: 1px solid var(--rule); }
        h3 { font-size: 1.25em; color: var(--h3); }
        h4 { font-size: 1em; color: var(--h4); }
        h5 { font-size: .875em; color: var(--h5); }
        h6 { font-size: .85em; color: var(--h6); }

        p, ul, ol, dl, table, pre, blockquote { margin: 0 0 1em; }
        a { color: var(--link); text-decoration: none; }
        a:hover { text-decoration: underline; }
        strong { color: var(--bold); font-weight: 600; }
        em { color: var(--italic); }
        del { color: var(--strike); }
        mark { background: var(--mark); color: inherit; border-radius: 3px; padding: 0 .15em; }
        sub, sup { line-height: 0; }

        code, pre { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: .875em; }
        code { color: var(--code); background: var(--code-bg); padding: .15em .35em; border-radius: 4px; }
        pre { background: var(--code-bg); padding: 12px 16px; border-radius: 8px; overflow-x: auto; line-height: 1.45; }
        pre code { background: none; padding: 0; font-size: 1em; border-radius: 0; }

        blockquote { margin-left: 0; padding: 0 1em; color: var(--quote); border-left: 4px solid var(--quote-bar); }
        blockquote > :last-child { margin-bottom: 0; }

        ul, ol { padding-left: 2em; }
        li + li { margin-top: .25em; }
        li > ul, li > ol { margin: .25em 0 0; }
        li > p { margin: .5em 0; }
        li::marker { color: var(--list); }
        .task-list-item { list-style: none; }
        .task-list-item input { margin: 0 .5em 0 -1.5em; vertical-align: middle; accent-color: var(--list); }
        .task-list-item.done { color: var(--muted); }

        hr { height: 2px; border: 0; background: var(--rule); margin: 1.5em 0; }

        table { border-collapse: collapse; display: block; width: max-content; max-width: 100%; overflow-x: auto; }
        th, td { border: 1px solid var(--table); padding: 6px 13px; }
        th { font-weight: 600; background: var(--code-bg); }
        tbody tr:nth-child(2n) td { background: var(--stripe); }

        img { max-width: 100%; }
        img:not([src^="data:"]) { color: var(--image); }

        dt { font-weight: 600; margin-top: .5em; }
        dd { margin: 0 0 .5em 1.5em; }

        .footnote-ref a, .footnote-backref { color: var(--footnote); }
        .footnotes { font-size: .875em; color: var(--muted); border-top: 1px solid var(--rule); margin-top: 2em; padding-top: 1em; }
        .footnotes li > p { margin: .25em 0; }

        ::highlight(md-find) { background-color: rgba(255, 214, 0, .4); }
        ::highlight(md-find-current) { background-color: rgb(255, 190, 0); color: #000; }
        """
    }
}

final class PreviewWebView: WKWebView {
    var onAppearanceChange: (() -> Void)?
    /// Escape: gibt `true` zurück, wenn die Taste verarbeitet wurde (Suchleiste geschlossen).
    var onCancel: (() -> Bool)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, onCancel?() == true { return }
        super.keyDown(with: event)
    }
}

#Preview {
    MarkdownRenderer(markdown: "# Vorschau\n\nText mit **fett** und `code`.", theme: lightTheme)
}
