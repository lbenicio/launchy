import SwiftUI

/// A view modifier that adds a subtle shimmer/loading animation
/// to placeholder content while data loads.
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.06),
                        Color.white.opacity(0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 400)
                .allowsHitTesting(false)
            }
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.8)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Applies a subtle shimmer animation, useful for loading placeholders.
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}
