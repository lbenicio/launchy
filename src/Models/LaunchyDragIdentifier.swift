import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct LaunchyDragIdentifier: Transferable, Codable, Hashable, Sendable {
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

extension LaunchyDragIdentifier {
    func makeProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        let payload = self
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.launchyItemIdentifier.identifier,
            visibility: .all
        ) { completion -> Progress? in
            do {
                let data = try JSONEncoder().encode(payload)
                completion(data, nil)
            } catch {
                completion(nil, error)
            }
            return nil
        }
        return provider
    }
}

extension UTType {
    static let launchyItemIdentifier = UTType(exportedAs: "dev.lbenicio.launchy.item")
}
