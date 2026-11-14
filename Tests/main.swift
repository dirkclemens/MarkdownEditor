//
//  main.swift
//  Tests für MarkdownTokenizer – ausführen mit ./Tests/run.sh
//

import Foundation

var failures = 0
var passed = 0

/// Ein Token als (Art, Textausschnitt), z. B. ("heading1", "H1").
typealias Pair = (kind: String, text: String)

/// Erwartetes Token. `text == nil` bedeutet: nur die Art wird verglichen.
struct Expected {
    let kind: String
    let text: String?
}

func t(_ kind: String, _ text: String) -> Expected { Expected(kind: kind, text: text) }
func k(_ kind: String) -> Expected { Expected(kind: kind, text: nil) }

func name(_ kind: MarkdownTokenKind) -> String {
    if case .heading(let level) = kind { return "heading\(level)" }
    return "\(kind)"
}

func pairs(_ input: String) -> [Pair] {
    let ns = input as NSString
    return MarkdownTokenizer.tokenize(input).map { (name($0.kind), ns.substring(with: $0.range)) }
}

func describe(_ list: [Pair]) -> String {
    list.isEmpty ? "(keine Tokens)" : list.map { "\($0.kind)(\"\($0.text)\")" }.joined(separator: ", ")
}

func describe(_ list: [Expected]) -> String {
    list.isEmpty ? "(keine Tokens)" : list.map { e in e.text.map { "\(e.kind)(\"\($0)\")" } ?? e.kind }.joined(separator: ", ")
}

func matches(_ pair: Pair, _ expected: Expected) -> Bool {
    pair.kind == expected.kind && (expected.text == nil || expected.text == pair.text)
}

func report(_ ok: Bool, _ input: String, expected: String, actual: [Pair], line: Int) {
    if ok {
        passed += 1
    } else {
        failures += 1
        print("FEHLER (Zeile \(line))")
        print("  Eingabe:  \(input.debugDescription)")
        print("  Erwartet: \(expected)")
        print("  Ist:      \(describe(actual))")
    }
}

/// Genau diese Tokens in dieser Reihenfolge.
func expectExact(_ input: String, _ expected: [Expected], line: Int = #line) {
    let actual = pairs(input)
    let ok = actual.count == expected.count && zip(actual, expected).allSatisfy { matches($0, $1) }
    report(ok, input, expected: "genau: " + describe(expected), actual: actual, line: line)
}

/// Die genannten Tokens kommen vor, die ausgeschlossenen Arten nicht.
func expectContains(_ input: String, _ expected: [Expected], excluding: [String] = [], line: Int = #line) {
    let actual = pairs(input)
    let containsAll = expected.allSatisfy { e in actual.contains { matches($0, e) } }
    let containsNone = !actual.contains { excluding.contains($0.kind) }
    let suffix = excluding.isEmpty ? "" : "; ohne " + excluding.joined(separator: ", ")
    report(containsAll && containsNone, input, expected: "enthält: " + describe(expected) + suffix, actual: actual, line: line)
}

func expectNone(_ input: String, line: Int = #line) {
    expectExact(input, [], line: line)
}

/// Zeilennummer (1-basiert) eines Tokens.
func lineNumber(of token: MarkdownToken, in text: NSString) -> Int {
    var count = 1
    for i in 0..<token.range.location where text.character(at: i) == 0x0A { count += 1 }
    return count
}

// MARK: - Überschriften

expectExact("# H1", [t("markup", "#"), t("heading1", "H1")])
expectExact("### My Great Heading {#custom-id}",
            [t("markup", "###"), t("heading3", "My Great Heading"), t("headingID", "{#custom-id}")])
expectExact("#\ntext", [t("markup", "#")])
expectNone("#hashtag")
expectContains("Title\n=====", [t("heading1", "Title"), t("markup", "=====")])
expectContains("Subtitle\n---", [t("heading2", "Subtitle"), t("markup", "---")], excluding: ["horizontalRule"])
expectContains("# Titel mit **fett**", [t("heading1", "Titel mit **fett**"), t("bold", "fett")])

// MARK: - Hervorhebung

