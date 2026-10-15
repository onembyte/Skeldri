import Foundation
import Testing

struct ConnectionLifecycleTests {
    @Test func terminalNotificationIsDeliveredOnlyOnce() {
        let gate = OneShotGate()
        #expect(gate.take())
        #expect(!gate.take())
        #expect(!gate.take())
    }

    @Test func staleConnectionGenerationCannotAffectReplacement() {
        var gate = ConnectionGenerationGate()
        let first = gate.begin()
        #expect(gate.contains(first))

        let replacement = gate.begin()
        #expect(!gate.contains(first))
        #expect(gate.contains(replacement))

        gate.invalidate()
        #expect(!gate.contains(replacement))
    }
}
