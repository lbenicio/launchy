import AppKit
import Foundation

struct AppItem: Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
    let bundleIdentifier: String?
    let bundleURL: URL

    func matches(_ query: String) -> Bool {
        let tokens = [displayName, bundleIdentifier ?? ""]
        return tokens.contains { value in
            value.localizedCaseInsensitiveContains(query)
        }
    }
}

struct FolderItem: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var apps: [AppItem]
}

enum CatalogEntry: Identifiable, Equatable, Hashable {
    case app(AppItem)
    case folder(FolderItem)

    var id: String {
        switch self {
        case .app(let app):
            return "app-\(app.id)"
        case .folder(let folder):
            return "folder-\(folder.id)"
        }
    }

    var app: AppItem? {
        if case .app(let app) = self {
            return app
        }
        return nil
    }

    var folder: FolderItem? {
        if case .folder(let folder) = self {
            return folder
        }
        return nil
    }
}
