import SwiftUI

struct FolderOverlay: View {
    let folder: FolderItem
    @EnvironmentObject private var store: AppCatalogStore

    private let gridLayout = [
        GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 20)
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Text(folder.name)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        store.dismissPresentedFolder()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                ScrollView {
                    LazyVGrid(columns: gridLayout, spacing: 20) {
                        ForEach(folder.apps) { app in
                            AppIconView(app: app)
                        }
                    }
                    .padding(28)
                }
            }
            .frame(maxWidth: 620)
            .padding(.vertical, 36)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(radius: 16)
        }
        .transition(.opacity)
        .zIndex(10)
    }
}
