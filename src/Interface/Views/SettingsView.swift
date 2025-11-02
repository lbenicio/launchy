import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    private let columnRange = 2...8
    private let rowRange = 2...6
  private let scrollRange = AppSettings.scrollThresholdRange

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

        VStack(alignment: .leading, spacing: 6) {
          Text("Scroll Sensitivity")
          HStack(spacing: 12) {
            Slider(value: $settings.scrollThreshold, in: scrollRange, step: 4)
            Text("\(Int(settings.scrollThreshold))")
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
          Text("Lower values need smaller scroll gestures to change pages.")
            .font(.footnote)
            .foregroundColor(.secondary)
        }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 280, minHeight: 160)
    .background(AuxiliaryWindowConfigurator())
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
