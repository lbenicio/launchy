import SwiftUI

/// A horizontal scrolling row of color swatches for selecting a folder icon color.
/// Reusable across folder creation and folder editing views.
struct IconColorPicker: View {
    @Binding var selectedColor: IconColor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(IconColor.allCases, id: \.self) { iconColor in
                    Button {
                        selectedColor = iconColor
                    } label: {
                        Circle()
                            .fill(iconColor.color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(
                                        Color.white,
                                        lineWidth: selectedColor == iconColor ? 2.5 : 0
                                    )
                            )
                            .overlay(
                                selectedColor == iconColor
                                    ? Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                    : nil
                            )
                            .shadow(
                                color: iconColor.color.opacity(
                                    selectedColor == iconColor ? 0.5 : 0
                                ),
                                radius: 4
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(iconColor.rawValue.capitalized)
                    .accessibilityHint(selectedColor == iconColor ? "Selected" : "Double tap to select")
                    .accessibilityAddTraits(selectedColor == iconColor ? [.isSelected] : [])
                }
            }
        }
    }
}
