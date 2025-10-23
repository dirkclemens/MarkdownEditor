//
//  MarkdownRenderer.swift
//  MarkdownEditor
//
//  Created by Dirk Clemens on 23.10.25.
//

import SwiftUI

struct MarkdownRenderer: View {

    let markdown: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                parseAndRender()
            }
            .padding()
        }
    }
    
    @ViewBuilder
    func parseAndRender() -> some View {
        let attributed = try! AttributedString(markdown: markdown)
        
        ForEach(Array(attributed.runs.enumerated()), id: \.offset) { index, run in
            let text = String(attributed[run.range].characters)
            
            if let intent = run.presentationIntent {
                let isCodeBlockRun = intent.components.contains { component in
                    if case .codeBlock = component.kind {
                        return true
                    }
                    return false
                }
                
                if isCodeBlockRun {
                    CodeBlockView(code: text)
                } else {
                    renderNonCodeRun(text: text, intent: intent)
                }
            } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(text)
            }
        }
    }
    
    @ViewBuilder
    func renderNonCodeRun(text: String, intent: PresentationIntent) -> some View {
        // Analysiere Intent AUSSERHALB des ViewBuilder
        let info = analyzeIntent(intent)
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !cleanText.isEmpty {
            if info.isInlineCode {
                InlineCodeView(code: cleanText)
            } else if info.isHeader {
                HeaderView(text: cleanText, level: info.headerLevel)
            } else if info.isList {
                ListItemView(text: cleanText, isOrdered: info.isOrdered, number: info.listNumber)
            } else {
                Text(cleanText)
            }
        }
    }
    
    // Hilfsfunktion zum Analysieren des Intent
    func analyzeIntent(_ intent: PresentationIntent) -> (isInlineCode: Bool, isHeader: Bool, headerLevel: Int, isList: Bool, isOrdered: Bool, listNumber: Int?) {
        var isInlineCode = false
        var isHeader = false
        var headerLevel = 0
        var isList = false
        var isOrdered = false
        var listNumber: Int?
        
        for component in intent.components {
            switch component.kind {
            case .codeBlock:
                isInlineCode = true
            case .header(let level):
                isHeader = true
                headerLevel = level
            case .listItem(let ordinal):
                isList = true
                listNumber = ordinal
            case .orderedList:
                isOrdered = true
            case .unorderedList:
                isOrdered = false
            default:
                break
            }
        }
        
        return (isInlineCode, isHeader, headerLevel, isList, isOrdered, listNumber)
    }
}

struct CodeBlockView: View {
    let code: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct InlineCodeView: View {
    let code: String
    
    var body: some View {
        Text(code)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(4)
    }
}

struct HeaderView: View {
    let text: String
    let level: Int
    
    var body: some View {
        switch level {
        case 1:
            Text(text).font(.largeTitle).bold()
        case 2:
            Text(text).font(.title).bold()
        case 3:
            Text(text).font(.title2).bold()
        case 4:
            Text(text).font(.title3).bold()
        default:
            Text(text).font(.headline)
        }
    }
}

struct ListItemView: View {
    let text: String
    let isOrdered: Bool
    let number: Int?
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isOrdered, let num = number {
                Text("\(num).")
                    .frame(width: 30, alignment: .trailing)
            } else {
                Text("•")
                    .frame(width: 30, alignment: .trailing)
            }
            
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    MarkdownRenderer(markdown: "")
}
