import SwiftUI

struct FolderOverlay: View {
    let folder: FolderItem
    let anchor: CGRect
    let containerSize: CGSize

    @EnvironmentObject private var store: AppCatalogStore
    @State private var isExpanded = false
    @State private var isClosing = false

    private let animation = Animation.spring(
        response: 0.36, dampingFraction: 0.82, blendDuration: 0.12)

    private var gridLayout: [GridItem] {
        [GridItem(.adaptive(minimum: 110, maximum: 140), spacing: 22)]
    }

    private var targetSize: CGSize {
        let width = max(min(containerSize.width - 160, 520), anchor.width)
        let rows = max(1, ceil(Double(folder.apps.count) / 4.0))
        let gridHeight = rows * 120.0
        let height = max(min(containerSize.height - 160, gridHeight + 120), anchor.height)
        return CGSize(width: width, height: height)
    }

    private var collapsedScaleX: CGFloat {
        guard targetSize.width > 0 else { return 1 }
        let ratio = anchor.width / targetSize.width
        return min(max(ratio, 0.32), 1)
    }

    private var collapsedScaleY: CGFloat {
        guard targetSize.height > 0 else { return 1 }
        let ratio = anchor.height / targetSize.height
        return min(max(ratio, 0.32), 1)
    }

    var body: some View {
        ZStack {
      Color.black.opacity(isExpanded ? 0.72 : 0)
                .ignoresSafeArea()
                .animation(animation, value: isExpanded)
                .onTapGesture { close() }

            folderCard
                .frame(width: targetSize.width, height: targetSize.height)
                .scaleEffect(
                    x: isExpanded ? 1 : collapsedScaleX,
                    y: isExpanded ? 1 : collapsedScaleY,
                    anchor: .center
                )
                .position(
                    x: isExpanded ? containerSize.width / 2 : anchor.midX,
                    y: isExpanded ? containerSize.height / 2 : anchor.midY
                )
                .shadow(
                    color: .black.opacity(isExpanded ? 0.28 : 0.12),
                    radius: isExpanded ? 22 : 10,
                    y: isExpanded ? 14 : 4
                )
                .contentShape(Rectangle())
                .onTapGesture {}
        }
        .animation(animation, value: isExpanded)
        .onAppear {
            withAnimation(animation) {
                isExpanded = true
            }
        }
    }

    private var folderCard: some View {
        VStack(spacing: 22) {
            HStack {
                Text(folder.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(radius: 6, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            ScrollView {
                LazyVGrid(columns: gridLayout, spacing: 22) {
                    ForEach(folder.apps) { app in
                        AppIconView(app: app)
                    }
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
        .fill(Color.black.opacity(0.62))
                .background(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(Color.black.opacity(0.45))
            .blur(radius: 24)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
        .stroke(Color.white.opacity(0.24), lineWidth: 1.2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        withAnimation(animation) {
            isExpanded = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            store.dismissPresentedFolder()
            isClosing = false
        }
    }
}
