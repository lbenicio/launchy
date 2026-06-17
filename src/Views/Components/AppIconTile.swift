import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct AppIconTile: View {
    let icon: AppIcon
    let isEditing: Bool
    let dimension: CGFloat
    var isRecentlyAdded: Bool = false

    #if os(macOS)
        @ObservedObject private var badgeProvider = NotificationBadgeProvider.shared
    #endif

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                iconImage
                    .frame(width: dimension, height: dimension)
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)

                #if os(macOS)
                    if !isEditing,
                        let badge = badgeProvider.badges[icon.bundleIdentifier],
                        !badge.isEmpty
                    {
                        badgeView(badge)
                    }
                #endif
            }

            Text(icon.name)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: dimension)
                .lineLimit(2)

            if isRecentlyAdded {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
            }
        }
        .wiggle(if: isEditing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelString)
    }

    private var accessibilityLabelString: String {
        #if os(macOS)
            if !isEditing,
                let badge = badgeProvider.badges[icon.bundleIdentifier],
                !badge.isEmpty
            {
                return "\(icon.name), \(badge) notification\(badge == "1" ? "" : "s")"
            }
        #endif
        return icon.name
    }

    @ViewBuilder
    private var iconImage: some View {
        #if os(macOS)
            Image(nsImage: ApplicationIconProvider.shared.icon(for: icon.bundleURL))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.08),
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .allowsHitTesting(false)
                }
        #else
            Rectangle().fill(Color.gray.opacity(0.2))
        #endif
    }

    #if os(macOS)
        private func badgeView(_ text: String) -> some View {
            let fontSize = max(dimension * 0.15, 11)
            let horizontalPadding = max(dimension * 0.06, 5)
            let verticalPadding = max(dimension * 0.02, 2)
            let minWidth = max(dimension * 0.22, 18)
            let offsetX = dimension * 0.08
            let offsetY = -dimension * 0.04

            return Text(text)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(minWidth: minWidth)
                .background(
                    Capsule()
                        .fill(Color.red)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                )
                .offset(x: offsetX, y: offsetY)
        }
    #endif
}
