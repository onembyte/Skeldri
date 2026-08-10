import Foundation

enum WirePacketType: UInt8, Sendable { case control = 1, videoConfiguration = 2, videoFrame = 3 }

struct FramedPacket: Sendable, Equatable { let type: WirePacketType; let payload: Data }

enum PacketFramerError: Error, Equatable { case invalidLength(Int); case unknownType(UInt8) }

/// Stateful TCP stream parser supporting fragmented and coalesced receives.
struct PacketFramer: Sendable {
    static let controlLimit = 1_048_576
    static let videoLimit = 16_777_216
    private(set) var buffer = Data()
    let maximumPayloadLength: Int

    init(maximumPayloadLength: Int = PacketFramer.controlLimit) { self.maximumPayloadLength = maximumPayloadLength }

    static func frame(type: WirePacketType, payload: Data) -> Data {
        let length = UInt32(payload.count + 1)
        var value = length.bigEndian
        var result = withUnsafeBytes(of: &value) { Data($0) }
        result.append(type.rawValue)
        result.append(payload)
        return result
    }

    mutating func append(_ data: Data) throws -> [FramedPacket] {
        buffer.append(data)
        var packets: [FramedPacket] = []
        while buffer.count >= 4 {
            let length = buffer.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard length >= 1, length <= maximumPayloadLength + 1 else { throw PacketFramerError.invalidLength(Int(length)) }
            let total = 4 + Int(length)
            guard buffer.count >= total else { break }
            let rawType = buffer[buffer.startIndex + 4]
            guard let type = WirePacketType(rawValue: rawType) else { throw PacketFramerError.unknownType(rawType) }
            let payloadStart = buffer.startIndex + 5
            let payloadEnd = buffer.startIndex + total
            packets.append(FramedPacket(type: type, payload: Data(buffer[payloadStart..<payloadEnd])))
            buffer.removeFirst(total)
        }
        return packets
    }
}

