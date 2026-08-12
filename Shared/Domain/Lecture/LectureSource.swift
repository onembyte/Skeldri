import Foundation

enum LectureSourceKind: String, Codable, Sendable, Equatable {
    case display
    case window
}

/// Safe, transportable metadata for a Mac-authoritative capture source.
/// The numeric identifier is meaningful only within the current connection.
struct LectureSourceDescriptor: Identifiable, Codable, Sendable, Equatable {
    let id: UInt32
    let kind: LectureSourceKind
    let name: String
    let width: Int
    let height: Int

    var aspectRatio: Double {
        guard width > 0, height > 0 else { return 1 }
        return Double(width) / Double(height)
    }
}

enum LectureSourceUnavailableReason: String, Codable, Sendable, Equatable {
    case closed
    case minimized
    case permissionRequired
    case captureFailed
    case noLongerAvailable
}
