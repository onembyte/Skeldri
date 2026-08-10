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
    private var screenPairs: [(SCDisplay, DisplayDescriptor)] = []

    init() {
        server.onConnectionChanged = { [weak self] value in Task { @MainActor in self?.connected = value } }
        server.onControlPacket = { [weak self] packet in Task { @MainActor in self?.apply(packet) } }
    }

    func start() async {
        do {
            screenPairs = try await DisplayManager().availableDisplays(); displays = screenPairs.map(\.1)
            selectedDisplayID = displays.first?.id; showOverlayForSelection()
            try server.start(); listenerReady = true
        } catch { errorMessage = error.localizedDescription }
    }

    func selectDisplay(_ id: UInt32?) { showOverlayForSelection() }
    func toggleOverlay() { annotationsVisible.toggle(); annotationsVisible ? showOverlayForSelection() : overlay.hide() }
    func clear() { drawingState.clear(); overlay.annotationView.strokes = []; server.sendControl(.clear) }

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
