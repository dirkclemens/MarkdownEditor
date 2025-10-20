//
//  MarkdownEditorApp.swift
//  MarkdownEditor
//
//  Created by Dirk Clemens on 20.10.25.
//

import SwiftUI

@main
struct MarkdownEditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownEditorDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
