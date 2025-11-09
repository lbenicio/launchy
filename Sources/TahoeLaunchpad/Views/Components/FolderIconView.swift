import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct FolderIconView: View {
    let folder: LaunchpadFolder
    let isEditing: Bool
    let dimension: CGFloat

    private var cornerRadius: CGFloat { dimension * 0.22 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(folder.color.color.opacity(0.7))
                    )
                    .frame(width: dimension, height: dimension)
                    .overlay(previewGrid.padding(8))
                    .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
            }

            Text(folder.name)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: dimension)
        }
        .wiggle(if: isEditing)
    }

    private var previewGrid: some View {
        GeometryReader { proxy in
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
            let size = (proxy.size.width - 8) / 3

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(folder.previewIcons) { icon in
                    #if os(macOS)
                        Image(nsImage: ApplicationIconProvider.shared.icon(for: icon.bundleURL))
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
