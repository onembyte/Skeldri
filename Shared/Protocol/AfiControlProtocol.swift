import Foundation

enum AfiProtocol {
    static let version = 1
    static let serviceType = "_skeldri-afi._tcp"
}

enum AfiControlError: Error, Equatable {
    case invalidEnvelope
    case incompatibleVersion(Int)
    case unknownKind(String)
    case invalidPayload(String)
}

/// Compatibility adapter for Objective-C/iOS 10 clients. The envelope is
/// intentionally explicit and independent of Swift's synthesized enum format.
enum AfiControlCodec {
    static func decode(_ data: Data) throws -> ControlPacket {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = (object["protocolVersion"] as? NSNumber)?.intValue,
              let kind = object["kind"] as? String else { throw AfiControlError.invalidEnvelope }
        guard version == AfiProtocol.version else { throw AfiControlError.incompatibleVersion(version) }

        switch kind {
        case "hello":
            guard let rawChannel = object["channel"] as? String,
                  let channel = ConnectionChannel(rawValue: rawChannel),
                  let client = object["client"] as? String,
                  let session = object["sessionID"] as? String,
                  let sessionID = UUID(uuidString: session) else { throw AfiControlError.invalidPayload(kind) }
            return .hello(version: version, channel: channel, client: client, sessionID: sessionID)
        case "ping":
            return .ping(id: try uuid(object, "id", kind), sentAt: try double(object, "sentAt", kind))
        case "pong":
            return .pong(id: try uuid(object, "id", kind), sentAt: try double(object, "sentAt", kind))
        case "inputMode":
            guard let raw = object["mode"] as? String, let mode = SkeldriInputMode(rawValue: raw) else {
                throw AfiControlError.invalidPayload(kind)
            }
            return .inputMode(mode)
        case "selectDisplay":
            guard let number = object["id"] as? NSNumber else { throw AfiControlError.invalidPayload(kind) }
            return .selectDisplay(id: number.uint32Value)
        case "strokeBegin":
            return .strokeBegin(
                id: try uuid(object, "id", kind),
                style: try nested(StrokeStyle.self, object, "style", kind),
                point: try nested(StrokePoint.self, object, "point", kind)
            )
        case "strokePoints":
            return .strokePoints(id: try uuid(object, "id", kind),
                                 points: try nested([StrokePoint].self, object, "points", kind))
        case "strokeEnd": return .strokeEnd(id: try uuid(object, "id", kind))
        case "deleteStrokes":
            guard let strings = object["ids"] as? [String], strings.allSatisfy({ UUID(uuidString: $0) != nil }) else {
                throw AfiControlError.invalidPayload(kind)
            }
            return .deleteStrokes(ids: strings.compactMap(UUID.init(uuidString:)))
        case "clear": return .clear
        case "trackpad": return .trackpad(try nested(TrackpadEvent.self, object, "event", kind))
        case "videoAcknowledgement":
            return .videoAcknowledgement(
                streamID: try uuid(object, "streamID", kind),
                sequence: try uint64(object, "sequence", kind),
                requiresKeyframe: (object["requiresKeyframe"] as? NSNumber)?.boolValue ?? false
            )
        default: throw AfiControlError.unknownKind(kind)
        }
    }

    static func encode(_ packet: ControlPacket) throws -> Data {
        var object: [String: Any] = ["protocolVersion": AfiProtocol.version]
        switch packet {
        case let .incompatibleVersion(expected): object.merge(["kind": "incompatibleVersion", "expected": expected]) { _, new in new }
        case let .pong(id, sentAt): object.merge(["kind": "pong", "id": id.uuidString, "sentAt": sentAt]) { _, new in new }
        case let .displays(displays): object.merge(["kind": "displays", "displays": try jsonObject(displays)]) { _, new in new }
        case let .display(display): object.merge(["kind": "display", "display": try jsonObject(display)]) { _, new in new }
        case .clear: object["kind"] = "clear"
        case let .canvasSnapshot(strokes): object.merge(["kind": "canvasSnapshot", "strokes": try jsonObject(strokes)]) { _, new in new }
        default: throw AfiControlError.invalidPayload("unsupported outbound packet")
        }
        return try JSONSerialization.data(withJSONObject: object)
    }

    private static func nested<T: Decodable>(_ type: T.Type, _ object: [String: Any], _ key: String,
                                               _ kind: String) throws -> T {
        guard let value = object[key], JSONSerialization.isValidJSONObject(value) else {
            throw AfiControlError.invalidPayload(kind)
        }
        do { return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value)) }
        catch { throw AfiControlError.invalidPayload(kind) }
    }

    private static func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }

    private static func uuid(_ object: [String: Any], _ key: String, _ kind: String) throws -> UUID {
        guard let value = object[key] as? String, let id = UUID(uuidString: value) else {
            throw AfiControlError.invalidPayload(kind)
        }
        return id
    }

    private static func double(_ object: [String: Any], _ key: String, _ kind: String) throws -> Double {
        guard let value = object[key] as? NSNumber else { throw AfiControlError.invalidPayload(kind) }
        return value.doubleValue
    }

    private static func uint64(_ object: [String: Any], _ key: String, _ kind: String) throws -> UInt64 {
        guard let value = object[key] as? NSNumber else { throw AfiControlError.invalidPayload(kind) }
        return value.uint64Value
    }
}
