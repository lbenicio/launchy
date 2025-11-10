import CoreGraphics
import SwiftUI

struct GridLayoutMetrics {
    let itemDimension: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let columns: [GridItem]
    let padding: CGFloat

    init(for settings: GridSettings, in size: CGSize) {
        let basePadding: CGFloat = 60
        let horizontalSpacing: CGFloat = 32
        let verticalSpacing: CGFloat = 36

        let availableWidth = max(0, size.width - basePadding * 2)
        let availableHeight = max(0, size.height - basePadding * 2)

        let columnSpacingTotal = CGFloat(max(settings.columns - 1, 0)) * horizontalSpacing
        let rowSpacingTotal = CGFloat(max(settings.rows - 1, 0)) * verticalSpacing

        let widthPerItem = (availableWidth - columnSpacingTotal) / CGFloat(max(settings.columns, 1))
        let heightPerItem = (availableHeight - rowSpacingTotal) / CGFloat(max(settings.rows, 1))

        let baseDimension = min(widthPerItem, heightPerItem)
        let clampedDimension = min(max(baseDimension, 80), 120)
        let dimension = clampedDimension * settings.iconScale

        self.itemDimension = dimension
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.columns = Array(
            repeating: GridItem(.fixed(dimension), spacing: horizontalSpacing),
            count: max(settings.columns, 1))
        self.padding = basePadding
    }
}