expectExact("**bold text**", [t("markup", "**"), t("bold", "bold text"), t("markup", "**")])
expectExact("*italicized text*", [t("markup", "*"), t("italic", "italicized text"), t("markup", "*")])
expectExact("***both***", [t("markup", "***"), t("boldItalic", "both"), t("markup", "***")])
expectContains("__bold__ and _ital_", [t("bold", "bold"), t("italic", "ital")])
expectNone("snake_case_name")
expectNone("2 * 3 * 4")
expectExact("* item with *emph* word",
            [t("listMarker", "*"), t("markup", "*"), t("italic", "emph"), t("markup", "*")])
expectContains("use `a*b` and `c*d` here", [t("inlineCode", "a*b"), t("inlineCode", "c*d")], excluding: ["italic"])
expectExact("a \\*not italic\\* b", [t("markup", "\\*"), t("markup", "\\*")])
expectExact("~~The world is flat.~~",
            [t("markup", "~~"), t("strikethrough", "The world is flat."), t("markup", "~~")])
expectExact("these ==very important words==.",
            [t("markup", "=="), t("highlight", "very important words"), t("markup", "==")])
expectExact("H~2~O", [t("markup", "~"), t("subscriptText", "2"), t("markup", "~")])
expectExact("X^2^", [t("markup", "^"), t("superscriptText", "2"), t("markup", "^")])
expectContains("*kursiv mit **fett** darin*", [t("italic", "kursiv mit **fett** darin"), t("bold", "fett")])
expectContains("``code mit ` Backtick``", [t("inlineCode", "code mit ` Backtick")])

// MARK: - Zitat und Listen

expectExact("> quote with **bold**",
            [t("blockquoteMarker", "> "), t("blockquote", "quote with **bold**"),
             t("markup", "**"), t("bold", "bold"), t("markup", "**")])
expectExact("1. First item", [t("listMarker", "1.")])
expectExact("- [x] done", [t("listMarker", "-"), t("taskDone", "[x]")])
expectExact("- [ ] open", [t("listMarker", "-"), t("taskOpen", "[ ]")])
expectExact("- item\n    - nested", [t("listMarker", "-"), t("listMarker", "-")])
expectExact("\n---", [t("horizontalRule", "---")])
expectExact("term\n: definition", [t("definitionMarker", ":")])

// MARK: - Links, Bilder, Fußnoten

expectExact("[Markdown Guide](https://www.markdownguide.org)",
            [t("markup", "["), t("linkText", "Markdown Guide"), t("markup", "]("),
             t("linkURL", "https://www.markdownguide.org"), t("markup", ")")])
expectExact("![alt text](https://x.de/tux.png)",
            [t("imageMarker", "!"), t("markup", "["), t("imageAlt", "alt text"), t("markup", "]("),
             t("imageURL", "https://x.de/tux.png"), t("markup", ")")])
expectContains("[a](https://x.de/a_(b))", [t("linkURL", "https://x.de/a_(b)")])
expectContains("<https://x.de> and https://y.de.", [t("linkURL", "https://x.de"), t("linkURL", "https://y.de")])
expectExact("Here's a footnote. [^1]", [t("footnote", "[^1]")])
expectExact("[^1]: This is the footnote.", [t("footnote", "[^1]:")])
expectExact("That is so funny! :joy:", [t("emoji", ":joy:")])
expectNone("at 10:30:45")
expectContains("[text][ref]", [t("linkText", "text"), t("linkURL", "ref")])
expectContains("[ref]: https://x.de", [t("linkText", "ref"), t("linkURL", "https://x.de")])
expectContains("<div>html</div>", [t("htmlTag", "<div>"), t("htmlTag", "</div>")])
expectContains("Mail an <name@example.com>", [t("linkURL", "name@example.com")])

// MARK: - Tabellen

