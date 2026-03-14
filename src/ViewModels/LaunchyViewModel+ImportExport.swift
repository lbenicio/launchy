import Foundation
import UniformTypeIdentifiers

#if os(macOS)
    import AppKit
#endif

// MARK: - Import / Export layout

extension LaunchyViewModel {

    /// Exports the current layout to a JSON file chosen by the user via a save panel.
    func exportLayout() {
        #if os(macOS)
            let panel = NSSavePanel()
            panel.title = "Export Launchy Layout"
            panel.nameFieldStringValue = "launchy-layout.json"
            panel.allowedContentTypes = [.json]
            panel.canCreateDirectories = true

            guard panel.runModal() == .OK, let url = panel.url else { return }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            do {
                let data = try encoder.encode(items)
                try data.write(to: url, options: [.atomic])
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        #endif
    }

    /// Imports a layout from a user-selected JSON file, replacing the current arrangement.
    func importLayout() {
        #if os(macOS)
            let panel = NSOpenPanel()
            panel.title = "Import Launchy Layout"
            panel.allowedContentTypes = [.json]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false

            guard panel.runModal() == .OK, let url = panel.url else { return }

            do {
                let data = try Data(contentsOf: url)
                let imported = try JSONDecoder().decode([LaunchyItem].self, from: data)
                items = imported
                currentPage = 0
                presentedFolderID = nil
                selectedItemIDs.removeAll()
                recentlyRemovedApps.removeAll()
                isEditing = false
                saveNow()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Import Failed"
                alert.informativeText =
                    "The file could not be read as a valid Launchy layout. \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        #endif
    }

    /// Reads the macOS Launchpad DB and replaces the current layout with the result.
    func importFromLaunchpad() {
        #if os(macOS)
            do {
                guard let imported = try LaunchpadImporter.importLayout() else {
                    let alert = NSAlert()
                    alert.messageText = "Launchpad Database Not Found"
                    alert.informativeText =
                        "No Launchpad database was found in ~/Library/Application Support/Dock/."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    return
                }
                recordForUndo()
                items = imported
                currentPage = 0
                presentedFolderID = nil
                selectedItemIDs.removeAll()
                recentlyRemovedApps.removeAll()
                isEditing = false
                saveNow()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Launchpad Import Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        #endif
    }
}
