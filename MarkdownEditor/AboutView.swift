//
//  AboutView.swift
//  MarkdownEditor
//
//  Fenster „Über Markdown Editor“.
//

import SwiftUI
import MarkdownEditorKit

struct AboutView: View {
    private static let repositoryURL = URL(string: "https://github.com/dirkclemens/MarkdownEditor")!

    private let info = Bundle.main.infoDictionary ?? [:]

    private var appName: String {
        info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? "Markdown Editor"
    }

    private var version: String {
        let version = info["CFBundleShortVersionString"] as? String ?? "–"
        let build = info["CFBundleVersion"] as? String
        return build.map { "Version \(version) (\($0))" } ?? "Version \(version)"
    }

    private var copyright: String? {
        (info["NSHumanReadableCopyright"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                .padding(.bottom, 14)

            Text(appName)
                .font(.system(size: 26, weight: .semibold))
            Text(version)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, 2)

            Text("A fast, native Markdown editor for macOS – with live preview, syntax highlighting and themes.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            HStack(spacing: 8) {
                Feature(title: "Live Preview", systemImage: "rectangle.split.2x1")
                Feature(title: "Highlighting", systemImage: "paintbrush")
                Feature(title: "\(MarkdownEditorTheme.builtInThemes.count) Themes", systemImage: "swatchpalette")
            }
            .padding(.top, 20)

            Link(destination: Self.repositoryURL) {
                Label("Source Code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.top, 22)

            VStack(spacing: 2) {
                if let copyright { Text(copyright) }
                Text("Released under the MIT License.")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.top, 18)
        }
        .padding(.horizontal, 36)
        .padding(.top, 40)
        .padding(.bottom, 28)
        .frame(width: 400)
        .background(alignment: .top) {
            LinearGradient(colors: [Color.accentColor.opacity(0.22), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 260)
                .ignoresSafeArea()
        }
        .containerBackground(.regularMaterial, for: .window)
        .gesture(WindowDragGesture())
    }
}

private struct Feature: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(height: 26)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
    }
}

/// Ersetzt „Über Markdown Editor“ im App-Menü durch das eigene Fenster.
struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Markdown Editor") { openWindow(id: AboutView.windowID) }
        }
    }
}

extension AboutView {
    static let windowID = "about"
}

#Preview {
    AboutView()
}
