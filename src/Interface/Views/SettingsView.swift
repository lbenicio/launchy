import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    private let columnRange = 2...8
    private let rowRange = 2...6
  private let scrollRange = AppSettings.scrollThresholdRange

    var body: some View {
    TabView {
      layoutTab
        .tabItem { Label("Layout", systemImage: "slider.horizontal.3") }
      aboutTab
        .tabItem { Label("About", systemImage: "info.circle") }
    }
    .padding()
    .frame(minWidth: 320, minHeight: 240)
    .background(AuxiliaryWindowConfigurator())
  }

  private var layoutTab: some View {
    VStack(alignment: .leading, spacing: 18) {
            Text("Layout")
        .font(.title3.weight(.semibold))

      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 16) {
                    Text("Columns")
          Spacer()
          Text("\(settings.gridColumns)")
            .monospacedDigit()
          Stepper("", value: $settings.gridColumns, in: columnRange)
            .labelsHidden()
                }

        HStack(spacing: 16) {
                    Text("Rows")
          Spacer()
          Text("\(settings.gridRows)")
            .monospacedDigit()
          Stepper("", value: $settings.gridRows, in: rowRange)
            .labelsHidden()
                }

        VStack(alignment: .leading, spacing: 8) {
          Text("Scroll Sensitivity")
          HStack(spacing: 12) {
            Slider(value: $settings.scrollThreshold, in: scrollRange, step: 1)
            Text(String(format: "%.0f", settings.scrollThreshold))
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
    .padding(.top, 12)
  }

  private var aboutTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("About Launchy")
        .font(.title3.weight(.semibold))

      Text("A lightweight Launchpad-inspired launcher built with SwiftUI.")
        .foregroundColor(.secondary)

      VStack(alignment: .leading, spacing: 4) {
        infoRow(label: "Version", value: AppInfo.version)
        infoRow(label: "Build", value: AppInfo.build)
      }

      Spacer()
    }
    .padding(.top, 12)
  }

  private func infoRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .foregroundColor(.secondary)
      Spacer()
      Text(value)
        .monospacedDigit()
    }
  }
}

private enum AppInfo {
  static var version: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
  }

  static var build: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
