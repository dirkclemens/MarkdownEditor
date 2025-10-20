//
//  ContentView.swift
//  MarkdownEditor
//
//  Created by Dirk Clemens on 20.10.25.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownEditorDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(MarkdownEditorDocument()))
}
