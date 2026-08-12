import SwiftUI
import UIKit

@main
struct SkeldriPadApp: App {
    @StateObject private var model = iPadAppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if model.connected {
                    DrawingScreen(model: model)
                } else {
                    DiscoveryView(model: model)
                }
            }
            .task { model.start() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { model.disconnect() }
                else if phase != .active { model.suspendPointerInput() }
            }
            .alert("Skeldri", isPresented: $model.showingError) {
                Button("OK") {}
            } message: {
                Text(model.errorMessage ?? "Unknown error")
            }
        }
    }
}

@MainActor
final class iPadAppModel: ObservableObject {
    @Published var macs: [DiscoveredMac] = []
    @Published var connected = false { didSet { UIApplication.shared.isIdleTimerDisabled = connected } }
    @Published var awaitingMacApproval = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var style = StrokeStyle.defaultPen
    @Published var mode: DrawingInteractionMode = .draw
    @Published var color = Color.red
    @Published var width = 0.005
    @Published var videoAspectRatio: CGFloat = 16 / 10
    @Published var displays: [DisplayDescriptor] = []
    @Published var selectedDisplayID: UInt32?
    @Published var pendingDisplayID: UInt32?
    @Published var clearsDrawingsWhenSwitchingDisplays = false
    @Published var inputMode: SkeldriInputMode = .drawing
    @Published private(set) var lectureSession = LectureSession()
    @Published var trackpadSensitivity: Double {
        didSet { UserDefaults.standard.set(trackpadSensitivity, forKey: Self.trackpadSensitivityKey) }
    }
    @Published var trackpadSpeed: Double {
        didSet { UserDefaults.standard.set(trackpadSpeed, forKey: Self.trackpadSpeedKey) }
    }
    @Published var trackpadAccelerationEnabled: Bool {
        didSet { UserDefaults.standard.set(trackpadAccelerationEnabled, forKey: Self.trackpadAccelerationKey) }
    }
    let drawingState = DrawingState()
    let decoder = H264Decoder()
    private let network = iPadNetworkClient()
    private var trackpadSequence: UInt64 = 0
    private static let trackpadSensitivityKey = "trackpad.sensitivity"
    private static let trackpadSpeedKey = "trackpad.speed"
    private static let trackpadAccelerationKey = "trackpad.acceleration"

