import SwiftUI

struct WidgetIconView: View {
    let widget: DashboardWidget
    let isEditing: Bool
    let dimension: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            // Widget icon
            Image(systemName: widget.iconName)
                .font(.system(size: dimension * 0.5, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: dimension * 0.8, height: dimension * 0.8)
                .background(
                    RoundedRectangle(cornerRadius: dimension * 0.2)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: dimension * 0.2)
                                .stroke(.tertiary, lineWidth: 1)
                        )
                )

            // Widget name
            if dimension >= 60 {
                Text(widget.name)
                    .font(.system(size: dimension * 0.12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: dimension * 0.9)
            }
        }
        .frame(width: dimension, height: dimension)
    }
}

#Preview {
    VStack(spacing: 20) {
        WidgetIconView(
            widget: DashboardWidget(type: .weather),
            isEditing: false,
            dimension: 80
        )

        WidgetIconView(
            widget: DashboardWidget(type: .calculator),
            isEditing: false,
            dimension: 60
        )

        WidgetIconView(
            widget: DashboardWidget(type: .notes),
            isEditing: true,
            dimension: 100
        )
    }
    .padding()
}
