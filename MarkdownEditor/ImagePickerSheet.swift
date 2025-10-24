import SwiftUI

struct ImagePickerSheet: View {
    var onSelect: (String) -> Void
    // Emojis grouped by type for better organization
    let emojiIcons: [String] = [
        // Faces & Emotions (full set)
        "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "🥲", "☺️", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🥸", "🤩", "🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺", "😢", "😭", "😤", "😠", "😡", "🤬", "🤯", "😳", "🥵", "🥶", "😱", "😨", "😰", "😥", "😓", "🤗", "🤔", "🤭", "🤫", "🤥", "😶", "😐", "🫥", "😑", "😬", "🫨", "🙄", "😯", "😦", "😧", "😮", "😲", "🥱", "😴", "🤤", "😪", "😵", "😵‍💫", "🤐", "🥴", "🤢", "🤮", "🤧", "😷", "🤒", "🤕", "🤑", "🤠", "😈", "👿", "👹", "👺", "🤡", "💩", "👻", "💀", "☠️", "👽", "👾", "🤖", "😺", "😸", "😹", "😻", "😼", "😽", "🙀", "😿", "😾",
        // Gestures & Body
        "👍", "🙏", "👏", "💪", "👀", "👋", "🙌", "🤝", "🤲", "✌️", "🤘", "👌", "🤙", "🖐️", "✋", "👉", "👈", "👆", "👇",
        // Travel & Places
        "🏖️", "🏔️", "🏜️", "🏕", "🏙️", "🌋", "🏝️", "🏞️", "🗽", "🗼", "🏰", "🏟️",
        // Animals & Nature
        "🦄", "🐶", "🐱", "🍀", "🍁", "🍂", "🍃", "🌸", "🌼", "🌻", "🌺",
        // Food
        "🍕", "🍔", "🍟", "🌭", "🍣", "🍩", "🍪", "🍎", "🍌", "🍉", "🍇", "🍓",
        // Objects
        "🧠", "💼", "📅", "⏰", "📚", "🖊️", "🗂️", "🔒", "🔑", "🔄",
        // Celebration & Activities
        "🎉", "🎊", "🎂", "🎈", "🏆", "🎶", "🎤", "🎧", "🎬", "📸",
        // Weather & Nature
        "🔥", "⚡", "🌟", "🌈", "☀️", "🌙", "☁️", "🌧️", "❄️",
        // Symbols
        "✅", "❌", "⚠️", "❤️", "💯", "💡", "ℹ️", "🔍", "🔔", "💬", "📢", "📌", "🚫", "♻️",
        // Numbers
        "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟",
        // Transport
        "🚀", "🚗", "✈️", "🚢", "🚲", "🛴", "🚁"
    ]
    // 8 columns for a dense grid
    let columns = Array(repeating: GridItem(.fixed(32), spacing: 0), count: 8)
    var body: some View {
        VStack(spacing: 8) {
            Text("Smileys & Emotion")
                .font(.headline)
                .padding(.top, 8)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(emojiIcons, id: \ .self) { emoji in
                        EmojiLabel(
                            emoji: emoji,
                            tooltip: (emoji.unicodeScalars.first?.properties.name ?? "").lowercased(),
                            onSelect: onSelect
                        )
                        .frame(width: 32, height: 32)
                    }
                }
                .padding([.leading, .trailing, .bottom], 8)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(maxWidth: 320, maxHeight: 360)
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}

struct EmojiLabel: NSViewRepresentable {
    let emoji: String
    let tooltip: String
    let onSelect: (String) -> Void
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: emoji, target: context.coordinator, action: #selector(Coordinator.handleClick))
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 24)
        button.toolTip = tooltip
        button.setButtonType(.momentaryChange)
        button.focusRingType = .none
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        return button
    }
    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.title = emoji
        nsView.toolTip = tooltip
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(emoji: emoji, onSelect: onSelect)
    }
    class Coordinator: NSObject {
        let emoji: String
        let onSelect: (String) -> Void
        init(emoji: String, onSelect: @escaping (String) -> Void) {
            self.emoji = emoji
            self.onSelect = onSelect
        }
        @objc func handleClick() {
            onSelect(emoji)
        }
    }
}

struct EmojiCell: View {
    let emoji: String
    let onSelect: (String) -> Void
    @State private var isHovered = false
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? Color.accentColor.opacity(0.2) : Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isHovered ? Color.accentColor : Color.gray.opacity(0.25), lineWidth: 1)
                    )
                Text(emoji)
                    .font(.system(size: 24))
                    .frame(width: 32, height: 32)
            }
            .padding(8)
            .onHover { hovering in
                isHovered = hovering
            }
            Text((emoji.unicodeScalars.first?.properties.name ?? "").lowercased())
                .font(.footnote)
                .lineLimit(2)
        }
        .onTapGesture {
            onSelect(emoji)
        }
    }
}
