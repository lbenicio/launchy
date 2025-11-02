import SwiftUI

struct GridMetrics {
    let columns: [GridItem]
    let tileSize: CGSize
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let rows: Int

    var capacity: Int { max(1, columns.count * rows) }
    var contentWidth: CGFloat {
        guard !columns.isEmpty else { return 0 }
        return (CGFloat(columns.count) * tileSize.width)
            + (CGFloat(max(columns.count - 1, 0)) * spacing)
    }

    var contentHeight: CGFloat {
        guard rows > 0 else { return 0 }
        return (CGFloat(rows) * tileSize.height) + (CGFloat(max(rows - 1, 0)) * spacing)
    }
}

enum GridMetricsCalculator {
    static func make(
        containerSize: CGSize,
        columns requestedColumns: Int,
        rows requestedRows: Int
    ) -> GridMetrics {
        let spacing: CGFloat = 24
        let horizontalPadding: CGFloat = 72

        var columns = max(1, min(requestedColumns, 8))
        let rows = max(1, min(requestedRows, 6))

        let availableWidth = max(0, containerSize.width - horizontalPadding * 2)
        var tileWidth: CGFloat = 140
        if availableWidth > 0 {
            var computedWidth: CGFloat = 0
            var candidateColumns = columns
            while candidateColumns >= 1 {
                let raw =
                    (availableWidth - spacing * CGFloat(candidateColumns - 1))
                        / CGFloat(candidateColumns)
                if raw >= 120 {
                    computedWidth = raw
                    columns = candidateColumns
                    break
                }
                candidateColumns -= 1
            }
            if computedWidth <= 0 {
                columns = 1
                computedWidth = availableWidth
            }
            tileWidth = max(120, computedWidth)
        }

        let verticalReserve: CGFloat = 320
        let availableHeight = max(160, containerSize.height - verticalReserve)
        let tileHeightRaw = (availableHeight - spacing * CGFloat(rows - 1)) / CGFloat(rows)
        let tileHeight = max(140, tileHeightRaw)

        let gridItems = Array(
            repeating: GridItem(.fixed(tileWidth), spacing: spacing, alignment: .top),
            count: columns
        )

        return GridMetrics(
            columns: gridItems,
            tileSize: CGSize(width: tileWidth, height: tileHeight),
            spacing: spacing,
            horizontalPadding: horizontalPadding,
            rows: rows
        )
    }
}
