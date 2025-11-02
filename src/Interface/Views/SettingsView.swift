import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    private let columnRange = 2...8
    private let rowRange = 2...6

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Layout")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Columns")
                    Spacer()
                    Stepper(value: $settings.gridColumns, in: columnRange) {
                        Text("\(settings.gridColumns)")
                            .monospacedDigit()
                    }
                    .labelsHidden()
                }

                HStack {
                    Text("Rows")
                    Spacer()
                    Stepper(value: $settings.gridRows, in: rowRange) {
                        Text("\(settings.gridRows)")
                            .monospacedDigit()
                    }
                    .labelsHidden()
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 280, minHeight: 160)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
