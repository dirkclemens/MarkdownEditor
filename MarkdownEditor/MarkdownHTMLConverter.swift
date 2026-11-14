//
//  MarkdownHTMLConverter.swift
//  MarkdownEditor
//
//  Wandelt Markdown in HTML für die Vorschau um.
//  Unterstützt CommonMark-Grundsyntax und die Erweiterungen aus dem Cheat Sheet:
//  Tabellen, Aufgabenlisten, Fußnoten, Definitionslisten, Überschriften-IDs,
//  ~~durchgestrichen~~, ==markiert==, ~tief~, ^hoch^, :emoji: und nackte URLs.
//  Importiert bewusst nur Foundation, damit die Datei ohne Xcode testbar ist
//  (siehe Tests/run.sh).
//

import Foundation

struct MarkdownHTMLConverter {
    /// Liefert für ein Bildziel ohne Schema (relativer oder absoluter Pfad) eine ladbare
    /// Adresse, z. B. eine data:-URL. `nil` lässt das Ziel unverändert.
    var resolveImage: ((String) -> String?)?

    init(resolveImage: ((String) -> String?)? = nil) {
        self.resolveImage = resolveImage
    }

    func convert(_ markdown: String) -> String {
        let parser = MarkdownBlockParser()
        let blocks = parser.parse(MarkdownBlockParser.lines(of: markdown))
        let renderer = MarkdownHTMLRenderer(references: parser.references,
                                            footnotes: parser.footnotes,
                                            resolveImage: resolveImage)
        return renderer.render(blocks)
    }
}

// MARK: - Blockmodell

enum TableAlignment {
    case none, left, center, right
}

struct MarkdownListItem {
    /// nil: keine Aufgabe, sonst erledigt ja/nein.
    var task: Bool?
    var blocks: [MarkdownBlock]
}

struct MarkdownDefinition {
    var term: String
    var definitions: [String]
}

indirect enum MarkdownBlock {
    case heading(level: Int, text: String, id: String?)
    case paragraph(String)
    case code(info: String, text: String)
    case quote([MarkdownBlock])
    case list(ordered: Bool, start: Int, tight: Bool, items: [MarkdownListItem])
    case rule
    case table(header: [String], alignments: [TableAlignment], rows: [[String]])
    case html(String)
    case definitions([MarkdownDefinition])
}

// MARK: - Blockparser

final class MarkdownBlockParser {
    /// Linkreferenzen `[label]: url "titel"`, Schlüssel normalisiert (siehe `normalize`).
    var references: [String: (url: String, title: String?)] = [:]
    /// Fußnoten `[^label]: text`, Schlüssel normalisiert.
    var footnotes: [String: [MarkdownBlock]] = [:]

    /// Zerlegt den Text in Zeilen und ersetzt Tabs in der Einrückung durch Leerzeichen.
    static func lines(of text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return normalized.components(separatedBy: "\n").map { expandLeadingTabs($0) }
    }

    private static func expandLeadingTabs(_ line: String) -> String {
        guard line.contains("\t") else { return line }
        var result = ""
        var column = 0
        var index = line.startIndex
        while index < line.endIndex, line[index] == " " || line[index] == "\t" {
            if line[index] == "\t" {
                let width = 4 - column % 4
                result += String(repeating: " ", count: width)
                column += width
            } else {
                result += " "
                column += 1
            }
            index = line.index(after: index)
        }
        return result + line[index...]
    }

