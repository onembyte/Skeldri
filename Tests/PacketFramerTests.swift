import Foundation
import Testing

struct PacketFramerTests {
    @Test func completePartialAndMultiple() throws {
        let first = PacketFramer.frame(type: .control, payload: Data("one".utf8))
        let second = PacketFramer.frame(type: .videoFrame, payload: Data("two".utf8))
        var parser = PacketFramer(maximumPayloadLength: 100)
        #expect(try parser.append(first.prefix(2)).isEmpty)
        #expect(try parser.append(first.dropFirst(2)).map(\.payload) == [Data("one".utf8)])
        #expect(try parser.append(first + second).count == 2)
    }
    @Test func malformedAndUnknown() {
        var oversized = PacketFramer(maximumPayloadLength: 1)
        #expect(throws: PacketFramerError.self) { try oversized.append(Data([0,0,0,10])) }
        var unknown = PacketFramer(maximumPayloadLength: 10)
        #expect(throws: PacketFramerError.self) { try unknown.append(Data([0,0,0,1,99])) }
    }
}

