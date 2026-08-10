import CoreGraphics
import Testing

struct CoordinateMapperTests {
    @Test func sameAspectCenterAndCorners() {
        let mapper = CoordinateMapper(container: CGRect(x: 0, y: 0, width: 160, height: 100), videoAspectRatio: 1.6)
        #expect(mapper.normalizedPoint(for: CGPoint(x: 80, y: 50)) == CGPoint(x: 0.5, y: 0.5))
        #expect(mapper.normalizedPoint(for: .zero) == .zero)
        #expect(mapper.normalizedPoint(for: CGPoint(x: 160, y: 100)) == CGPoint(x: 1, y: 1))
    }
    @Test func pillarboxRejectsOutside() {
        let mapper = CoordinateMapper(container: CGRect(x: 0, y: 0, width: 200, height: 100), videoAspectRatio: 1)
        #expect(mapper.videoRect == CGRect(x: 50, y: 0, width: 100, height: 100))
        #expect(mapper.normalizedPoint(for: CGPoint(x: 20, y: 50)) == nil)
        #expect(mapper.normalizedPoint(for: CGPoint(x: 100, y: 50)) == CGPoint(x: 0.5, y: 0.5))
    }
    @Test func letterboxAndRotation() {
        let mapper = CoordinateMapper(container: CGRect(x: 0, y: 0, width: 100, height: 200), videoAspectRatio: 2)
        #expect(mapper.videoRect == CGRect(x: 0, y: 75, width: 100, height: 50))
        #expect(mapper.normalizedPoint(for: CGPoint(x: 50, y: 20)) == nil)
    }
}

