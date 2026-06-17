import AppKit
import Foundation
import SQLite3

/// Reads the macOS Launchpad layout from the Dock SQLite database and
/// converts it into a `[LaunchyItem]` array that can be applied directly
/// to `LaunchyViewModel.items`.
///
/// The Launchpad database lives at
/// `~/Library/Application Support/Dock/<uuid>.db`.
/// It is opened read-only so the live Launchpad layout is never modified.
@MainActor
struct LaunchpadImporter {

    // MARK: - Public API

    /// Locates the Launchpad database, parses its layout, and returns the
    /// resulting item array.  Returns `nil` when no suitable database file
    /// is found; throws when the file exists but cannot be parsed.
    static func importLayout() throws -> [LaunchyItem]? {
        guard let dbURL = findDatabaseURL() else { return nil }
        return try importFrom(dbURL: dbURL)
    }

    // MARK: - Database discovery

    static func findDatabaseURL() -> URL? {
        let dockDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Dock")
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: dockDir,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
        else { return nil }
        // The Launchpad DB has a UUID-style name, NOT "desktopview.db"
        return contents.first {
            $0.pathExtension == "db" && $0.lastPathComponent != "desktopview.db"
        }
    }

    // MARK: - Import

    static func importFrom(dbURL: URL) throws -> [LaunchyItem] {
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil)
        guard rc == SQLITE_OK, let db else {
            throw ImportError.cannotOpenDatabase
        }
        defer { sqlite3_close(db) }

        guard hasRequiredTables(db) else { throw ImportError.unsupportedSchema }

        let pageIDs = try fetchPageIDs(db: db)
        var result: [LaunchyItem] = []
        for pageID in pageIDs {
            let items = try fetchPageContents(db: db, pageItemID: pageID)
            result.append(contentsOf: items)
        }
        return result
    }

    // MARK: - Schema validation

    private static func hasRequiredTables(_ db: OpaquePointer) -> Bool {
        let sql = """
            SELECT COUNT(*) FROM sqlite_master
            WHERE type='table'
              AND name IN ('apps','items','groups','parent_relations')
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return false }
        return sqlite3_column_int(stmt, 0) == 4
    }

    // MARK: - Pages

    private static func fetchPageIDs(db: OpaquePointer) throws -> [Int32] {
        // Pages are groups with kind=1, sorted by their ordering under the root.
        let sql = """
            SELECT g.item_id
            FROM groups g
            JOIN parent_relations pr ON pr.child_id = g.item_id
            WHERE g.kind = 1
            ORDER BY pr.ordering
            """
        return try queryInts(db: db, sql: sql)
    }

    // MARK: - Page contents

    private static func fetchPageContents(
        db: OpaquePointer,
        pageItemID: Int32
    ) throws -> [LaunchyItem] {
        let sql = """
            SELECT pr.child_id,
                   a.title, a.bundleID, a.url,
                   g.name,  g.kind
            FROM parent_relations pr
            LEFT JOIN apps   a ON a.item_id    = pr.child_id
            LEFT JOIN groups g ON g.item_id    = pr.child_id
            WHERE pr.parent_id = ?
              AND (a.title IS NOT NULL OR g.kind = 2)
            ORDER BY pr.ordering
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ImportError.queryFailed
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, pageItemID)

        var items: [LaunchyItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let childID = sqlite3_column_int(stmt, 0)
            let gKind = sqlite3_column_type(stmt, 5) != SQLITE_NULL
                ? sqlite3_column_int(stmt, 5) : -1

            if gKind == 2 {
                // Folder
                let folderName = str(stmt, 4) ?? "Folder"
                let apps = (try? fetchFolderContents(db: db, folderItemID: childID)) ?? []
                guard !apps.isEmpty else { continue }
                items.append(.folder(LaunchyFolder(name: folderName, apps: apps)))
            } else if let title = str(stmt, 1),
                let bundleID = str(stmt, 2),
                let urlStr = str(stmt, 3)
            {
                let url = resolvedURL(urlStr: urlStr, bundleID: bundleID)
                items.append(.app(AppIcon(name: title, bundleIdentifier: bundleID, bundleURL: url)))
            }
        }
        return items
    }

    // MARK: - Folder contents

    private static func fetchFolderContents(
        db: OpaquePointer,
        folderItemID: Int32
    ) throws -> [AppIcon] {
        let sql = """
            SELECT a.title, a.bundleID, a.url
            FROM apps a
            JOIN parent_relations pr ON pr.child_id = a.item_id
            WHERE pr.parent_id = ? AND a.title IS NOT NULL
            ORDER BY pr.ordering
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ImportError.queryFailed
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, folderItemID)

        var apps: [AppIcon] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let title = str(stmt, 0),
                let bundleID = str(stmt, 1),
                let urlStr = str(stmt, 2)
            else { continue }
            let url = resolvedURL(urlStr: urlStr, bundleID: bundleID)
            apps.append(AppIcon(name: title, bundleIdentifier: bundleID, bundleURL: url))
        }
        return apps
    }

    // MARK: - Helpers

    private static func queryInts(db: OpaquePointer, sql: String) throws -> [Int32] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ImportError.queryFailed
        }
        defer { sqlite3_finalize(stmt) }
        var out: [Int32] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(sqlite3_column_int(stmt, 0))
        }
        return out
    }

    private static func str(_ stmt: OpaquePointer?, _ col: Int32) -> String? {
        guard let stmt, let raw = sqlite3_column_text(stmt, col) else { return nil }
        return String(cString: raw)
    }

    /// Resolves the DB URL string to a local file URL, falling back to
    /// `NSWorkspace` lookup when the stored path cannot be directly resolved.
    private static func resolvedURL(urlStr: String, bundleID: String) -> URL {
        if urlStr.hasPrefix("file://"), let url = URL(string: urlStr) {
            return url
        }
        if let resolved = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID)
        {
            return resolved
        }
        return URL(fileURLWithPath: urlStr)
    }

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case cannotOpenDatabase
        case unsupportedSchema
        case queryFailed

        var errorDescription: String? {
            switch self {
            case .cannotOpenDatabase:
                return "Cannot open the Launchpad database."
            case .unsupportedSchema:
                return "The Launchpad database schema is not supported on this macOS version."
            case .queryFailed:
                return "A database query failed."
            }
        }
    }
}
