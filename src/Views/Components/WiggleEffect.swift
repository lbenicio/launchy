import SwiftUI

struct WiggleEffect: ViewModifier {
    let isActive: Bool
    let intensity: Double

    @State private var animate = false
    @State private var phase: Double = Double.random(in: 0...1)

    private var resolvedDuration: Double {
        0.12 + phase * 0.08
    }

    private var resolvedIntensity: Double {
        intensity * (0.85 + phase * 0.3)
    }

    func body(content: Content) -> some View {
        content
            .rotationEffect(
                isActive
                    ? .degrees(animate ? resolvedIntensity : -resolvedIntensity)
                    : .degrees(0)
            )
            .offset(
                x: isActive ? (animate ? resolvedIntensity : -resolvedIntensity) * 0.3 : 0,
                y: isActive ? (animate ? resolvedIntensity * 0.15 : -resolvedIntensity * 0.15) : 0
            )
            .animation(
                isActive
                    ? Animation
                        .easeInOut(duration: resolvedDuration)
                        .repeatForever(autoreverses: true)
                    : Animation.easeOut(duration: 0.2),
                value: animate
            )
            .onChange(of: isActive) { _, active in
                if active {
                    phase = Double.random(in: 0...1)
                    animate = true
                } else {
                    animate = false
                }
            }
            .onAppear {
                if isActive {
                    phase = Double.random(in: 0...1)
                    animate = true
                }
            }
    }
}

extension View {
    func wiggle(if isActive: Bool, intensity: Double = 2.4) -> some View {
        modifier(WiggleEffect(isActive: isActive, intensity: intensity))
    }
}
