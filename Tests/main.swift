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
