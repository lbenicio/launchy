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
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Launchpad Settings")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Fine-tune the grid density, folder layout, and interaction behaviour.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                settingsCard(title: "Launchpad Grid", systemImage: "square.grid.3x3.fill") {
                    gridStepperRow(
                        title: "Columns",
                        subtitle: "Number of icons per row",
                        value: store.settings.columns,
                        binding: columnsBinding,
                        range: 3...10
                    )

                    Divider()

                    gridStepperRow(
                        title: "Rows",
                        subtitle: "Number of rows per page",
                        value: store.settings.rows,
                        binding: rowsBinding,
                        range: 3...10
                    )

                    Divider()

                    sliderRow(
                        title: "Icon Scale",
                        subtitle: "Make app tiles larger or smaller",
                        value: store.settings.iconScale,
                        formattedValue: String(format: "%.2f×", store.settings.iconScale),
                        binding: iconScaleBinding,
                        range: 0.8...1.4,
                        step: 0.05
                    )
                }

                settingsCard(title: "Folder Grid", systemImage: "folder.fill") {
                    gridStepperRow(
                        title: "Columns",
                        subtitle: "Apps per row when a folder is open",
                        value: store.settings.folderColumns,
                        binding: folderColumnsBinding,
                        range: 2...8
                    )

                    Divider()

                    gridStepperRow(
                        title: "Rows",
                        subtitle: "Maximum rows shown inside folders",
                        value: store.settings.folderRows,
                        binding: folderRowsBinding,
                        range: 2...8
                    )
                }

                settingsCard(title: "Interaction", systemImage: "cursorarrow.click") {
                    sliderRow(
                        title: "Scroll Wheel Sensitivity",
                        subtitle: "Adjust how many scroll steps are needed to change pages",
                        value: store.settings.scrollSensitivity,
                        formattedValue: String(format: "%.2f×", store.settings.scrollSensitivity),
                        binding: scrollSensitivityBinding,
                        range: 0.2...2.0,
                        step: 0.05
                    )
                }

                settingsCard(title: "Window", systemImage: "rectangle.topthird.inset") {
                    Toggle(isOn: fullScreenBinding) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fill Entire Screen")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Disable to keep the launchpad centered and sized to the grid.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 32)
        .frame(minWidth: 640, minHeight: 520)
    }
}

private extension SettingsView {
    @ViewBuilder
    func settingsCard(title: String, systemImage: String, @ViewBuilder content: () -> some View)
        -> some View
    {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(Color.primary.opacity(0.9))

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    func gridStepperRow(
        title: String, subtitle: String, value: Int, binding: Binding<Int>, range: ClosedRange<Int>
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 24)

            Stepper(value: binding, in: range) {
                valueBadge("\(value)")
            }
            .labelsHidden()
        }
    }

    func sliderRow(
        title: String,
        subtitle: String,
        value: Double,
        formattedValue: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                valueBadge(formattedValue)
            }

            Slider(value: binding, in: range, step: step)
        }
    }

    func valueBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.16), in: Capsule())
    }
}
