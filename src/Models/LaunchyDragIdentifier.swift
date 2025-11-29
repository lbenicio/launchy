import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct LaunchyDragIdentifier: Transferable, Codable, Hashable {
    let itemID: UUID
    let sourceFolderID: UUID?

    init(itemID: UUID, sourceFolderID: UUID? = nil) {
        self.itemID = itemID
        self.sourceFolderID = sourceFolderID
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .launchyItemIdentifier)
    }
}

extension UTType {
    static let launchyItemIdentifier = UTType(exportedAs: "dev.lbenicio.launchy.item")
}
