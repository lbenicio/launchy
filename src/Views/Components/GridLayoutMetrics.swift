import CoreGraphics
import SwiftUI

struct GridLayoutMetrics {
    let itemDimension: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let columns: [GridItem]
    let padding: CGFloat

    init(for settings: GridSettings, in size: CGSize) {
        let rows = max(settings.rows, 1)
        let columns = max(settings.columns, 1)

        let paddingRange: ClosedRange<CGFloat> = 4...48
        let horizontalSpacingRange: ClosedRange<CGFloat> = 8...28
        let verticalSpacingRange: ClosedRange<CGFloat> = 6...30
        let tileAccessoryHeight: CGFloat = 34
        let preferredIconSize: CGFloat = 104
        let maxIconSize: CGFloat = 136
        let minIconSize: CGFloat = 48

        func normalized(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
            guard upper - lower > 0 else { return 1 }
            return max(0, min(1, (value - lower) / (upper - lower)))
        }

        func interpolate(range: ClosedRange<CGFloat>, factor: CGFloat) -> CGFloat {
            let clamped = max(0, min(1, factor))
            return range.lowerBound + (range.upperBound - range.lowerBound) * clamped
        }

        func layoutBudget(
            size: CGSize,
            padding: CGFloat,
            horizontalSpacing: CGFloat,
            verticalSpacing: CGFloat
        ) -> (widthPerItem: CGFloat, heightPerItem: CGFloat) {
            let availableWidth = max(0, size.width - padding * 2)
            let availableHeight = max(0, size.height - padding * 2)
            let columnSpacingTotal = CGFloat(max(columns - 1, 0)) * horizontalSpacing
            let rowSpacingTotal = CGFloat(max(rows - 1, 0)) * verticalSpacing

            let widthBudget = (availableWidth - columnSpacingTotal) / CGFloat(max(columns, 1))
            let heightBudgetPerRow = (availableHeight - rowSpacingTotal) / CGFloat(max(rows, 1))
            let heightPerItem = heightBudgetPerRow - tileAccessoryHeight
            return (max(0, widthBudget), max(0, heightPerItem))
        }

        let shortestSide = min(size.width, size.height)
        let scaleFactor = normalized(shortestSide, lower: 520, upper: 1400)

        var padding = interpolate(range: paddingRange, factor: scaleFactor)
        var horizontalSpacing = interpolate(range: horizontalSpacingRange, factor: scaleFactor)
        var verticalSpacing = interpolate(range: verticalSpacingRange, factor: scaleFactor)

        var widthPerItem: CGFloat = 0
        var heightPerItem: CGFloat = 0

        func tightenLayout(needsWidthAdjustment: Bool, needsHeightAdjustment: Bool) -> Bool {
            if needsWidthAdjustment {
                if horizontalSpacing > horizontalSpacingRange.lowerBound {
                    horizontalSpacing = max(
                        horizontalSpacingRange.lowerBound, horizontalSpacing - 2)
                    return true
                }
                if padding > paddingRange.lowerBound {
                    padding = max(paddingRange.lowerBound, padding - 2)
                    return true
                }
            }

            if needsHeightAdjustment {
                if verticalSpacing > verticalSpacingRange.lowerBound {
                    verticalSpacing = max(verticalSpacingRange.lowerBound, verticalSpacing - 2)
                    return true
                }
                if padding > paddingRange.lowerBound {
                    padding = max(paddingRange.lowerBound, padding - 2)
                    return true
                }
            }

            if needsWidthAdjustment || needsHeightAdjustment {
                if padding > paddingRange.lowerBound {
                    padding = max(paddingRange.lowerBound, padding - 2)
                    return true
                }
            }

            return false
        }

        for _ in 0..<32 {
            (widthPerItem, heightPerItem) = layoutBudget(
                size: size,
                padding: padding,
                horizontalSpacing: horizontalSpacing,
                verticalSpacing: verticalSpacing
            )

            let needsWidthAdjustment = widthPerItem < minIconSize
            let needsHeightAdjustment = heightPerItem < minIconSize

            guard needsWidthAdjustment || needsHeightAdjustment else { break }

            if !tightenLayout(
                needsWidthAdjustment: needsWidthAdjustment,
                needsHeightAdjustment: needsHeightAdjustment
            ) {
                break
            }
        }

        (widthPerItem, heightPerItem) = layoutBudget(
            size: size,
            padding: padding,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )

        let availableDimension = max(0, min(widthPerItem, heightPerItem))
        let scaledPreference = preferredIconSize * CGFloat(settings.iconScale)
        let desiredDimension = min(max(scaledPreference, minIconSize), maxIconSize)
        let constrainedPreference = min(desiredDimension, availableDimension)
        let resolvedDimension = max(
            constrainedPreference,
            min(availableDimension, minIconSize)
        )

        self.itemDimension = resolvedDimension
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.columns = Array(
            repeating: GridItem(.fixed(resolvedDimension), spacing: horizontalSpacing),
            count: columns)
        self.padding = padding
    }
}
