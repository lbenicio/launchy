import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct AppIconTile: View {
    let icon: AppIcon
    let isEditing: Bool
    let dimension: CGFloat

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
        }
        .wiggle(if: isEditing)
    }

    @ViewBuilder
    private var iconImage: some View {
        #if os(macOS)
            Image(nsImage: ApplicationIconProvider.shared.icon(for: icon.bundleURL))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        #else
            Rectangle().fill(Color.gray.opacity(0.2))
        #endif
    }

    #if os(macOS)
        private func badgeView(_ text: String) -> some View {
            Text(text)
                .font(.system(size: max(dimension * 0.15, 11), weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, max(dimension * 0.06, 5))
                .padding(.vertical, max(dimension * 0.02, 2))
                .frame(minWidth: max(dimension * 0.22, 18))
                .background(
                    Capsule()
                        .fill(Color.red)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                )
                .offset(x: dimension * 0.08, y: -dimension * 0.04)
        }
    #endif
}
