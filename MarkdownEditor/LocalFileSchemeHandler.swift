//
//  LocalFileSchemeHandler.swift
//  MarkdownEditor
//
//  Liefert lokale Bilder an die Vorschau. Die Seite wird mit einer Basis-URL im eigenen
//  Schema geladen (md-local:///Pfad/zum/Dokument.md); relative Verweise wie
//  `![](bild.png)` oder `<img src="./bild.png">` landen damit hier und werden aus dem
//  Dateisystem gelesen. Mit loadHTMLString und einer file:-Basis-URL dürfte die
//  WKWebView keine lokalen Dateien laden.
//

import Foundation
import UniformTypeIdentifiers
import WebKit

final class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "md-local"

    /// Basis-URL für ein Dokument; ohne Speicherort (neues Dokument) nur absolute Pfade.
    static func baseURL(for documentURL: URL?) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.path = documentURL?.standardizedFileURL.path ?? "/"
        return components.url ?? URL(string: "\(scheme):///")!
    }

    /// Datei-URL zu einer URL im eigenen Schema (z. B. für angeklickte Links).
    static func fileURL(for url: URL) -> URL? {
        guard url.scheme == scheme else { return nil }
        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? url.path
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    /// Laufende Anfragen; nach `stop` darf eine Anfrage nicht mehr beantwortet werden.
    private var activeTasks = Set<ObjectIdentifier>()

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let id = ObjectIdentifier(urlSchemeTask)
        activeTasks.insert(id)
        guard let url = urlSchemeTask.request.url, let fileURL = Self.fileURL(for: url) else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            activeTasks.remove(id)
            return
        }
        Task {
            // Lesen außerhalb des Main Thread – große Bilder sollen das Tippen nicht bremsen.
            let result = await Task.detached { Self.load(fileURL) }.value
            guard activeTasks.remove(id) != nil else { return }
            switch result {
            case .success(let (data, mimeType)):
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
                    "Content-Type": mimeType,
                    "Content-Length": String(data.count),
                    // Bild wurde evtl. geändert – beim nächsten Rendern neu laden.
                    "Cache-Control": "no-cache"
                ])!
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            case .failure(let error):
                urlSchemeTask.didFailWithError(error)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        activeTasks.remove(ObjectIdentifier(urlSchemeTask))
    }

    /// Nur Bilder ausliefern: Das Dokument kann beliebige Pfade nennen, die Vorschau soll
    /// darüber aber keine anderen Dateien lesen.
    nonisolated private static func load(_ fileURL: URL) -> Result<(Data, String), URLError> {
        guard let type = UTType(filenameExtension: fileURL.pathExtension), type.conforms(to: .image),
              let mimeType = type.preferredMIMEType
        else { return .failure(URLError(.unsupportedURL)) }
        guard let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size <= 50_000_000,
              let data = try? Data(contentsOf: fileURL)
        else { return .failure(URLError(.fileDoesNotExist)) }
        return .success((data, mimeType))
    }
}
