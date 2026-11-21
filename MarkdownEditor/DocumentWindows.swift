//
//  DocumentWindows.swift
//  MarkdownEditor
//
//  Merkt sich die offenen Dokumentfenster und beendet die App, wenn das letzte
//  geschlossen wird (abschaltbar in den Einstellungen). Einstellungen und
//  About-Fenster zählen nicht mit.
//

import AppKit
import SwiftUI

enum DocumentWindows {
    private static var observers: [ObjectIdentifier: NSObjectProtocol] = [:]

    static func register(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        guard observers[id] == nil else { return }
        observers[id] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { windowWillClose(id) }
        }
    }

    private static func windowWillClose(_ id: ObjectIdentifier) {
        if let observer = observers.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(observer)
        }
        guard observers.isEmpty,
              UserDefaults.standard.bool(forKey: SettingsKey.quitWhenLastDocumentClosed)
        else { return }
        // Erst nach dem Schließen beenden; ein inzwischen geöffnetes Dokument verhindert es.
        DispatchQueue.main.async {
            if observers.isEmpty { NSApp.terminate(nil) }
        }
    }
}

/// Meldet das Fenster, in dem ein Dokument angezeigt wird.
struct DocumentWindowReporter: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ReporterView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ReporterView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { DocumentWindows.register(window) }
        }
    }
}
