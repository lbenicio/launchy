import SwiftUI

#if os(macOS)
    import AppKit

    struct LaunchySearchField: View {
        @Binding var text: String
        @FocusState private var isFocused: Bool

        var body: some View {
            TextField("Search", text: $text)
                .font(.system(size: 16, weight: .regular))
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .frame(width: 320, height: 44)
                .focused($isFocused)
                .allowsHitTesting(true)
                .onAppear {
                    // Delay focus setting slightly to ensure the view hierarchy is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }
                .onTapGesture {
                    isFocused = true
                }
        }
    }
#else
    struct LaunchySearchField: View {
        @Binding var text: String

        var body: some View {
            TextField("Search", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
#endif
