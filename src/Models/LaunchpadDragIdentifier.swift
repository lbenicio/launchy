import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct LaunchpadDragIdentifier: Transferable, Codable, Hashable {
    let itemID: UUID
    let sourceFolderID: UUID?

    init(itemID: UUID, sourceFolderID: UUID? = nil) {
        self.itemID = itemID
        self.sourceFolderID = sourceFolderID
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .launchpadItemIdentifier)
    }
}

extension UTType {
    static let launchpadItemIdentifier = UTType(exportedAs: "com.tahoe.launchpad.item")
}
