import Foundation
import UIKit

enum PendingMediaKind: Hashable {
    case image
    case video
}

struct PendingMediaItem: Identifiable, Hashable {
    let id: UUID
    let image: UIImage?
    let videoURL: URL?
    let fileName: String
    let kind: PendingMediaKind

    init(
        id: UUID = UUID(),
        image: UIImage? = nil,
        videoURL: URL? = nil,
        fileName: String,
        kind: PendingMediaKind
    ) {
        self.id = id
        self.image = image
        self.videoURL = videoURL
        self.fileName = fileName
        self.kind = kind
    }

    static func == (lhs: PendingMediaItem, rhs: PendingMediaItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
