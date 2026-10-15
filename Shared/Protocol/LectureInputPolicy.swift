import Foundation

/// Read-only enforcement for Lecture.
///
/// The iPad already hides both input surfaces in Read mode, but that is a
/// presentation guarantee. This policy makes the Mac refuse mutating packets
/// regardless of what a peer actually sends, so a modified or malfunctioning
/// client cannot draw on or drive the Mac while it claims to be reading.
///
/// Only Lecture is constrained. Draw and Trackpad keep their existing,
/// separately validated behavior.
enum LectureInputPolicy {
    static func allows(_ packet: ControlPacket, whileIn mode: SkeldriInputMode) -> Bool {
        guard mode == .lecture else { return true }
        switch packet {
        case .strokeBegin, .strokePoints, .strokeEnd, .deleteStrokes, .clear, .canvasSnapshot:
            return false
        case let .trackpad(event):
            // A reset only releases buttons a previous mode may have left held,
            // so it stays allowed; it is the fail-safe, not an input.
            if case .reset = event { return true }
            return false
        default:
            return true
        }
    }
}
