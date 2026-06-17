import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct FolderIconView: View {
    let folder: LaunchyFolder
    let isEditing: Bool
    let dimension: CGFloat

    #if os(macOS)
        @ObservedObject private var badgeProvider = NotificationBadgeProvider.shared
    #endif

    private var cornerRadius: CGFloat { dimension * 0.22 }

    #if os(macOS)
        /// Aggregate badge count across all apps contained in this folder.
        private var aggregateBadgeCount: Int {
            folder.apps.reduce(0) { total, app in
                if let badge = badgeProvider.badges[app.bundleIdentifier],
                    let count = Int(badge)
                {
                    return total + count
                }
                return total
            }
        }
    #endif

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(folder.color.color.opacity(0.7))
                    )
                    .frame(width: dimension, height: dimension)
                    .overlay(previewGrid.padding(8))
                    .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)

                #if os(macOS)
                    if !isEditing, aggregateBadgeCount > 0 {
                        Text("\(aggregateBadgeCount)")
                            .font(
                                .system(
                                    size: max(dimension * 0.15, 11),
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(.white)
                            .padding(.horizontal, max(dimension * 0.06, 5))
                            .padding(.vertical, max(dimension * 0.02, 2))
                            .frame(minWidth: max(dimension * 0.22, 18))
                            .background(
                                Capsule()
                                    .fill(Color.red)
                                    .shadow(
                                        color: Color.black.opacity(0.3),
                                        radius: 2,
                                        x: 0,
                                        y: 1
                                    )
                            )
                            .offset(
                                x: dimension * 0.08,
                                y: -dimension * 0.04
                            )
                    }
                #endif
            }

            Text(folder.name)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: dimension)
        }
        .wiggle(if: isEditing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelString)
    }

    private var accessibilityLabelString: String {
        #if os(macOS)
            if !isEditing, aggregateBadgeCount > 0 {
                return "\(folder.name) folder, \(folder.apps.count) apps, \(aggregateBadgeCount) notification\(aggregateBadgeCount == 1 ? "" : "s")"
            }
        #endif
        return "\(folder.name) folder, \(folder.apps.count) apps"
    }

    private var previewGrid: some View {
        GeometryReader { proxy in
            let columns = Array(
                repeating: GridItem(.flexible(), spacing: 4),
                count: 3
            )
            let size = (proxy.size.width - 8) / 3

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(folder.previewIcons) { icon in
                    #if os(macOS)
                        Image(
                            nsImage: ApplicationIconProvider.shared
                                .icon(for: icon.bundleURL)
                        )
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 6,
                                style: .continuous
                            )
                        )
                    #else
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: size, height: size)
                    #endif
                }
            }
        }
    }
}