    static func normalize(_ label: String) -> String {
        label.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    func parse(_ lines: [String]) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if isBlank(line) {
                i += 1
                continue
            }
            if let fence = Self.fenceOpening(line) {
                blocks.append(parseFence(lines, &i, fence))
                continue
            }
            if indentation(of: line) >= 4 {
                blocks.append(parseIndentedCode(lines, &i))
                continue
            }
            if let heading = Self.atxHeading(line) {
                blocks.append(heading)
                i += 1
                continue
            }
            if Self.isRule(line) {
                blocks.append(.rule)
                i += 1
                continue
            }
            if Self.isQuote(line) {
                blocks.append(parseQuote(lines, &i))
                continue
            }
            if let footnote = Self.match(Self.footnoteDefinition, line) {
                parseFootnote(lines, &i, label: footnote[1], firstLine: footnote[2])
                continue
            }
            if let marker = Self.listMarker(line) {
                blocks.append(parseList(lines, &i, first: marker))
                continue
            }
            if Self.isHTMLBlockStart(line) {
                blocks.append(parseHTML(lines, &i))
                continue
            }
            if let table = parseTable(lines, &i) {
                blocks.append(table)
                continue
            }
            if let reference = Self.match(Self.referenceDefinition, line), !reference[1].hasPrefix("^") {
                let key = Self.normalize(reference[1])
                if references[key] == nil {
                    let title = [reference[3], reference[4], reference[5]].first { !$0.isEmpty }
                    references[key] = (reference[2], title)
                }
                i += 1
                continue
            }
            if i + 1 < lines.count, Self.isDefinitionLine(lines[i + 1]) {
                blocks.append(parseDefinitions(lines, &i))
                continue
            }
            blocks.append(parseParagraph(lines, &i))
        }
        return blocks
    }

    // MARK: Einzelne Blöcke

    private struct Fence {
        let indent: Int
        let character: Character
        let length: Int
        let info: String
    }

    private static func fenceOpening(_ line: String) -> Fence? {
        let indent = line.prefix { $0 == " " }.count
        guard indent <= 3 else { return nil }
        let rest = line.dropFirst(indent)
        guard let character = rest.first, character == "`" || character == "~" else { return nil }
        let length = rest.prefix { $0 == character }.count
        guard length >= 3 else { return nil }
        let info = rest.dropFirst(length).trimmingCharacters(in: .whitespaces)
        if character == "`" && info.contains("`") { return nil }
        return Fence(indent: indent, character: character, length: length, info: info)
    }

    private func parseFence(_ lines: [String], _ i: inout Int, _ fence: Fence) -> MarkdownBlock {
        var content: [String] = []
        i += 1
        while i < lines.count {
            let line = lines[i]
            let indent = line.prefix { $0 == " " }.count
            let rest = line.dropFirst(indent)
            if indent <= 3,
               rest.prefix(while: { $0 == fence.character }).count >= fence.length,
               rest.drop(while: { $0 == fence.character }).allSatisfy({ $0 == " " || $0 == "\t" }) {
                i += 1
                break
            }
            content.append(String(line.dropFirst(min(fence.indent, indent))))
            i += 1
        }
        let language = fence.info.split(separator: " ").first.map(String.init) ?? ""
        return .code(info: language, text: content.joined(separator: "\n"))
    }

    private func parseIndentedCode(_ lines: [String], _ i: inout Int) -> MarkdownBlock {
        var content: [String] = []
        while i < lines.count, isBlank(lines[i]) || indentation(of: lines[i]) >= 4 {
            content.append(String(lines[i].dropFirst(min(4, indentation(of: lines[i])))))
            i += 1
        }
        while content.last.map(isBlank) == true { content.removeLast() }
        return .code(info: "", text: content.joined(separator: "\n"))
    }

    private static func atxHeading(_ line: String) -> MarkdownBlock? {
        let indent = line.prefix { $0 == " " }.count
        guard indent <= 3 else { return nil }
        let rest = line.dropFirst(indent)
        let level = rest.prefix { $0 == "#" }.count
        guard (1...6).contains(level) else { return nil }
        let afterHashes = rest.dropFirst(level)
        guard afterHashes.isEmpty || afterHashes.first == " " || afterHashes.first == "\t" else { return nil }
        var text = afterHashes.trimmingCharacters(in: .whitespaces)
        // Schließende #-Folge entfernen („## Titel ##“)
        if let closing = text.range(of: #"(^|[ \t]+)#+[ \t]*$"#, options: .regularExpression) {
            text = String(text[..<closing.lowerBound])
        }
        var id: String?
        if let custom = text.range(of: #"[ \t]*\{#[A-Za-z0-9_:.\-]+\}$"#, options: .regularExpression) {
            let raw = text[custom].trimmingCharacters(in: .whitespaces)
            id = String(raw.dropFirst(2).dropLast())
            text = String(text[..<custom.lowerBound])
        }
        return .heading(level: level, text: text, id: id)
    }

    private static func isRule(_ line: String) -> Bool {
        line.range(of: #"^ {0,3}((\*[ \t]*){3,}|(-[ \t]*){3,}|(_[ \t]*){3,})$"#, options: .regularExpression) != nil
    }

    private static func isQuote(_ line: String) -> Bool {
        let indent = line.prefix { $0 == " " }.count
        return indent <= 3 && line.dropFirst(indent).first == ">"
    }

    private func parseQuote(_ lines: [String], _ i: inout Int) -> MarkdownBlock {
        var content: [String] = []
        var previousWasText = false
        while i < lines.count {
            let line = lines[i]
            if Self.isQuote(line) {
                var rest = line.drop { $0 == " " }.dropFirst()
                if rest.first == " " { rest = rest.dropFirst() }
                content.append(String(rest))
                previousWasText = !isBlank(String(rest)) && Self.fenceOpening(String(rest)) == nil
            } else if previousWasText && !isBlank(line) && !startsBlock(line) {
                content.append(line) // „lazy“ Fortsetzung eines Absatzes im Zitat
            } else {
                break
            }
            i += 1
        }
        return .quote(parse(content))
    }

    private struct ListMarker {
        let ordered: Bool
        let symbol: Character      // Aufzählungszeichen bzw. Trennzeichen . oder )
        let start: Int
        let contentIndent: Int
        let content: String
    }

    private static func listMarker(_ line: String) -> ListMarker? {
        let indent = line.prefix { $0 == " " }.count
        guard indent <= 3 else { return nil }
        let rest = line.dropFirst(indent)
        guard let first = rest.first else { return nil }

        let ordered: Bool
        let symbol: Character
        let start: Int
        let markerWidth: Int
        if first == "-" || first == "+" || first == "*" {
            ordered = false
            symbol = first
            start = 1
            markerWidth = 1
        } else {
            let digits = rest.prefix { $0.isASCII && $0.isNumber }
            guard (1...9).contains(digits.count),
                  let delimiter = rest.dropFirst(digits.count).first,
                  delimiter == "." || delimiter == ")"
            else { return nil }
            ordered = true
            symbol = delimiter
            start = Int(digits) ?? 1
            markerWidth = digits.count + 1
        }

        let afterMarker = rest.dropFirst(markerWidth)
        if afterMarker.trimmingCharacters(in: .whitespaces).isEmpty {
            return ListMarker(ordered: ordered, symbol: symbol, start: start,
                              contentIndent: indent + markerWidth + 1, content: "")
        }
        let spaces = afterMarker.prefix { $0 == " " }.count
        guard spaces >= 1 else { return nil }
        if spaces >= 5 {
            // Eingerückter Code direkt hinter dem Marker
            return ListMarker(ordered: ordered, symbol: symbol, start: start,
                              contentIndent: indent + markerWidth + 1,
                              content: String(afterMarker.dropFirst(1)))
        }
        return ListMarker(ordered: ordered, symbol: symbol, start: start,
                          contentIndent: indent + markerWidth + spaces,
                          content: String(afterMarker.dropFirst(spaces)))
    }

    private func parseList(_ lines: [String], _ i: inout Int, first: ListMarker) -> MarkdownBlock {
        var itemLines: [[String]] = []
        var current = [first.content]
        var contentIndent = first.contentIndent
        var loose = false
        var sawBlank = false
        var previousWasText = !first.content.isEmpty
        i += 1

        while i < lines.count {
            let line = lines[i]
            if isBlank(line) {
                current.append("")
                sawBlank = true
                previousWasText = false
                i += 1
                continue
            }
            let indent = indentation(of: line)
            if indent >= contentIndent {
                let stripped = String(line.dropFirst(contentIndent))
                current.append(stripped)
                previousWasText = Self.fenceOpening(stripped) == nil
                sawBlank = false
                i += 1
                continue
            }
            if !Self.isRule(line), let marker = Self.listMarker(line),
               marker.ordered == first.ordered, marker.symbol == first.symbol {
                itemLines.append(current)
                if sawBlank { loose = true }
                current = [marker.content]
                contentIndent = marker.contentIndent
                previousWasText = !marker.content.isEmpty
                sawBlank = false
                i += 1
                continue
            }
            if previousWasText && !sawBlank && !startsBlock(line) {
                current.append(line.trimmingCharacters(in: .whitespaces)) // „lazy“ Fortsetzung
                i += 1
                continue
            }
            break
        }
        itemLines.append(current)

        var items: [MarkdownListItem] = []
        for var linesOfItem in itemLines {
            while linesOfItem.count > 1, linesOfItem.last.map(isBlank) == true { linesOfItem.removeLast() }
            // Leerzeile vor weiterem Inhalt auf oberster Ebene des Eintrags: lockere Liste
            for (index, line) in linesOfItem.enumerated().dropFirst() where isBlank(linesOfItem[index - 1]) && !isBlank(line) {
                if indentation(of: line) == 0 { loose = true }
            }
            var task: Bool?
            if let firstLine = linesOfItem.first,
               let checkbox = firstLine.range(of: #"^\[[ xX]\]([ \t]|$)"#, options: .regularExpression) {
                task = firstLine[firstLine.index(after: firstLine.startIndex)] != " "
                linesOfItem[0] = String(firstLine[checkbox.upperBound...])
            }
            items.append(MarkdownListItem(task: task, blocks: parse(linesOfItem)))
        }
        return .list(ordered: first.ordered, start: first.start, tight: !loose, items: items)
    }

    private func parseFootnote(_ lines: [String], _ i: inout Int, label: String, firstLine: String) {
        var content = [firstLine]
        var previousWasText = !isBlank(firstLine)
        i += 1
        while i < lines.count {
            let line = lines[i]
            if isBlank(line) {
                // Gehört nur dazu, wenn danach eingerückter Inhalt folgt.
                var next = i + 1
                while next < lines.count, isBlank(lines[next]) { next += 1 }
                guard next < lines.count, indentation(of: lines[next]) >= 4 else { break }
                content.append("")
                previousWasText = false
            } else if indentation(of: line) >= 4 {
                content.append(String(line.dropFirst(4)))
                previousWasText = true
            } else if previousWasText && !startsBlock(line) && Self.match(Self.footnoteDefinition, line) == nil {
                content.append(line)
            } else {
                break
            }
            i += 1
        }
        let key = Self.normalize(label)
        if footnotes[key] == nil {
            footnotes[key] = parse(content)
        }
    }

    private static let htmlBlockTags = "address|article|aside|audio|blockquote|body|center|details|dialog|div|dl|dd|dt|fieldset|figcaption|figure|footer|form|h[1-6]|head|header|hr|html|iframe|img|li|main|nav|ol|p|picture|pre|script|section|source|style|summary|table|tbody|td|tfoot|th|thead|tr|ul|video"

    private static func isHTMLBlockStart(_ line: String) -> Bool {
        line.range(of: #"^ {0,3}<(!--|/?("# + htmlBlockTags + #")([\s/>]|$))"#,
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func parseHTML(_ lines: [String], _ i: inout Int) -> MarkdownBlock {
        var content: [String] = []
        while i < lines.count, !isBlank(lines[i]) {
            content.append(lines[i])
            i += 1
        }
        return .html(content.joined(separator: "\n"))
    }

    private static func isTableDelimiterRow(_ line: String) -> Bool {
        line.contains("-") && line.range(of: #"^ {0,3}\|?([ \t]*:?-+:?[ \t]*\|)*[ \t]*:?-+:?[ \t]*\|?[ \t]*$"#,
                                         options: .regularExpression) != nil
    }

    private func parseTable(_ lines: [String], _ i: inout Int) -> MarkdownBlock? {
        guard i + 1 < lines.count, lines[i].contains("|"), Self.isTableDelimiterRow(lines[i + 1]) else { return nil }
        let header = Self.tableCells(lines[i])
        let delimiters = Self.tableCells(lines[i + 1])
        guard header.count == delimiters.count else { return nil }

        let alignments: [TableAlignment] = delimiters.map { cell in
            switch (cell.hasPrefix(":"), cell.hasSuffix(":")) {
            case (true, true): return .center
            case (true, false): return .left
            case (false, true): return .right
            default: return .none
            }
        }
        var rows: [[String]] = []
        i += 2
        while i < lines.count, !isBlank(lines[i]), !startsBlock(lines[i]) {
            var cells = Self.tableCells(lines[i])
            if cells.count < header.count {
                cells += Array(repeating: "", count: header.count - cells.count)
            }
            rows.append(Array(cells.prefix(header.count)))
            i += 1
        }
        return .table(header: header, alignments: alignments, rows: rows)
    }

    /// Zerlegt eine Tabellenzeile an nicht maskierten `|` außerhalb von Code-Spans.
    static func tableCells(_ line: String) -> [String] {
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("|") { text.removeFirst() }
        if text.hasSuffix("|") && !text.hasSuffix("\\|") { text.removeLast() }

        var cells: [String] = []
        var cell = ""
        var inCode = 0
        var characters = Array(text)[...]
        while let character = characters.popFirst() {
            if character == "\\", characters.first == "|" {
                cell.append("|")
                characters.removeFirst()
            } else if character == "`" {
                var run = 1
                while characters.first == "`" { characters.removeFirst(); run += 1 }
                inCode = inCode == 0 ? run : (inCode == run ? 0 : inCode)
                cell += String(repeating: "`", count: run)
            } else if character == "|" && inCode == 0 {
                cells.append(cell.trimmingCharacters(in: .whitespaces))
                cell = ""
            } else {
                cell.append(character)
            }
        }
        cells.append(cell.trimmingCharacters(in: .whitespaces))
        return cells
    }

    private static func isDefinitionLine(_ line: String) -> Bool {
        line.range(of: #"^ {0,3}:[ \t]+\S"#, options: .regularExpression) != nil
    }

    private func parseDefinitions(_ lines: [String], _ i: inout Int) -> MarkdownBlock {
        var entries: [MarkdownDefinition] = []
        while i + 1 < lines.count, !isBlank(lines[i]), Self.isDefinitionLine(lines[i + 1]) {
            var entry = MarkdownDefinition(term: lines[i].trimmingCharacters(in: .whitespaces), definitions: [])
            i += 1
            while i < lines.count, Self.isDefinitionLine(lines[i]) {
                var text = String(lines[i].drop { $0 == " " }.dropFirst()).trimmingCharacters(in: .whitespaces)
                i += 1
                while i < lines.count, !isBlank(lines[i]), !Self.isDefinitionLine(lines[i]),
                      indentation(of: lines[i]) >= 2 {
                    text += "\n" + lines[i].trimmingCharacters(in: .whitespaces)
                    i += 1
                }
                entry.definitions.append(text)
            }
            entries.append(entry)
            // Weitere Begriffe nach Leerzeilen gehören zur selben Liste.
            var next = i
            while next < lines.count, isBlank(lines[next]) { next += 1 }
            if next + 1 < lines.count, Self.isDefinitionLine(lines[next + 1]) {
                i = next
            } else {
                break
            }
        }
        return .definitions(entries)
    }

    private func parseParagraph(_ lines: [String], _ i: inout Int) -> MarkdownBlock {
        var content = [String(lines[i].drop { $0 == " " })]
        i += 1
        while i < lines.count {
            let line = lines[i]
            if isBlank(line) { break }
            if line.range(of: #"^ {0,3}(=+|-+)[ \t]*$"#, options: .regularExpression) != nil {
                i += 1
                let level = line.contains("=") ? 1 : 2
                return .heading(level: level, text: content.joined(separator: "\n"), id: nil)
            }
            if startsBlock(line, interruptingParagraph: true) { break }
            if i + 1 < lines.count, Self.isDefinitionLine(lines[i + 1]) { break }
            if i + 1 < lines.count, line.contains("|"), Self.isTableDelimiterRow(lines[i + 1]) { break }
            content.append(line.drop { $0 == " " }.description)
            i += 1
        }
        var text = content.joined(separator: "\n")
        while text.last == " " || text.last == "\t" { text.removeLast() }
        return .paragraph(text)
    }

    // MARK: Hilfsfunktionen

    /// Beginnt mit dieser Zeile ein neuer Block (beendet Absätze und „lazy“ Fortsetzungen)?
    private func startsBlock(_ line: String, interruptingParagraph: Bool = false) -> Bool {
        if Self.fenceOpening(line) != nil || Self.atxHeading(line) != nil || Self.isRule(line)
            || Self.isQuote(line) || Self.isHTMLBlockStart(line) {
            return true
        }
        if let marker = Self.listMarker(line) {
            // Ein Absatz wird nur von nicht leeren Einträgen bzw. „1.“ unterbrochen.
            if interruptingParagraph {
                return !marker.content.isEmpty && (!marker.ordered || marker.start == 1)
            }
            return true
        }
        return false
    }

    private func isBlank(_ line: String) -> Bool {
        line.allSatisfy { $0 == " " || $0 == "\t" }
    }

    private func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    private static let footnoteDefinition = try! NSRegularExpression(pattern: #"^ {0,3}\[\^([^\]\s]+)\]:[ \t]?(.*)$"#)
    private static let referenceDefinition = try! NSRegularExpression(
        pattern: #"^ {0,3}\[([^\]]+)\]:[ \t]*<?([^\s>]+)>?(?:[ \t]+(?:"([^"]*)"|'([^']*)'|\(([^)]*)\)))?[ \t]*$"#)

    /// Liefert die Gruppen eines vollständigen Treffers (leere Strings für fehlende Gruppen).
    private static func match(_ regex: NSRegularExpression, _ line: String) -> [String]? {
        let ns = line as NSString
        guard let result = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<result.numberOfRanges).map { index in
            let range = result.range(at: index)
            return range.location == NSNotFound ? "" : ns.substring(with: range)
        }
    }
}

// MARK: - HTML-Ausgabe

final class MarkdownHTMLRenderer {
    private let references: [String: (url: String, title: String?)]
    private let footnoteDefinitions: [String: [MarkdownBlock]]
    private let resolveImage: ((String) -> String?)?
    /// Fußnoten in der Reihenfolge ihres ersten Verweises.
    private var footnoteOrder: [String] = []
    private var usedIDs: [String: Int] = [:]

    init(references: [String: (url: String, title: String?)],
         footnotes: [String: [MarkdownBlock]],
         resolveImage: ((String) -> String?)?) {
        self.references = references
        self.footnoteDefinitions = footnotes
        self.resolveImage = resolveImage
    }

    func render(_ blocks: [MarkdownBlock]) -> String {
        var html = renderBlocks(blocks, tight: false)

        guard !footnoteOrder.isEmpty else { return html }
        html += "<section class=\"footnotes\">\n<ol>\n"
        var index = 0
        while index < footnoteOrder.count { // Fußnoten können weitere Fußnoten referenzieren
            let number = index + 1
            let backref = "<a href=\"#fnref-\(number)\" class=\"footnote-backref\">↩︎</a>"
            var content = renderBlocks(footnoteDefinitions[footnoteOrder[index]] ?? [], tight: false)
            if content.hasSuffix("</p>\n") {
                content.removeLast(5)
                content += " \(backref)</p>\n"
            } else {
                content += backref + "\n"
            }
            html += "<li id=\"fn-\(number)\">\n\(content)</li>\n"
            index += 1
        }
        html += "</ol>\n</section>\n"
        return html
    }

    private func renderBlocks(_ blocks: [MarkdownBlock], tight: Bool) -> String {
        var html = ""
        for block in blocks {
            switch block {
            case .heading(let level, let text, let id):
                let content = inline(text)
                let anchor = uniqueID(id ?? slug(content))
                html += "<h\(level) id=\"\(escapeAttribute(anchor))\">\(content)</h\(level)>\n"
            case .paragraph(let text):
                html += tight ? inline(text) + "\n" : "<p>\(inline(text))</p>\n"
            case .code(let info, let text):
                let language = info.isEmpty ? "" : " class=\"language-\(escapeAttribute(info))\""
                let body = text.isEmpty ? "" : escape(text) + "\n"
                html += "<pre><code\(language)>\(body)</code></pre>\n"
            case .quote(let children):
                html += "<blockquote>\n\(renderBlocks(children, tight: false))</blockquote>\n"
            case .list(let ordered, let start, let tight, let items):
                html += renderList(ordered: ordered, start: start, tight: tight, items: items)
            case .rule:
                html += "<hr />\n"
            case .table(let header, let alignments, let rows):
                html += renderTable(header: header, alignments: alignments, rows: rows)
            case .html(let raw):
                html += raw + "\n"
            case .definitions(let entries):
                html += "<dl>\n"
                for entry in entries {
                    html += "<dt>\(inline(entry.term))</dt>\n"
                    for definition in entry.definitions {
                        html += "<dd>\(inline(definition))</dd>\n"
                    }
                }
                html += "</dl>\n"
            }
        }
        return html
    }

    private func renderList(ordered: Bool, start: Int, tight: Bool, items: [MarkdownListItem]) -> String {
        let tag = ordered ? "ol" : "ul"
        let isTaskList = items.contains { $0.task != nil }
        var attributes = ordered && start != 1 ? " start=\"\(start)\"" : ""
        if isTaskList { attributes += " class=\"task-list\"" }

        var html = "<\(tag)\(attributes)>\n"
        for item in items {
            var content = renderBlocks(item.blocks, tight: tight)
            if let done = item.task {
                let checkbox = "<input type=\"checkbox\" disabled\(done ? " checked" : "") /> "
                if content.hasPrefix("<p>") {
                    content.insert(contentsOf: checkbox, at: content.index(content.startIndex, offsetBy: 3))
                } else {
                    content = checkbox + content
                }
                html += "<li class=\"task-list-item\(done ? " done" : "")\">"
            } else {
                html += "<li>"
            }
            // Bei engen Listen den Zeilenumbruch hinter reinem Text entfernen.
            if tight, content.hasSuffix("\n"), !content.hasSuffix(">\n") {
                content.removeLast()
            }
            html += (content.hasPrefix("<") && !tight ? "\n" : "") + content + "</li>\n"
        }
        return html + "</\(tag)>\n"
    }

    private func renderTable(header: [String], alignments: [TableAlignment], rows: [[String]]) -> String {
        func cell(_ tag: String, _ text: String, _ column: Int) -> String {
            let style: String
            switch alignments[column] {
            case .none: style = ""
            case .left: style = " style=\"text-align: left\""
            case .center: style = " style=\"text-align: center\""
            case .right: style = " style=\"text-align: right\""
            }
            return "<\(tag)\(style)>\(inline(text))</\(tag)>"
        }
        var html = "<table>\n<thead>\n<tr>"
        html += header.enumerated().map { cell("th", $0.element, $0.offset) }.joined()
        html += "</tr>\n</thead>\n"
        if !rows.isEmpty {
            html += "<tbody>\n"
            for row in rows {
                html += "<tr>" + row.enumerated().map { cell("td", $0.element, $0.offset) }.joined() + "</tr>\n"
            }
            html += "</tbody>\n"
        }
        return html + "</table>\n"
    }

    // MARK: IDs

    private func slug(_ html: String) -> String {
        let text = Self.plainText(html).lowercased()
        var result = ""
        for character in text {
            if character.isLetter || character.isNumber || character == "_" || character == "-" {
                result.append(character)
            } else if character == " " {
                result.append("-")
            }
        }
        return result.isEmpty ? "section" : result
    }

    private func uniqueID(_ base: String) -> String {
        guard let count = usedIDs[base] else {
            usedIDs[base] = 0
            return base
        }
        var number = count + 1
        while usedIDs["\(base)-\(number)"] != nil { number += 1 }
        usedIDs[base] = number
        usedIDs["\(base)-\(number)"] = 0
        return "\(base)-\(number)"
    }

    /// Entfernt Tags und löst die von `escape` erzeugten Entities wieder auf.
    static func plainText(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    // MARK: Inline

    /// Ein Stück der Inline-Ausgabe; Begrenzer (`*`, `_`, `~`, `=`, `^`) werden erst
    /// nach dem Durchlauf zu Tags gepaart (Verfahren wie in CommonMark).
    private struct Piece {
        var html: String
        var delimiter: Character?
        var count = 0
        var originalCount = 0
        var canOpen = false
        var canClose = false
        var sourceStart = 0
        var sourceEnd = 0
        var openTags: [String] = []
        var closeTags: [String] = []
    }

    func inline(_ text: String, allowLinks: Bool = true) -> String {
        let c = Array(text)
        let n = c.count
        var pieces: [Piece] = []
        var p = 0

        func emit(_ html: String) {
            if let last = pieces.indices.last, pieces[last].delimiter == nil {
                pieces[last].html += html
            } else {
                pieces.append(Piece(html: html))
            }
        }
        func trimTrailingSpaces() -> Int {
            guard let last = pieces.indices.last, pieces[last].delimiter == nil else { return 0 }
            var removed = 0
            while pieces[last].html.last == " " {
                pieces[last].html.removeLast()
                removed += 1
            }
            return removed
        }

        while p < n {
            let ch = c[p]
            switch ch {
            case "\\":
                if p + 1 < n, c[p + 1] == "\n" {
                    _ = trimTrailingSpaces()
                    emit("<br />\n")
                    p += 2
                } else if p + 1 < n, c[p + 1].isASCII, c[p + 1].isPunctuation || c[p + 1].isSymbol {
                    emit(escape(String(c[p + 1])))
                    p += 2
                } else {
                    emit("\\")
                    p += 1
                }

            case "`":
                let run = c[p...].prefix { $0 == "`" }.count
                if let end = closingBackticks(c, from: p + run, length: run) {
                    var code = String(c[(p + run)..<end]).replacingOccurrences(of: "\n", with: " ")
                    if code.count >= 2, code.first == " ", code.last == " ", code.contains(where: { $0 != " " }) {
                        code = String(code.dropFirst().dropLast())
                    }
                    emit("<code>\(escape(code))</code>")
                    p = end + run
                } else {
                    emit(String(repeating: "`", count: run))
                    p += run
                }

            case "!" where p + 1 < n && c[p + 1] == "[":
                if case let (html, end)? = parseLink(c, at: p + 1, image: true) {
                    emit(html)
                    p = end
                } else {
                    emit("!")
                    p += 1
                }

            case "[":
                if case let (html, end)? = footnoteReference(c, at: p) {
                    emit(html)
                    p = end
                } else if allowLinks, case let (html, end)? = parseLink(c, at: p, image: false) {
                    emit(html)
                    p = end
                } else {
                    emit("[")
                    p += 1
                }

            case "<":
                if case let (html, end)? = autolinkOrHTML(c, at: p, allowLinks: allowLinks) {
                    emit(html)
                    p = end
                } else {
                    emit("&lt;")
                    p += 1
                }

            case "&":
                if let end = entityEnd(c, at: p) {
                    emit(String(c[p..<end]))
                    p = end
                } else {
                    emit("&amp;")
                    p += 1
                }

            case ":":
                if case let (emoji, end)? = emojiShortcode(c, at: p) {
                    emit(emoji)
                    p = end
                } else {
                    emit(":")
                    p += 1
                }

            case "\n":
                let spaces = trimTrailingSpaces()
                emit(spaces >= 2 ? "<br />\n" : "\n")
                p += 1
                while p < n, c[p] == " " { p += 1 }

            case "*", "_", "~", "=", "^":
                let run = c[p...].prefix { $0 == ch }.count
                let before: Character = p > 0 ? c[p - 1] : " "
                let after: Character = p + run < n ? c[p + run] : " "
                let leftFlanking = !after.isWhitespace
                    && (!isPunctuation(after) || before.isWhitespace || isPunctuation(before))
                let rightFlanking = !before.isWhitespace
                    && (!isPunctuation(before) || after.isWhitespace || isPunctuation(after))
                var piece = Piece(html: String(repeating: String(ch), count: run), delimiter: ch,
                                  count: run, originalCount: run, sourceStart: p, sourceEnd: p + run)
                if ch == "_" {
                    piece.canOpen = leftFlanking && (!rightFlanking || isPunctuation(before))
                    piece.canClose = rightFlanking && (!leftFlanking || isPunctuation(after))
                } else {
                    piece.canOpen = leftFlanking
                    piece.canClose = rightFlanking
                }
                if ch == "=" && run != 2 {
                    emit(String(repeating: "=", count: run))
                } else {
                    pieces.append(piece)
                }
                p += run

            default:
                if allowLinks, ch == "h" || ch == "w", p == 0 || !(c[p - 1].isLetter || c[p - 1].isNumber),
                   case let (html, end)? = bareURL(c, at: p) {
                    emit(html)
                    p = end
                } else {
                    emit(escape(String(ch)))
                    p += 1
                }
            }
        }

        processEmphasis(&pieces, source: c)
        return pieces.map { piece in
            guard piece.delimiter != nil else { return piece.html }
            return piece.closeTags.joined()
                + String(repeating: String(piece.delimiter!), count: piece.count)
                + piece.openTags.joined()
        }.joined()
    }

    private func processEmphasis(_ pieces: inout [Piece], source: [Character]) {
        for closer in pieces.indices where pieces[closer].delimiter != nil {
            while pieces[closer].canClose && pieces[closer].count > 0 {
                let character = pieces[closer].delimiter!
                var match: (opener: Int, size: Int, tag: String)?
                var opener = closer - 1
                while opener >= 0 {
                    let candidate = pieces[opener]
                    if candidate.delimiter == character, candidate.canOpen, candidate.count > 0,
                       case let (size, tag)? = pairing(candidate, pieces[closer], source: source) {
                        match = (opener, size, tag)
                        break
                    }
                    opener -= 1
                }
                guard let match else { break }
                pieces[match.opener].count -= match.size
                pieces[closer].count -= match.size
                pieces[match.opener].openTags.insert("<\(match.tag)>", at: 0)
                pieces[closer].closeTags.append("</\(match.tag)>")
                for between in (match.opener + 1)..<closer where pieces[between].delimiter != nil {
                    pieces[between].canOpen = false
                    pieces[between].canClose = false
                }
            }
        }
    }

    /// Größe und Tag einer Paarung oder nil, wenn Öffner und Schließer nicht zusammenpassen.
    private func pairing(_ opener: Piece, _ closer: Piece, source: [Character]) -> (Int, String)? {
        switch closer.delimiter {
        case "*", "_":
            if (opener.canClose || closer.canOpen),
               (opener.originalCount + closer.originalCount) % 3 == 0,
               !(opener.originalCount % 3 == 0 && closer.originalCount % 3 == 0) {
                return nil
            }
            return opener.count >= 2 && closer.count >= 2 ? (2, "strong") : (1, "em")
        case "~":
            guard opener.count == closer.count else { return nil }
            if closer.count == 2 { return (2, "del") }
            if closer.count == 1, isTight(source, opener, closer) { return (1, "sub") }
            return nil
        case "=":
            return opener.count == 2 && closer.count == 2 ? (2, "mark") : nil
        case "^":
            return opener.count == 1 && closer.count == 1 && isTight(source, opener, closer) ? (1, "sup") : nil
        default:
            return nil
        }
    }

    /// Hoch-/Tiefstellung nur ohne Leerraum dazwischen (H~2~O, X^2^).
    private func isTight(_ source: [Character], _ opener: Piece, _ closer: Piece) -> Bool {
        opener.sourceEnd < closer.sourceStart
            && !source[opener.sourceEnd..<closer.sourceStart].contains { $0.isWhitespace }
    }

    private func isPunctuation(_ character: Character) -> Bool {
        character.isPunctuation || character.isSymbol
    }

    private func closingBackticks(_ c: [Character], from start: Int, length: Int) -> Int? {
        var index = start
        while index < c.count {
            if c[index] == "`" {
                let run = c[index...].prefix { $0 == "`" }.count
                if run == length { return index }
                index += run
            } else {
                index += 1
            }
        }
        return nil
    }

    // MARK: Links und Bilder

    /// Index der zur `[` bei `start` passenden `]` (verschachtelte Klammern, Escapes, Code-Spans).
    private func closingBracket(_ c: [Character], from start: Int) -> Int? {
        var depth = 0
        var index = start
        while index < c.count {
            switch c[index] {
            case "\\":
                index += 2
                continue
            case "`":
                let run = c[index...].prefix { $0 == "`" }.count
                if let end = closingBackticks(c, from: index + run, length: run) {
                    index = end + run
                    continue
                }
                index += run
                continue
            case "[":
                depth += 1
            case "]":
                depth -= 1
                if depth == 0 { return index }
            default:
                break
            }
            index += 1
        }
        return nil
    }

    private func parseLink(_ c: [Character], at start: Int, image: Bool) -> (String, Int)? {
        guard let close = closingBracket(c, from: start) else { return nil }
        let label = String(c[(start + 1)..<close])
        var url: String
        var title: String?
        var end: Int

        if close + 1 < c.count, c[close + 1] == "(", let destination = inlineDestination(c, from: close + 2) {
            (url, title, end) = destination
        } else if close + 1 < c.count, c[close + 1] == "[",
                  let refClose = c[(close + 2)...].firstIndex(of: "]") {
            let refLabel = String(c[(close + 2)..<refClose])
            let key = MarkdownBlockParser.normalize(refLabel.isEmpty ? label : refLabel)
            guard let reference = references[key] else { return nil }
            (url, title, end) = (reference.url, reference.title, refClose + 1)
        } else if let reference = references[MarkdownBlockParser.normalize(label)] {
            (url, title, end) = (reference.url, reference.title, close + 1)
        } else {
            return nil
        }

        let titleAttribute = title.map { " title=\"\(escapeAttribute($0))\"" } ?? ""
        if image {
            if !hasScheme(url), let resolved = resolveImage?(url) {
                url = resolved
            }
            let alt = Self.plainText(inline(label, allowLinks: false))
            return ("<img src=\"\(escapeAttribute(url))\" alt=\"\(escapeAttribute(alt))\"\(titleAttribute) />", end)
        }
        return ("<a href=\"\(escapeAttribute(url))\"\(titleAttribute)>\(inline(label, allowLinks: false))</a>", end)
    }

    /// Liest `url "titel")` ab `start` (direkt hinter der öffnenden Klammer).
    private func inlineDestination(_ c: [Character], from start: Int) -> (String, String?, Int)? {
        var index = start
        func skipSpaces() { while index < c.count, c[index] == " " || c[index] == "\n" { index += 1 } }
        skipSpaces()

        var url = ""
        if index < c.count, c[index] == "<" {
            index += 1
            while index < c.count, c[index] != ">" {
                if c[index] == "\n" { return nil }
                url.append(c[index])
                index += 1
            }
            guard index < c.count else { return nil }
            index += 1
        } else {
            var depth = 0
            while index < c.count, !c[index].isWhitespace {
                let character = c[index]
                if character == "\\", index + 1 < c.count {
                    url.append(c[index + 1])
                    index += 2
                    continue
                }
                if character == "(" { depth += 1 }
                if character == ")" {
                    if depth == 0 { break }
                    depth -= 1
                }
                url.append(character)
                index += 1
            }
        }

        skipSpaces()
        var title: String?
        if index < c.count, let closing: Character = ["\"": "\"", "'": "'", "(": ")"][c[index]] {
            index += 1
            var value = ""
            while index < c.count, c[index] != closing {
                if c[index] == "\\", index + 1 < c.count { index += 1 }
                value.append(c[index])
                index += 1
            }
            guard index < c.count else { return nil }
            title = value
            index += 1
            skipSpaces()
        }
        guard index < c.count, c[index] == ")" else { return nil }
        return (url, title, index + 1)
    }

    private func footnoteReference(_ c: [Character], at start: Int) -> (String, Int)? {
        guard start + 2 < c.count, c[start + 1] == "^",
              let close = c[(start + 2)...].firstIndex(of: "]"), close > start + 2
        else { return nil }
        let key = MarkdownBlockParser.normalize(String(c[(start + 2)..<close]))
        guard footnoteDefinitions[key] != nil else { return nil }

        let number: Int
        let isFirst: Bool
        if let existing = footnoteOrder.firstIndex(of: key) {
            number = existing + 1
            isFirst = false
        } else {
            footnoteOrder.append(key)
            number = footnoteOrder.count
            isFirst = true
        }
        let id = isFirst ? " id=\"fnref-\(number)\"" : ""
        return ("<sup class=\"footnote-ref\"><a href=\"#fn-\(number)\"\(id)>\(number)</a></sup>", close + 1)
    }

    private static let autolinkURL = try! NSRegularExpression(pattern: #"^<([A-Za-z][A-Za-z0-9+.\-]{1,31}:[^\s<>]*)>"#)
    private static let autolinkEmail = try! NSRegularExpression(
        pattern: #"^<([A-Za-z0-9.!#$%&'*+/=?^_`{|}~\-]+@[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?)+)>"#)
    private static let inlineHTML = try! NSRegularExpression(pattern:
        #"^(?:<[A-Za-z][A-Za-z0-9\-]*(?:\s+[A-Za-z_:][\w:.\-]*(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)*\s*/?>|</[A-Za-z][A-Za-z0-9\-]*\s*>|<!--[\s\S]*?-->)"#)

    private func autolinkOrHTML(_ c: [Character], at start: Int, allowLinks: Bool) -> (String, Int)? {
        let candidate = String(c[start..<min(c.count, start + 2000)])
        let ns = candidate as NSString
        let range = NSRange(location: 0, length: ns.length)
        func length(of match: NSTextCheckingResult) -> Int { ns.substring(with: match.range).count }

        if allowLinks, let match = Self.autolinkURL.firstMatch(in: candidate, range: range) {
            let url = ns.substring(with: match.range(at: 1))
            return ("<a href=\"\(escapeAttribute(url))\">\(escape(url))</a>", start + length(of: match))
        }
        if allowLinks, let match = Self.autolinkEmail.firstMatch(in: candidate, range: range) {
            let address = ns.substring(with: match.range(at: 1))
            return ("<a href=\"mailto:\(escapeAttribute(address))\">\(escape(address))</a>", start + length(of: match))
        }
        if let match = Self.inlineHTML.firstMatch(in: candidate, range: range) {
            return (ns.substring(with: match.range), start + length(of: match))
        }
        return nil
    }

    private func bareURL(_ c: [Character], at start: Int) -> (String, Int)? {
        let prefixes = ["https://", "http://", "www."]
        let head = String(c[start..<min(c.count, start + 8)])
        guard let prefix = prefixes.first(where: { head.hasPrefix($0) }) else { return nil }

        var end = start
        while end < c.count, !c[end].isWhitespace, c[end] != "<" { end += 1 }
        // Satzzeichen am Ende gehören nicht zur URL, ebenso eine nicht geöffnete „)“.
        while end > start {
            let last = c[end - 1]
            if ".,:;!?*_~'\"".contains(last) {
                end -= 1
            } else if last == ")" {
                let slice = c[start..<end]
                if slice.filter({ $0 == ")" }).count > slice.filter({ $0 == "(" }).count { end -= 1 } else { break }
            } else {
                break
            }
        }
        guard end - start > prefix.count else { return nil }
        let text = String(c[start..<end])
        let href = prefix == "www." ? "http://" + text : text
        return ("<a href=\"\(escapeAttribute(href))\">\(escape(text))</a>", end)
    }

    private func entityEnd(_ c: [Character], at start: Int) -> Int? {
        var index = start + 1
        var name = ""
        while index < c.count, index - start <= 32, c[index] != ";" {
            name.append(c[index])
            index += 1
        }
        guard index < c.count, c[index] == ";",
              name.range(of: #"^(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[A-Za-z][A-Za-z0-9]{1,31})$"#,
                         options: .regularExpression) != nil
        else { return nil }
        return index + 1
    }

    private func emojiShortcode(_ c: [Character], at start: Int) -> (String, Int)? {
        var index = start + 1
        var name = ""
        while index < c.count, index - start <= 40,
              c[index].isASCII, c[index].isLetter || c[index].isNumber || "_+-".contains(c[index]) {
            name.append(c[index])
            index += 1
        }
        guard index < c.count, c[index] == ":", let emoji = MarkdownEmoji.shortcodes[name] else { return nil }
        return ("<span class=\"emoji\" title=\":\(name):\">\(emoji)</span>", index + 1)
    }

    private func hasScheme(_ url: String) -> Bool {
        url.range(of: #"^[A-Za-z][A-Za-z0-9+.\-]*:"#, options: .regularExpression) != nil
    }

    // MARK: Maskieren

    private func escape(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            default: result.append(character)
            }
        }
        return result
    }

    private func escapeAttribute(_ text: String) -> String {
        escape(text)
    }
}

// MARK: - Emoji

enum MarkdownEmoji {
    /// Gebräuchliche Kurzcodes (GitHub-Namen).
    static let shortcodes: [String: String] = [
        "smile": "😄", "smiley": "😃", "grinning": "😀", "grin": "😁", "laughing": "😆", "satisfied": "😆",
        "sweat_smile": "😅", "joy": "😂", "rofl": "🤣", "relaxed": "☺️", "blush": "😊", "innocent": "😇",
        "slightly_smiling_face": "🙂", "upside_down_face": "🙃", "wink": "😉", "relieved": "😌",
        "heart_eyes": "😍", "smiling_face_with_three_hearts": "🥰", "kissing_heart": "😘", "yum": "😋",
        "stuck_out_tongue": "😛", "stuck_out_tongue_winking_eye": "😜", "zany_face": "🤪", "nerd_face": "🤓",
        "sunglasses": "😎", "star_struck": "🤩", "partying_face": "🥳", "smirk": "😏", "unamused": "😒",
        "disappointed": "😞", "pensive": "😔", "worried": "😟", "confused": "😕", "slightly_frowning_face": "🙁",
        "persevere": "😣", "tired_face": "😫", "weary": "😩", "pleading_face": "🥺", "cry": "😢", "sob": "😭",
        "triumph": "😤", "angry": "😠", "rage": "😡", "exploding_head": "🤯", "flushed": "😳", "scream": "😱",
        "fearful": "😨", "cold_sweat": "😰", "sweat": "😓", "hugs": "🤗", "thinking": "🤔", "shushing_face": "🤫",
        "no_mouth": "😶", "neutral_face": "😐", "expressionless": "😑", "grimacing": "😬", "roll_eyes": "🙄",
        "hushed": "😯", "open_mouth": "😮", "astonished": "😲", "yawning_face": "🥱", "sleeping": "😴",
        "drooling_face": "🤤", "dizzy_face": "😵", "zipper_mouth_face": "🤐", "nauseated_face": "🤢",
        "vomiting_face": "🤮", "sneezing_face": "🤧", "mask": "😷", "money_mouth_face": "🤑", "cowboy_hat_face": "🤠",
        "smiling_imp": "😈", "clown_face": "🤡", "poop": "💩", "hankey": "💩", "ghost": "👻", "skull": "💀",
        "alien": "👽", "robot": "🤖", "smiley_cat": "😺", "heart_eyes_cat": "😻",
        "+1": "👍", "thumbsup": "👍", "-1": "👎", "thumbsdown": "👎", "pray": "🙏", "clap": "👏", "muscle": "💪",
        "eyes": "👀", "wave": "👋", "raised_hands": "🙌", "handshake": "🤝", "v": "✌️", "metal": "🤘",
        "ok_hand": "👌", "call_me_hand": "🤙", "raised_hand": "✋", "point_right": "👉", "point_left": "👈",
        "point_up": "☝️", "point_up_2": "👆", "point_down": "👇", "fist": "✊", "punch": "👊", "facepalm": "🤦",
        "shrug": "🤷", "brain": "🧠",
        "heart": "❤️", "orange_heart": "🧡", "yellow_heart": "💛", "green_heart": "💚", "blue_heart": "💙",
        "purple_heart": "💜", "black_heart": "🖤", "broken_heart": "💔", "sparkling_heart": "💖", "100": "💯",
        "fire": "🔥", "zap": "⚡", "star": "⭐", "star2": "🌟", "sparkles": "✨", "boom": "💥", "rainbow": "🌈",
        "sunny": "☀️", "cloud": "☁️", "umbrella": "☔", "snowflake": "❄️", "crescent_moon": "🌙", "earth_africa": "🌍",
        "unicorn": "🦄", "dog": "🐶", "cat": "🐱", "bug": "🐛", "bee": "🐝", "four_leaf_clover": "🍀",
        "maple_leaf": "🍁", "cherry_blossom": "🌸", "sunflower": "🌻", "rose": "🌹", "seedling": "🌱", "evergreen_tree": "🌲",
        "pizza": "🍕", "hamburger": "🍔", "fries": "🍟", "coffee": "☕", "beer": "🍺", "beers": "🍻", "wine_glass": "🍷",
        "cake": "🍰", "birthday": "🎂", "apple": "🍎", "banana": "🍌", "strawberry": "🍓", "cookie": "🍪", "doughnut": "🍩",
        "tada": "🎉", "confetti_ball": "🎊", "balloon": "🎈", "gift": "🎁", "trophy": "🏆", "medal_sports": "🏅",
        "soccer": "⚽", "musical_note": "🎵", "notes": "🎶", "microphone": "🎤", "headphones": "🎧", "camera": "📷",
        "movie_camera": "🎥", "art": "🎨", "video_game": "🎮",
        "rocket": "🚀", "car": "🚗", "airplane": "✈️", "ship": "🚢", "bike": "🚲", "house": "🏠", "office": "🏢",
        "computer": "💻", "keyboard": "⌨️", "iphone": "📱", "phone": "☎️", "email": "📧", "envelope": "✉️",
        "memo": "📝", "pencil": "📝", "pencil2": "✏️", "book": "📖", "books": "📚", "bookmark": "🔖", "calendar": "📆",
        "date": "📅", "clipboard": "📋", "pushpin": "📌", "paperclip": "📎", "scissors": "✂️", "file_folder": "📁",
        "chart_with_upwards_trend": "📈", "chart_with_downwards_trend": "📉", "bar_chart": "📊",
        "lock": "🔒", "unlock": "🔓", "key": "🔑", "hammer": "🔨", "wrench": "🔧", "gear": "⚙️", "link": "🔗",
        "mag": "🔍", "bulb": "💡", "bell": "🔔", "speech_balloon": "💬", "loudspeaker": "📢", "hourglass": "⌛",
        "alarm_clock": "⏰", "watch": "⌚", "moneybag": "💰", "dollar": "💵", "euro": "💶", "package": "📦",
        "white_check_mark": "✅", "heavy_check_mark": "✔️", "ballot_box_with_check": "☑️", "x": "❌",
        "negative_squared_cross_mark": "❎", "warning": "⚠️", "no_entry": "⛔", "no_entry_sign": "🚫",
        "question": "❓", "exclamation": "❗", "information_source": "ℹ️", "recycle": "♻️", "arrows_counterclockwise": "🔄",
        "arrow_right": "➡️", "arrow_left": "⬅️", "arrow_up": "⬆️", "arrow_down": "⬇️", "heavy_plus_sign": "➕",
        "heavy_minus_sign": "➖", "copyright": "©️", "registered": "®️", "tm": "™️", "new": "🆕", "free": "🆓",
        "red_circle": "🔴", "large_blue_circle": "🔵", "green_circle": "🟢", "yellow_circle": "🟡",
        "construction": "🚧", "rotating_light": "🚨", "checkered_flag": "🏁", "triangular_flag_on_post": "🚩",
        "de": "🇩🇪", "us": "🇺🇸", "gb": "🇬🇧", "eu": "🇪🇺"
    ]
}
