import AppKit
import CoreGraphics

/// Permission-gated adapter from validated protocol events to Quartz input.
/// A dedicated serial queue owns ordering, button state, and replay protection.
final class MacInputController: @unchecked Sendable {
    var onPermissionChanged: (@Sendable (Bool) -> Void)?

    private let queue = DispatchQueue(label: "Skeldri.input", qos: .userInteractive)
    private var sequenceGate = TrackpadSequenceGate()
    private var active = false
    private var leftButtonDown = false
    private var rightButtonDown = false
    private var scrollAccumulator = TrackpadScrollAccumulator()
    private var magnifyAccumulator = TrackpadMagnifyAccumulator()
    private var cursor = TrackpadCursorTracker()
    private var desktopBounds = CGRect.null

    var hasPermission: Bool { CGPreflightPostEventAccess() }

    func requestPermission() {
        DispatchQueue.main.async { [weak self] in
            let granted = CGRequestPostEventAccess()
            self?.onPermissionChanged?(granted)
        }
    }

    func setActive(_ value: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            active = value
            sequenceGate.reset()
            cursor.invalidate()
            desktopBounds = Self.activeDesktopBounds()
            if value {
                if !CGPreflightPostEventAccess() { requestPermission() }
            } else {
                releaseAllButtons()
            }
            onPermissionChanged?(CGPreflightPostEventAccess())
        }
    }

    func handle(_ untrustedEvent: TrackpadEvent) {
        queue.async { [weak self] in
            guard let self, active, CGPreflightPostEventAccess(),
                  let event = TrackpadInputValidator.validated(untrustedEvent),
                  sequenceGate.accepts(event.sequence) else { return }
            apply(event)
        }
    }

    func reset() {
        queue.async { [weak self] in
            self?.releaseAllButtons()
            self?.sequenceGate.reset()
            self?.cursor.invalidate()
        }
    }

    /// Global display bounds share the top-left origin that `CGEvent` locations
    /// use. `NSScreen.frame` does not, so it must not be substituted here.
    private static func activeDesktopBounds() -> CGRect {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return .null }
        var identifiers = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &identifiers, &count) == .success else { return .null }
        return identifiers.prefix(Int(count)).reduce(CGRect.null) { $0.union(CGDisplayBounds($1)) }
    }

    private func apply(_ event: TrackpadEvent) {
        switch event {
        case let .move(_, deltaX, deltaY):
            move(deltaX: CGFloat(deltaX), deltaY: CGFloat(deltaY))
        case let .scroll(_, deltaX, deltaY):
            scroll(deltaX: deltaX, deltaY: deltaY)
        case let .magnify(_, delta):
            magnify(delta: delta)
        case let .button(_, button, isDown, clickCount):
            setButton(button, down: isDown, clickCount: clickCount)
        case .reset:
            releaseAllButtons()
        }
    }

    private func move(deltaX: CGFloat, deltaY: CGFloat) {
        guard let current = CGEvent(source: nil)?.location else { return }
        let destination = cursor.nextLocation(
            systemLocation: current, deltaX: deltaX, deltaY: deltaY,
            bounds: desktopBounds, now: CFAbsoluteTimeGetCurrent()
        )
        let type: CGEventType
        let button: CGMouseButton
        if leftButtonDown {
            type = .leftMouseDragged; button = .left
        } else if rightButtonDown {
            type = .rightMouseDragged; button = .right
        } else {
            type = .mouseMoved; button = .left
        }
        CGEvent(mouseEventSource: nil, mouseType: type,
                mouseCursorPosition: destination, mouseButton: button)?.post(tap: .cghidEventTap)
    }

    private func scroll(deltaX: Float, deltaY: Float) {
        let step = scrollAccumulator.consume(deltaX: deltaX, deltaY: deltaY)
        guard step != .zero else { return }
        // Negating produces macOS natural scrolling: content follows the fingers.
        CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                wheel1: -step.vertical, wheel2: -step.horizontal, wheel3: 0)?.post(tap: .cghidEventTap)
    }

    /// CoreGraphics has no supported system-wide synthetic magnify-event API.
    /// Standard Command-Plus/Minus shortcuts provide a public, dependable zoom
    /// path in Safari, Preview, editors, and most document applications.
    private func magnify(delta: Float) {
        let steps = magnifyAccumulator.consume(delta: delta)
        guard steps != 0 else { return }
        let zoomIn = steps > 0
        for _ in 0..<abs(steps) { postZoomShortcut(zoomIn: zoomIn) }
    }

    private func postZoomShortcut(zoomIn: Bool) {
        let keyCode: CGKeyCode = zoomIn ? 24 : 27 // ANSI '='/'+' and '-'.
        let flags: CGEventFlags = zoomIn ? [.maskCommand, .maskShift] : [.maskCommand]
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: isDown) else { continue }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }

    private func setButton(_ button: TrackpadButton, down: Bool, clickCount: Int) {
        switch button {
        case .left:
            guard leftButtonDown != down else { return }
            leftButtonDown = down
            postButton(.left, down: down, clickCount: clickCount)
        case .right:
            guard rightButtonDown != down else { return }
            rightButtonDown = down
            postButton(.right, down: down, clickCount: clickCount)
        }
    }

    private func postButton(_ button: CGMouseButton, down: Bool, clickCount: Int) {
        guard let systemLocation = CGEvent(source: nil)?.location else { return }
        // Post where the pointer was last commanded to go. The system location
        // can still be the pre-move position when a tap follows movement.
        let location = cursor.currentLocation(
            systemLocation: systemLocation, now: CFAbsoluteTimeGetCurrent()
        )
        let type: CGEventType = button == .left
            ? (down ? .leftMouseDown : .leftMouseUp)
            : (down ? .rightMouseDown : .rightMouseUp)
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type,
                                  mouseCursorPosition: location, mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        event.post(tap: .cghidEventTap)
    }

    private func releaseAllButtons() {
        scrollAccumulator.reset()
        magnifyAccumulator.reset()
        if leftButtonDown { leftButtonDown = false; postButton(.left, down: false, clickCount: 1) }
        if rightButtonDown { rightButtonDown = false; postButton(.right, down: false, clickCount: 1) }
    }
}
