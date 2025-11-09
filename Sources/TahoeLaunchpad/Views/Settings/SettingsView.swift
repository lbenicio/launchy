import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: GridSettingsStore

    private var columnsBinding: Binding<Int> {
        Binding(
            get: { store.settings.columns },
            set: { store.update(columns: $0) }
        )
    }

    private var rowsBinding: Binding<Int> {
        Binding(
            get: { store.settings.rows },
            set: { store.update(rows: $0) }
        )
    }

    private var folderColumnsBinding: Binding<Int> {
        Binding(
            get: { store.settings.folderColumns },
            set: { store.update(folderColumns: $0) }
        )
    }

    private var folderRowsBinding: Binding<Int> {
        Binding(
            get: { store.settings.folderRows },
            set: { store.update(folderRows: $0) }
        )
    }

    private var iconScaleBinding: Binding<Double> {
        Binding(
            get: { store.settings.iconScale },
            set: { store.update(iconScale: $0) }
        )
    }

    private var scrollSensitivityBinding: Binding<Double> {
        Binding(
            get: { store.settings.scrollSensitivity },
            set: { store.update(scrollSensitivity: $0) }
        )
    }

    private var fullScreenBinding: Binding<Bool> {
        Binding(
            get: { store.settings.useFullScreenLayout },
            set: { store.update(useFullScreenLayout: $0) }
        )
    }

    var body: some View {
        Form {
            Section("Grid Layout") {
                Stepper(value: columnsBinding, in: 3...10) {
                    HStack {
                        Text("Columns")
                        Spacer()
                        Text("\(store.settings.columns)")
                    }
                }

                Stepper(value: rowsBinding, in: 3...10) {
                    HStack {
                        Text("Rows")
                        Spacer()
                        Text("\(store.settings.rows)")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Icon Scale")
                        Spacer()
                        Text(String(format: "%.2f", store.settings.iconScale))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: iconScaleBinding, in: 0.8...1.4, step: 0.05)
                }
            }

            Section("Folder Layout") {
                Stepper(value: folderColumnsBinding, in: 2...8) {
                    HStack {
                        Text("Columns")
                        Spacer()
                        Text("\(store.settings.folderColumns)")
                    }
                }

                Stepper(value: folderRowsBinding, in: 2...8) {
                    HStack {
                        Text("Rows")
                        Spacer()
                        Text("\(store.settings.folderRows)")
                    }
                }
            }

            Section("Interaction & Window") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Scroll Wheel Sensitivity")
                        Spacer()
                        Text(String(format: "%.2f×", store.settings.scrollSensitivity))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: scrollSensitivityBinding, in: 0.2...2.0, step: 0.05)
                        .accessibilityLabel("Scroll Wheel Sensitivity")
                }

                Toggle(isOn: fullScreenBinding) {
                    Text("Fill Entire Screen")
                }
            }
        }
        .padding(.vertical, 12)
        .frame(minWidth: 420, minHeight: 360)
    }
}
