import CoreGraphics
import Foundation
import Testing

struct StrokeHitTestingTests {
    @Test func hitMissWidthsAndMultiple() {
        let a = Stroke(id: UUID(), style: .defaultPen, points: [.init(x:0.1,y:0.1,timestamp:0,pressure:nil), .init(x:0.9,y:0.1,timestamp:1,pressure:nil)])
        let thick = Stroke(id: UUID(), style: .init(tool:.highlighter,red:1,green:1,blue:0,alpha:0.3,normalizedWidth:0.1), points:[.init(x:0.5,y:0.5,timestamp:0,pressure:nil)])
        #expect(StrokeHitTesting.hitStrokeIDs(at: CGPoint(x:50,y:10), strokes:[a,thick], canvasSize:CGSize(width:100,height:100), additionalTolerance:1) == [a.id])
        #expect(StrokeHitTesting.hitStrokeIDs(at: CGPoint(x:54,y:50), strokes:[a,thick], canvasSize:CGSize(width:100,height:100), additionalTolerance:0) == [thick.id])
        #expect(StrokeHitTesting.hitStrokeIDs(at: CGPoint(x:99,y:99), strokes:[a,thick], canvasSize:CGSize(width:100,height:100), additionalTolerance:0).isEmpty)
    }
}