    init() {
        let defaults = UserDefaults.standard
        trackpadSensitivity = defaults.object(forKey: Self.trackpadSensitivityKey) == nil
            ? 1 : defaults.double(forKey: Self.trackpadSensitivityKey)
        trackpadSpeed = defaults.object(forKey: Self.trackpadSpeedKey) == nil
            ? 1.35 : defaults.double(forKey: Self.trackpadSpeedKey)
        trackpadAccelerationEnabled = defaults.object(forKey: Self.trackpadAccelerationKey) == nil
            ? true : defaults.bool(forKey: Self.trackpadAccelerationKey)
        network.onServicesChanged = { [weak self] values in Task { @MainActor in self?.macs = values } }
        network.onStateChanged = { [weak self] value, error in Task { @MainActor in
            guard let self else { return }
            self.connected = value
            if !value {
                if self.lectureSession.state != .inactive {
                    self.lectureSession.apply(.disconnected)
                }
                self.inputMode = .drawing
                self.awaitingMacApproval = false
                self.decoder.reset()
            }
            if let error { self.errorMessage = error; self.showingError = true }
        } }
        network.onControlPacket = { [weak self] packet in Task { @MainActor in self?.apply(packet) } }
        decoder.onFrameConsumed = { [weak network] receipt in
            network?.send(.videoAcknowledgement(
                streamID: receipt.streamID,
                sequence: receipt.sequence,
                requiresKeyframe: receipt.requiresKeyframe
            ))
        }
        network.onVideoPacket = { [weak self] packet in
            guard let self else { return }
            if packet.type == .videoConfiguration, let configuration = try? JSONDecoder().decode(VideoConfiguration.self, from: packet.payload) { decoder.configure(configuration) }
            if packet.type == .videoFrame { decoder.decode(payload: packet.payload) }
        }
    }
    func start() { network.startBrowsing() }
    func refreshDiscovery() { network.refreshBrowsing() }
    func connect(_ mac: DiscoveredMac) {
        awaitingMacApproval = true
        network.connect(to: mac.endpoint)
    }
    func disconnect() {
        sendTrackpadReset()
        if inputMode == .lecture { network.send(.leaveLectureMode) }
        network.send(.inputMode(.drawing))
        network.disconnect()
        decoder.reset()
        inputMode = .drawing
        lectureSession.apply(.leave)
        awaitingMacApproval = false
    }
    func setInputMode(_ newMode: SkeldriInputMode) {
        guard newMode != inputMode else { return }
        let transition = ExperienceModeTransition(from: inputMode, to: newMode)
        if transition.mustResetTrackpad { sendTrackpadReset() }
        if inputMode == .lecture {
            network.send(.leaveLectureMode)
            lectureSession.apply(.leave)
        }

        inputMode = newMode
        network.send(.inputMode(newMode))
        if newMode == .lecture {
            beginLectureSourceSelection()
        }
    }
    func requestLectureSourceSelection() {
        guard inputMode == .lecture else { return }
        beginLectureSourceSelection()
    }
    func suspendPointerInput() {
        guard inputMode == .trackpad else { return }
        sendTrackpadReset()
    }
    func sendTrackpadMove(deltaX: CGFloat, deltaY: CGFloat) {
        sendTrackpad(.move(sequence: nextTrackpadSequence(), deltaX: Float(deltaX), deltaY: Float(deltaY)))
    }
    func sendTrackpadScroll(deltaX: CGFloat, deltaY: CGFloat) {
        sendTrackpad(.scroll(sequence: nextTrackpadSequence(), deltaX: Float(deltaX), deltaY: Float(deltaY)))
    }
    func sendTrackpadMagnify(delta: CGFloat) {
        sendTrackpad(.magnify(sequence: nextTrackpadSequence(), delta: Float(delta)))
    }
    func sendTrackpadButton(_ button: TrackpadButton, isDown: Bool, clickCount: Int) {
        sendTrackpad(.button(sequence: nextTrackpadSequence(), button: button, isDown: isDown, clickCount: clickCount))
    }
    var trackpadMotionSettings: TrackpadMotionSettings {
        TrackpadMotionSettings(
            sensitivity: CGFloat(trackpadSensitivity),
            speed: CGFloat(trackpadSpeed),
            accelerationEnabled: trackpadAccelerationEnabled
        )
    }
    func choosePen() { mode = .draw; style = StrokeStyle(tool: .pen, red: style.red, green: style.green, blue: style.blue, alpha: 1, normalizedWidth: Float(width)) }
    func chooseHighlighter() { mode = .draw; style = StrokeStyle(tool: .highlighter, red: style.red, green: style.green, blue: style.blue, alpha: 0.3, normalizedWidth: Float(max(width, 0.015))) }
    func updateColor(_ color: Color) { let resolved = UIColor(color); var r: CGFloat=0,g: CGFloat=0,b: CGFloat=0,a: CGFloat=0; resolved.getRed(&r, green:&g, blue:&b, alpha:&a); style = StrokeStyle(tool: style.tool, red: Float(r), green: Float(g), blue: Float(b), alpha: style.alpha, normalizedWidth: style.normalizedWidth) }
    func updateWidth(_ width: Double) { style = StrokeStyle(tool: style.tool, red: style.red, green: style.green, blue: style.blue, alpha: style.alpha, normalizedWidth: Float(width)) }
    func handleLocal(_ packet: ControlPacket) { apply(packet); network.send(packet) }
    func undo() { if let id = drawingState.undo() { network.send(.deleteStrokes(ids: [id])) } }
    func clear() { drawingState.clear(); network.send(.clear) }
    func selectDisplay(_ id: UInt32) {
        guard selectedDisplayID != id, pendingDisplayID != id else { return }
        if clearsDrawingsWhenSwitchingDisplays { clear() }
        pendingDisplayID = id
        network.send(.selectDisplay(id: id))
    }
    private func sendTrackpadReset() {
        sendTrackpad(.reset(sequence: nextTrackpadSequence()))
    }
    private func sendTrackpad(_ event: TrackpadEvent) {
        if inputMode != .trackpad {
            guard case .reset = event else { return }
        }
        network.send(.trackpad(event))
    }
    private func nextTrackpadSequence() -> UInt64 {
        defer { trackpadSequence &+= 1 }
        return trackpadSequence
    }
    private func apply(_ packet: ControlPacket) {
        switch packet {
        case .authorizationRequired:
            awaitingMacApproval = true
        case let .authorizationResult(approved):
            awaitingMacApproval = false
            if approved {
                connected = true
            } else {
                network.disconnect()
                errorMessage = "The connection was not allowed on the Mac."
                showingError = true
            }
        case let .strokeBegin(id, style, point): drawingState.begin(id:id, style:style, point:point)
        case let .strokePoints(id, points): drawingState.append(id:id, points:points)
        case let .strokeEnd(id): drawingState.finish(id:id)
        case let .deleteStrokes(ids): drawingState.delete(ids:ids)
        case .clear: drawingState.clear()
        case let .canvasSnapshot(value): drawingState.replace(with:value)
        case let .displays(values): displays = values
        case let .display(display):
            // Read mode owns the viewport; a display announcement must not reset
            // its decoder or aspect ratio underneath the reader.
            guard inputMode != .lecture else { break }
            // Only a real switch invalidates decoder state. Resetting when the
            // iPad merely learns its first display races the video channel:
            // control packets hop to the main actor while video configuration
            // is applied synchronously, so this reset could land after the
            // decoder was configured and leave it with no format at all.
            if let current = selectedDisplayID, current != display.id { decoder.reset() }
            selectedDisplayID = display.id
            if pendingDisplayID == display.id { pendingDisplayID = nil }
            videoAspectRatio = CGFloat(display.aspectRatio)
        case let .lectureSourceSelected(source, generation):
            if lectureSession.apply(.sourceSelected(source, generation: generation)) {
                decoder.reset()
                videoAspectRatio = CGFloat(source.aspectRatio)
            }
        case let .lectureSourceUnavailable(reason, generation):
            lectureSession.apply(.sourceUnavailable(reason, generation: generation))
        case let .incompatibleVersion(expected): errorMessage = "Incompatible protocol version. Mac expects \(expected)."; showingError = true
        default: break
        }
    }
    private func beginLectureSourceSelection() {
        let requestID = UUID()
        lectureSession.apply(.enter(requestID: requestID))
        network.send(.requestLectureSourceSelection(requestID: requestID))
    }
}
