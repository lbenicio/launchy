import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct AppIconTile: View {
    let icon: AppIcon
    let isEditing: Bool
    let dimension: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            iconImage
                .frame(width: dimension, height: dimension)
                .shadow(color: Color.black.opacity(0.28), radius: 12, x: 0, y: 8)

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
}
