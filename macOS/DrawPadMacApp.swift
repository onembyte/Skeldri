import AppKit
import ScreenCaptureKit
import SwiftUI

@main
struct DrawPadMacApp: App {
    @StateObject private var model = MacAppModel()
    var body: some Scene { WindowGroup { MacMainView(model: model).task { await model.start() } }.windowResizability(.contentSize) }
}

@MainActor
final class MacAppModel: ObservableObject {
    @Published var displays: [DisplayDescriptor] = []
    @Published var selectedDisplayID: UInt32?
    @Published var capturePermission = CGPreflightScreenCaptureAccess()
    @Published var listenerReady = false
    @Published var connected = false
    @Published var annotationsVisible = true
    @Published var errorMessage: String?
    let drawingState = DrawingState()
    private let overlay = OverlayWindowController()
    private let server = MacNetworkServer()
    private let capture = ScreenCaptureManager()
    private let encoder = H264Encoder()
    private var screenPairs: [(SCDisplay, DisplayDescriptor)] = []

    init() {
        server.onConnectionChanged = { [weak self] value in Task { @MainActor in self?.connected = value } }
        server.onControlPacket = { [weak self] packet in Task { @MainActor in self?.apply(packet) } }
        server.onVideoChannelChanged = { [weak self] connected in Task { @MainActor in if connected { await self?.startStreaming() } else { await self?.stopStreaming() } } }
        capture.consumer = encoder
        encoder.onConfiguration = { [weak server] configuration in server?.sendVideoConfiguration(configuration) }
        encoder.onFrame = { [weak server] frame in server?.sendVideoFrame(frame.data, header: VideoFrameHeader(presentationTime: frame.presentationTime, isKeyframe: frame.isKeyframe)) }
    }

    func start() async {
        // Discovery must remain available even when screen-recording permission or
        // ScreenCaptureKit display enumeration is unavailable.
        do {
            try server.start(); listenerReady = true
        } catch {
            errorMessage = "Local network listener failed: \(error.localizedDescription)"
            return
        }
        do {
            screenPairs = try await DisplayManager().availableDisplays(); displays = screenPairs.map(\.1)
            selectedDisplayID = displays.first?.id; showOverlayForSelection()
        } catch {
            errorMessage = "Display enumeration failed: \(error.localizedDescription)"
        }
    }

    func selectDisplay(_ id: UInt32?) { showOverlayForSelection() }
    func toggleOverlay() { annotationsVisible.toggle(); annotationsVisible ? showOverlayForSelection() : overlay.hide() }
    func clear() { drawingState.clear(); overlay.annotationView.strokes = []; server.sendControl(.clear) }

    private func startStreaming() async {
        guard capturePermission, let id = selectedDisplayID, let display = screenPairs.first(where: { $0.1.id == id })?.0 else { errorMessage = "Screen Recording permission is required."; return }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let ownBundleID = Bundle.main.bundleIdentifier
            try await capture.start(display: display, excluding: content.applications.filter { $0.bundleIdentifier == ownBundleID })
            if let descriptor = displays.first(where: { $0.id == id }) { server.sendControl(.display(descriptor)) }
        } catch { errorMessage = "Capture failed: \(error.localizedDescription)" }
    }

    private func stopStreaming() async { await capture.stop(); encoder.invalidate() }

    private func showOverlayForSelection() {
        guard annotationsVisible, let id = selectedDisplayID,
              let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == id }) else { return }
        overlay.show(on: screen)
    }

    private func apply(_ packet: ControlPacket) {
        switch packet {
        case let .strokeBegin(id, style, point): drawingState.begin(id: id, style: style, point: point)
        case let .strokePoints(id, points): drawingState.append(id: id, points: points)
        case let .strokeEnd(id): drawingState.finish(id: id)
        case let .deleteStrokes(ids): drawingState.delete(ids: ids)
        case .clear: drawingState.clear()
        case let .canvasSnapshot(strokes): drawingState.replace(with: strokes)
        case let .ping(id, sentAt): server.sendControl(.pong(id: id, sentAt: sentAt))
        default: break
        }
        overlay.annotationView.strokes = drawingState.strokes
    }
}
