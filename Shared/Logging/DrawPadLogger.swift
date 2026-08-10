import OSLog

enum DrawPadLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "DrawPad"
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let video = Logger(subsystem: subsystem, category: "video")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let drawing = Logger(subsystem: subsystem, category: "drawing")
    static let overlay = Logger(subsystem: subsystem, category: "overlay")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
