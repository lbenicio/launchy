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
        case let .app(app):
            "app-\(app.id)"
        case let .folder(folder):
            "folder-\(folder.id)"
        }
    }

    var app: AppItem? {
        if case let .app(app) = self {
            return app
        }
        return nil
    }

    var folder: FolderItem? {
        if case let .folder(folder) = self {
            return folder
        }
        return nil
    }
}
