import Foundation

// MARK: - StubFileManager

/// A `FileManager` subclass that optionally redirects Application Support queries
/// to a temporary directory, and always blocks real `/Applications` paths so tests
/// never touch the host system.
///
/// Usage:
/// - `StubFileManager(applicationSupportDirectory: url)` — redirects app support
///   AND blocks system app directories. Use for tests that exercise persistence.
/// - `StubFileManager()` — only blocks system app directories. Use for tests that
///   exercise app-scanning logic without needing a fake persistence location.
final class StubFileManager: FileManager {
    private let _applicationSupportDirectory: URL?
    private let blockedPaths: Set<String>

    init(applicationSupportDirectory: URL) {
        _applicationSupportDirectory = applicationSupportDirectory
        blockedPaths = Self.makeBlockedPaths()
        super.init()
    }

    override init() {
        _applicationSupportDirectory = nil
        blockedPaths = Self.makeBlockedPaths()
        super.init()
    }

    private static func makeBlockedPaths() -> Set<String> {
        let homeApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .path
        return Set([
            "/Applications",
            "/System/Applications",
            NSString(string: homeApplications).standardizingPath,
        ])
    }

    override func urls(
        for directory: FileManager.SearchPathDirectory,
        in domainMask: FileManager.SearchPathDomainMask
    ) -> [URL] {
        if directory == .applicationSupportDirectory,
            let dir = _applicationSupportDirectory
        {
            return [dir]
        }
        return super.urls(for: directory, in: domainMask)
    }

    override func fileExists(atPath path: String) -> Bool {
        let normalized = NSString(string: path).standardizingPath
        if blockedPaths.contains(normalized) { return false }
        return super.fileExists(atPath: path)
    }

    override func fileExists(
        atPath path: String,
        isDirectory: UnsafeMutablePointer<ObjCBool>?
    ) -> Bool {
        let normalized = NSString(string: path).standardizingPath
        if blockedPaths.contains(normalized) {
            isDirectory?.pointee = false
            return false
        }
        return super.fileExists(atPath: path, isDirectory: isDirectory)
    }
}