do {
    let input = "| Syntax | Description |\n| --- | --- |\n| Header | Title |"
    let ns = input as NSString
    let tokens = MarkdownTokenizer.tokenize(input)
    let byLine = Dictionary(grouping: tokens) { lineNumber(of: $0, in: ns) }
    func kinds(_ line: Int) -> [String] { (byLine[line] ?? []).map { name($0.kind) } }
    func texts(_ line: Int, _ kind: String) -> [String] {
        (byLine[line] ?? []).filter { name($0.kind) == kind }.map { ns.substring(with: $0.range) }
    }
    let line1OK = kinds(1).filter { $0 == "tablePipe" }.count == 3
        && texts(1, "tableHeader") == ["Syntax", "Description"]
    let line2OK = kinds(2) == ["tableSeparator"] && texts(2, "tableSeparator") == ["| --- | --- |"]
    let line3OK = kinds(3).filter { $0 == "tablePipe" }.count == 3 && !kinds(3).contains("tableHeader")
    report(line1OK && line2OK && line3OK, input,
           expected: "Z1: 3 tablePipe + tableHeader(Syntax, Description); Z2: 1 tableSeparator; Z3: 3 tablePipe, kein tableHeader",
           actual: pairs(input), line: #line)
}
expectNone("prose with a | pipe")

// MARK: - Code

expectExact("```\n- item | x\n> quote [l](u) ~~s~~\n# no heading\n```",
            [k("codeFence"), k("codeBlock"), k("codeBlock"), k("codeBlock"), k("codeFence")])
expectExact("```swift\nlet a = 1\n\nunclosed",
            [t("codeFence", "```"), t("codeInfo", "swift"), t("codeBlock", "let a = 1"), t("codeBlock", "unclosed")])
expectExact("~~~\ncode\n~~~", [t("codeFence", "~~~"), t("codeBlock", "code"), t("codeFence", "~~~")])
expectExact("\n    indented code", [t("codeBlock", "    indented code")])
expectExact("````\n```\n````", [t("codeFence", "````"), t("codeBlock", "```"), t("codeFence", "````")])
expectContains("Absatz\r\n# Überschrift\r\n", [t("heading1", "Überschrift")])

// MARK: - Code-Kontext (keine typografischen Ersetzungen)

/// `|` markiert die geprüfte Position und wird vor dem Tokenisieren entfernt.
func expectCode(_ marked: String, _ expected: Bool, line: Int = #line) {
    let position = (marked as NSString).range(of: "|").location
    let input = marked.replacingOccurrences(of: "|", with: "")
    let actual = MarkdownTokenizer.isCode(at: position, in: input as NSString, tokens: MarkdownTokenizer.tokenize(input))
    report(actual == expected, marked, expected: "isCode = \(expected)", actual: [("isCode", "\(actual)")], line: line)
}

expectCode("```\nprint(|\"x\")\n```", true)
expectCode("```swift\n|\"", true)
expectCode("```\nx\n```\n|\"t\"", false)
expectCode("text\n\n    |\"x\"", true)
expectCode("call `f(|\"", true)
expectCode("a `b` c |\"", false)
expectCode("a ``b` |\"", true)
expectCode("a \\`b |\"", false)
expectCode("say |\"hi\"", false)

// MARK: - HTML-Konverter

func expectHTML(_ input: String, _ expected: String, line: Int = #line) {
    let actual = MarkdownHTMLConverter().convert(input)
    if actual == expected {
        passed += 1
    } else {
        failures += 1
        print("FEHLER (Zeile \(line))")
        print("  Eingabe:  \(input.debugDescription)")
        print("  Erwartet: \(expected.debugDescription)")
        print("  Ist:      \(actual.debugDescription)")
    }
}

// Überschriften
expectHTML("# H1", "<h1 id=\"h1\">H1</h1>\n")
expectHTML("## Zwei ##", "<h2 id=\"zwei\">Zwei</h2>\n")
expectHTML("### My Great Heading {#custom-id}", "<h3 id=\"custom-id\">My Great Heading</h3>\n")
expectHTML("Titel\n=====", "<h1 id=\"titel\">Titel</h1>\n")
expectHTML("Sub\n---", "<h2 id=\"sub\">Sub</h2>\n")
expectHTML("# A\n# A", "<h1 id=\"a\">A</h1>\n<h1 id=\"a-1\">A</h1>\n")
expectHTML("#hashtag", "<p>#hashtag</p>\n")

// Absätze und Zeilenumbrüche
expectHTML("a\nb\n\nc", "<p>a\nb</p>\n<p>c</p>\n")
expectHTML("a  \nb", "<p>a<br />\nb</p>\n")
expectHTML("a\\\nb", "<p>a<br />\nb</p>\n")

// Hervorhebung
expectHTML("**bold** *it* ***both***", "<p><strong>bold</strong> <em>it</em> <em><strong>both</strong></em></p>\n")
expectHTML("*kursiv mit **fett** darin*", "<p><em>kursiv mit <strong>fett</strong> darin</em></p>\n")
expectHTML("snake_case_name und 2 * 3 * 4", "<p>snake_case_name und 2 * 3 * 4</p>\n")
expectHTML("__a__ _b_", "<p><strong>a</strong> <em>b</em></p>\n")
expectHTML("~~weg~~ ==mark== H~2~O X^2^", "<p><del>weg</del> <mark>mark</mark> H<sub>2</sub>O X<sup>2</sup></p>\n")
expectHTML("a ~b c~ d", "<p>a ~b c~ d</p>\n")
expectHTML("\\*kein\\* <b>", "<p>*kein* <b></p>\n")
expectHTML("`a < b` und ``x ` y``", "<p><code>a &lt; b</code> und <code>x ` y</code></p>\n")
expectHTML("Tom & Jerry &copy;", "<p>Tom &amp; Jerry &copy;</p>\n")

// Links und Bilder
expectHTML("[Guide](https://x.de \"Titel\")", "<p><a href=\"https://x.de\" title=\"Titel\">Guide</a></p>\n")
expectHTML("[a](https://x.de/a_(b))", "<p><a href=\"https://x.de/a_(b)\">a</a></p>\n")
expectHTML("![alt *text*](tux.png)", "<p><img src=\"tux.png\" alt=\"alt text\" /></p>\n")
expectHTML("[text][ref]\n\n[ref]: https://x.de", "<p><a href=\"https://x.de\">text</a></p>\n")
expectHTML("[Ref]\n\n[ref]: https://x.de 'T'", "<p><a href=\"https://x.de\" title=\"T\">Ref</a></p>\n")
expectHTML("<https://x.de> und <a@b.de>", "<p><a href=\"https://x.de\">https://x.de</a> und <a href=\"mailto:a@b.de\">a@b.de</a></p>\n")
expectHTML("siehe https://x.de/a.", "<p>siehe <a href=\"https://x.de/a\">https://x.de/a</a>.</p>\n")
expectHTML("[kein Link]", "<p>[kein Link]</p>\n")
expectHTML("So lustig! :joy: 10:30:45", "<p>So lustig! <span class=\"emoji\" title=\":joy:\">😂</span> 10:30:45</p>\n")
expectHTML("[link mit https://x.de](https://y.de)", "<p><a href=\"https://y.de\">link mit https://x.de</a></p>\n")
do {
    let converter = MarkdownHTMLConverter(resolveImage: { $0 == "bild.png" ? "data:image/png;base64,AA==" : nil })
    let actual = converter.convert("![b](bild.png) ![c](https://x.de/c.png)")
    let expected = "<p><img src=\"data:image/png;base64,AA==\" alt=\"b\" /> <img src=\"https://x.de/c.png\" alt=\"c\" /></p>\n"
    report(actual == expected, "resolveImage", expected: expected, actual: [("html", actual)], line: #line)
}

// Blöcke
expectHTML("> zitat\nweiter\n> > tief", "<blockquote>\n<p>zitat\nweiter</p>\n<blockquote>\n<p>tief</p>\n</blockquote>\n</blockquote>\n")
expectHTML("---", "<hr />\n")
expectHTML("* * *", "<hr />\n")
expectHTML("```swift\nlet a = \"<b>\"\n```", "<pre><code class=\"language-swift\">let a = &quot;&lt;b&gt;&quot;\n</code></pre>\n")
expectHTML("```\nunclosed", "<pre><code>unclosed\n</code></pre>\n")
expectHTML("text\n\n    code\n    more", "<p>text</p>\n<pre><code>code\nmore\n</code></pre>\n")
expectHTML("<div>\n*roh*\n</div>", "<div>\n*roh*\n</div>\n")

// Listen
expectHTML("- a\n- b", "<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n")
expectHTML("3. a\n4. b", "<ol start=\"3\">\n<li>a</li>\n<li>b</li>\n</ol>\n")
expectHTML("- a\n\n- b", "<ul>\n<li>\n<p>a</p>\n</li>\n<li>\n<p>b</p>\n</li>\n</ul>\n")
expectHTML("- a\n    - b\n- c", "<ul>\n<li>a\n<ul>\n<li>b</li>\n</ul>\n</li>\n<li>c</li>\n</ul>\n")
expectHTML("1. a\n   - b", "<ol>\n<li>a\n<ul>\n<li>b</li>\n</ul>\n</li>\n</ol>\n")
expectHTML("- [x] done\n- [ ] open",
           "<ul class=\"task-list\">\n<li class=\"task-list-item done\"><input type=\"checkbox\" disabled checked /> done</li>\n<li class=\"task-list-item\"><input type=\"checkbox\" disabled /> open</li>\n</ul>\n")
expectHTML("- a\n- b\n\nAbsatz", "<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n<p>Absatz</p>\n")
expectHTML("- a\n* b", "<ul>\n<li>a</li>\n</ul>\n<ul>\n<li>b</li>\n</ul>\n")
expectHTML("Text\n- a", "<p>Text</p>\n<ul>\n<li>a</li>\n</ul>\n")
expectHTML("Jahr\n2024. war gut", "<p>Jahr\n2024. war gut</p>\n")

// Tabellen
expectHTML("| A | B |\n| :-- | --: |\n| 1 | `x|y` |\n| 2 |",
           "<table>\n<thead>\n<tr><th style=\"text-align: left\">A</th><th style=\"text-align: right\">B</th></tr>\n</thead>\n<tbody>\n<tr><td style=\"text-align: left\">1</td><td style=\"text-align: right\"><code>x|y</code></td></tr>\n<tr><td style=\"text-align: left\">2</td><td style=\"text-align: right\"></td></tr>\n</tbody>\n</table>\n")
expectHTML("prosa mit | pipe", "<p>prosa mit | pipe</p>\n")

// Fußnoten und Definitionslisten
expectHTML("Satz.[^1]\n\n[^1]: Die Fußnote.",
           "<p>Satz.<sup class=\"footnote-ref\"><a href=\"#fn-1\" id=\"fnref-1\">1</a></sup></p>\n<section class=\"footnotes\">\n<ol>\n<li id=\"fn-1\">\n<p>Die Fußnote. <a href=\"#fnref-1\" class=\"footnote-backref\">↩︎</a></p>\n</li>\n</ol>\n</section>\n")
expectHTML("Ohne[^x]", "<p>Ohne[^x]</p>\n")
expectHTML("term\n: definition\n: zweite", "<dl>\n<dt>term</dt>\n<dd>definition</dd>\n<dd>zweite</dd>\n</dl>\n")

// MARK: - Cheat Sheet

do {
    let path = "markdown-cheat-sheet.md"
    if let input = try? String(contentsOfFile: path, encoding: .utf8) {
        let ns = input as NSString
        let tokens = MarkdownTokenizer.tokenize(input)
        let invalid = tokens.filter { $0.range.location < 0 || NSMaxRange($0.range) > ns.length || $0.range.length <= 0 }
        report(invalid.isEmpty && !tokens.isEmpty, path, expected: "alle Ranges gültig",
               actual: invalid.map { (name($0.kind), "\($0.range)") }, line: #line)

        // Ersten Fenced Code Block suchen statt fester Zeilennummern (die Datei wird bearbeitet).
        let lines = input.components(separatedBy: "\n")
        let fenceLines = lines.indices.filter { lines[$0].hasPrefix("```") }.prefix(2).map { $0 + 1 }
        if fenceLines.count == 2 {
            let block = fenceLines[0]...fenceLines[1]
            let nonEmpty = block.filter { !lines[$0 - 1].trimmingCharacters(in: .whitespaces).isEmpty }.count
            let inFence = tokens.filter { block.contains(lineNumber(of: $0, in: ns)) }
            let foreign = inFence.filter { $0.kind != .codeFence && $0.kind != .codeBlock }
            report(foreign.isEmpty && inFence.count == nonEmpty, path,
                   expected: "Zeilen \(block.lowerBound)–\(block.upperBound): nur codeFence/codeBlock (\(nonEmpty) Tokens)",
                   actual: inFence.map { (name($0.kind), ns.substring(with: $0.range)) }, line: #line)
        } else {
            report(false, path, expected: "Fenced Code Block vorhanden", actual: [], line: #line)
        }
    } else {
        report(false, path, expected: "Datei lesbar", actual: [], line: #line)
    }
}

// MARK: - Ergebnis

if failures > 0 {
    print("\(failures) Test(s) fehlgeschlagen, \(passed) bestanden")
    exit(1)
}
print("Alle Tests bestanden (\(passed))")
