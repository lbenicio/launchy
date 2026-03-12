import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: GridSettingsStore
    @State private var isConfirmingReset: Bool = false

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

    private var backgroundModeBinding: Binding<BackgroundMode> {
        Binding(
            get: { store.settings.backgroundMode },
            set: { store.update(backgroundMode: $0) }
        )
    }

    private var blurIntensityBinding: Binding<Double> {
        Binding(
            get: { store.settings.blurIntensity },
            set: { store.update(blurIntensity: $0) }
        )
    }

    private var solidColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: store.settings.solidColorHex ?? "1A2030") },
            set: { store.update(solidColorHex: $0.hexString) }
        )
    }

    private var gradientStartBinding: Binding<Color> {
        Binding(
            get: { Color(hex: store.settings.gradientStartHex ?? "212833") },
            set: { store.update(gradientStartHex: $0.hexString) }
        )
    }

    private var gradientEndBinding: Binding<Color> {
        Binding(
            get: { Color(hex: store.settings.gradientEndHex ?? "080A0D") },
            set: { store.update(gradientEndHex: $0.hexString) }
        )
    }

    private var iCloudSyncBinding: Binding<Bool> {
        Binding(
            get: { store.settings.iCloudSyncEnabled },
            set: { newValue in
                store.update(iCloudSyncEnabled: newValue)
                if newValue {
                    ICloudSyncService.shared.startObserving()
                } else {
                    ICloudSyncService.shared.stopObserving()
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Launchy Settings")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Fine-tune the grid density, folder layout, and interaction behaviour.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                settingsCard(title: "Launchy Grid", systemImage: "square.grid.3x3.fill") {
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

                    Divider()

                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(0.7), Color.purple.opacity(0.7),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(
                                    width: 64 * store.settings.iconScale,
                                    height: 64 * store.settings.iconScale
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 4)
                                .animation(
                                    .interactiveSpring(response: 0.3, dampingFraction: 0.7),
                                    value: store.settings.iconScale
                                )
                            Text("Preview")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
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
                            Text("Disable to keep the launcher centered and sized to the grid.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }

                settingsCard(title: "Background", systemImage: "paintbrush.fill") {
                    Picker("Mode", selection: backgroundModeBinding) {
                        Text("Wallpaper Blur").tag(BackgroundMode.wallpaperBlur)
                        Text("Solid Color").tag(BackgroundMode.solidColor)
                        Text("Gradient").tag(BackgroundMode.gradient)
                    }
                    .pickerStyle(.segmented)

                    switch store.settings.backgroundMode {
                    case .wallpaperBlur:
                        sliderRow(
                            title: "Blur Overlay Intensity",
                            subtitle: "How much the dark overlay covers the desktop wallpaper",
                            value: store.settings.blurIntensity,
                            formattedValue: String(
                                format: "%.0f%%",
                                store.settings.blurIntensity * 100
                            ),
                            binding: blurIntensityBinding,
                            range: 0.0...1.0,
                            step: 0.05
                        )
                    case .solidColor:
                        ColorPicker("Background Color", selection: solidColorBinding)
                    case .gradient:
                        ColorPicker("Start Color", selection: gradientStartBinding)
                        ColorPicker("End Color", selection: gradientEndBinding)
                    }
                }

                settingsCard(title: "Data", systemImage: "arrow.counterclockwise") {
                    Toggle(isOn: iCloudSyncBinding) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iCloud Sync")
                                .font(.system(size: 15, weight: .semibold))
                            Text(
                                "Sync your layout across Macs using iCloud. Changes on one Mac will appear on others."
                            )
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reset Layout")
                                .font(.system(size: 15, weight: .semibold))
                            Text(
                                "Remove all folders and custom arrangement. Apps will be re-imported from your Applications directories in alphabetical order."
                            )
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        }

                        if isConfirmingReset {
                            HStack(spacing: 12) {
                                Text("Are you sure?")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.orange)
                                Button("Cancel") {
                                    isConfirmingReset = false
                                }
                                Button("Reset") {
                                    isConfirmingReset = false
                                    NotificationCenter.default.post(
                                        name: .resetToDefaultLayout,
                                        object: nil
                                    )
                                }
                                .foregroundStyle(.red)
                            }
                        } else {
                            Button {
                                isConfirmingReset = true
                            } label: {
                                Label(
                                    "Reset to Default Layout",
                                    systemImage: "arrow.counterclockwise"
                                )
                                .font(.system(size: 13, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Import / Export")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Save your layout to a file or restore from a previous export.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            Button {
                                NotificationCenter.default.post(name: .exportLayout, object: nil)
                            } label: {
                                Label("Export Layout", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .buttonStyle(.bordered)

                            Button {
                                NotificationCenter.default.post(name: .importLayout, object: nil)
                            } label: {
                                Label("Import Layout", systemImage: "square.and.arrow.down")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
        .padding(.horizontal, 36)
        .padding(.vertical, 32)
        .frame(minWidth: 640, minHeight: 520)
    }
}

extension SettingsView {
    @ViewBuilder
    fileprivate func settingsCard(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> some View
    )
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

    fileprivate func gridStepperRow(
        title: String,
        subtitle: String,
        value: Int,
        binding: Binding<Int>,
        range: ClosedRange<Int>
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

            HStack(spacing: 10) {
                valueBadge("\(value)")

                Stepper("", value: binding, in: range)
                    .labelsHidden()
                    .fixedSize()
            }
        }
    }

    fileprivate func sliderRow(
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

    fileprivate func valueBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.16), in: Capsule())
    }
}
