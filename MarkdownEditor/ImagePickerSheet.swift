import SwiftUI

struct ImagePickerSheet: View {
    var onSelect: (String) -> Void
    
    // Emojis grouped by type for better organization
    let emojiIcons: [String] = [
        // Faces & Emotions
        "😀", "😂", "😍", "🥰", "😎", "😊", "😉", "😁", "😅", "😭", "😡", "😢", "😮", "😳", "😞", "😤", "🤯", "🤪", "🤬", "😷", "🤨", "😇", "😜", "🤩", "😏", "😴", "🤗", "😬", "😱", "🤓", "😈",
        // Gestures & Body
        "👍", "🙏", "👏", "💪", "👀", "👋", "🙌", "🤝", "🤲", "✌️", "🤘", "👌", "🤙", "🖐️", "✋", "👉", "👈", "👆", "👇",
        // Travel & Places
        "🏖️", "🏔️", "🏜️", "🏕", "🏙️", "🌋", "🏝️", "🏞️", "🗽", "🗼", "🏰", "🏟️",
        // Animals & Nature
        "🦄", "🐶", "🐱", "🍀", "🍁", "🍂", "🍃", "🌸", "🌼", "🌻", "🌺", "💩",
        // Food
        "🍕", "🍔", "🍟", "🌭", "🍣", "🍩", "🍪", "🍎", "🍌", "🍉", "🍇", "🍓",
        // Objects
        "🧠", "👾", "💼", "📅", "⏰", "📚", "🖊️", "🗂️", "🔒", "🔑", "🔄",
        // Celebration & Activities
        "🎉", "🎊", "🎂", "🎈", "🏆", "🎶", "🎤", "🎧", "🎬", "📸",
        // Weather & Nature
        "🔥", "⚡", "🌟", "🌈", "☀️", "🌙", "☁️", "🌧️", "❄️",
        // Symbols
        "✅", "❌", "⚠️", "❤️", "💯", "💡", "ℹ️", "🔍", "🔔", "💬", "📢", "📌", "🚫", "♻️",
        // Fantasy & Halloween
        "👻", "💀", "☠️", "👽",
        // Numbers
        "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟",
        // Transport
        "🚀", "🚗", "✈️", "🚢", "🚲", "🛴", "🚁"
    ]
    
    // 5 fixed columns for emoji grid
    let columns = Array(repeating: GridItem(.fixed(60)), count: 5)
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                // Show emoji icons
                ForEach(emojiIcons, id: \ .self) { emoji in
                    EmojiCell(emoji: emoji, onSelect: onSelect)
                }
            }
            .padding()
        }
        .frame(maxWidth: 360, maxHeight: 360)
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
