import SwiftUI

struct WiggleEffect: ViewModifier {
    @State private var animate = false
    let isActive: Bool
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .rotationEffect(isActive ? .degrees(animate ? intensity : -intensity) : .degrees(0))
            .offset(x: isActive ? (animate ? intensity : -intensity) * 0.35 : 0)
            .animation(
                isActive ? .easeInOut(duration: 0.14).repeatForever(autoreverses: true) : .default,
                value: animate
            )
            .onAppear { startIfNeeded() }
            .onChange(of: isActive) { _, _ in startIfNeeded() }
    }

    private func startIfNeeded() {
        if isActive {
            DispatchQueue.main.async {
                animate = true
            }
        } else {
            animate = false
        }
    }
}

extension View {
    func wiggle(if isActive: Bool, intensity: Double = 2.6) -> some View {
        modifier(WiggleEffect(isActive: isActive, intensity: intensity))
    }
}
