import Foundation

enum LectureSourceKind: String, Codable, Sendable, Equatable {
    case display
    case window
}

/// Safe, transportable metadata for a Mac-authoritative capture source.
/// The numeric identifier is meaningful only within the current connection.
///
/// Deliberately not `Identifiable`: `id` is a `CGWindowID` or a
/// `CGDirectDisplayID`, and those share no namespace, so a window and a display
/// can carry the same number. Use `qualifiedIdentity` wherever a unique key is
/// required — an `Identifiable` conformance on `id` alone silently collides.
struct LectureSourceDescriptor: Codable, Sendable, Equatable {
    private static let maximumNameBytes = 256
    private static let maximumDimension = 16_384

    let id: UInt32
    let kind: LectureSourceKind
    let name: String
    let width: Int
    let height: Int

    init(id: UInt32, kind: LectureSourceKind, name: String, width: Int, height: Int) {
        self.id = id
        self.kind = kind
        self.name = name
        self.width = width
        self.height = height
    }

    var aspectRatio: Double {
        guard width > 0, height > 0 else { return 1 }
        return Double(width) / Double(height)
    }

    /// Unique across both source kinds, unlike `id` on its own.
    var qualifiedIdentity: String { "\(kind.rawValue):\(id)" }

    private enum CodingKeys: String, CodingKey {
        case id, kind, name, width, height
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UInt32.self, forKey: .id)
        let kind = try container.decode(LectureSourceKind.self, forKey: .kind)
        let name = try container.decode(String.self, forKey: .name)
        let width = try container.decode(Int.self, forKey: .width)
        let height = try container.decode(Int.self, forKey: .height)

        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.utf8.count <= Self.maximumNameBytes,
              (1...Self.maximumDimension).contains(width),
              (1...Self.maximumDimension).contains(height) else {
            throw DecodingError.dataCorruptedError(
                forKey: .name,
                in: container,
                debugDescription: "Lecture source metadata is outside supported bounds."
            )
        }

        self.init(id: id, kind: kind, name: name, width: width, height: height)
    }
}

enum LectureSourceUnavailableReason: String, Codable, Sendable, Equatable {
    case closed
    case minimized
    case permissionRequired
    case captureFailed
    case noLongerAvailable
    /// The Mac's owner dismissed the picker instead of approving a source.
    /// Distinct from the failure cases so the iPad does not report a problem
    /// the Mac never had.
    case declined
}
