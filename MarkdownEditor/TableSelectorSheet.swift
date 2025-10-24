import SwiftUI

struct TableSelectorSheet: View {
    let maxColumns = 6
    let maxRows = 8
    @State private var selectedColumns: Int = 0
    @State private var selectedRows: Int = 0
    @State private var hoveredCell: (col: Int, row: Int)? = nil
    var onSelect: (Int, Int) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Select table size")
                .font(.headline)
                .padding(.top, 8)
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(0..<maxRows, id: \ .self) { row in
                    GridRow {
                        ForEach(0..<maxColumns, id: \ .self) { col in
                            let isSelected = row <= selectedRows && col <= selectedColumns
                            let isHovered = hoveredCell?.col == col && hoveredCell?.row == row
                            ZStack {
                                Rectangle()
                                    .fill(isHovered ? Color.accentColor.opacity(0.4) : (isSelected ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.2)))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 2 : 0)
                                    )
                                if isHovered || (col == selectedColumns && row == selectedRows) {
                                    Text("\(col+1),\(row+1)")
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                        .opacity(0.5)
                                }
                            }
                            .onHover { hovering in
                                hoveredCell = hovering ? (col, row) : nil
                            }
                            .onTapGesture {
                                selectedColumns = col
                                selectedRows = row
                                onSelect(col+1, row+1)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 250, minHeight: 250)
        .frame(maxWidth: 320, maxHeight: 360)
    }
}
