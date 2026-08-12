import AppKit
import ScreenCaptureKit
import SwiftUI

@main
struct SkeldriMacApp: App {
    @NSApplicationDelegateAdaptor(SkeldriMacAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MacMainView(model: appDelegate.model)
        } label: {
            Label {
                Text("Skeldri")
            } icon: {
                Image("MenuBarMark")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Owns startup independently from presentation so Bonjour is available before
/// the user opens the menu-bar popover.
@MainActor
final class SkeldriMacAppDelegate: NSObject, NSApplicationDelegate {
    let model = MacAppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { await model.start() }
    }
}

@MainActor
final class MacAppModel: ObservableObject {
    @Published var displays: [DisplayDescriptor] = []
    @Published var selectedDisplayID: UInt32?
    @Published var capturePermission = CGPreflightScreenCaptureAccess()
    @Published var listenerReady = false
    @Published var connected = false
    @Published var annotationsVisible = true
    @Published var inputPermission = CGPreflightPostEventAccess()
    @Published var errorMessage: String?
    let drawingState = DrawingState()
    private let overlay = OverlayWindowController()
    private let server = MacNetworkServer()
    private let afiServer = AfiNetworkServer()
    private let capture = ScreenCaptureManager()
    private let encoder = H264Encoder()
    private let input = MacInputController()
    private var screenPairs: [(SCDisplay, DisplayDescriptor)] = []
    private var videoConnected = false
    private var modernControlConnected = false
    private var afiControlConnected = false
    private var modernVideoConnected = false
    private var afiVideoConnected = false
    private var streamingDisplayID: UInt32?
    private var requestedDisplayID: UInt32?
    private var reconciliationIsRunning = false

    init() {
        server.onConnectionChanged = { [weak self] value in
            Task { @MainActor in
                guard let self else { return }
                self.modernControlConnected = value
                self.afiServer.setAcceptingClients(!value)
                if value { self.afiServer.disconnectClient() }
                self.connected = self.modernControlConnected || self.afiControlConnected
                if value {
                    self.publishDisplays()
                    self.server.sendControl(.canvasSnapshot(self.drawingState.strokes))
                }
            }
        }
        server.onControlPacket = { [weak self] packet in Task { @MainActor in self?.apply(packet) } }
        server.onVideoChannelChanged = { [weak self] connected in
            Task { @MainActor in
                guard let self else { return }
                self.modernVideoConnected = connected
                self.videoConnected = self.modernVideoConnected || self.afiVideoConnected
                self.scheduleReconciliation()
            }
        }
        server.onVideoRecoveryRequested = { [weak encoder] in encoder?.requestKeyframe() }
        server.onInputModeChanged = { [weak input] mode in input?.setActive(mode == .trackpad) }
        server.onTrackpadEvent = { [weak input] event in input?.handle(event) }
        afiServer.onConnectionChanged = { [weak self] value in
            Task { @MainActor in
                guard let self else { return }
                self.afiControlConnected = value
                self.connected = self.modernControlConnected || self.afiControlConnected
                if value {
                    self.publishDisplays()
                    self.afiServer.sendControl(.canvasSnapshot(self.drawingState.strokes))
                }
            }
        }
        afiServer.onControlPacket = { [weak self] packet in Task { @MainActor in self?.apply(packet) } }
        afiServer.onVideoChannelChanged = { [weak self] connected in
            Task { @MainActor in
                guard let self else { return }
                self.afiVideoConnected = connected
                self.videoConnected = self.modernVideoConnected || self.afiVideoConnected
                self.scheduleReconciliation()
            }
        }
        afiServer.onVideoRecoveryRequested = { [weak encoder] in encoder?.requestKeyframe() }
        afiServer.onInputModeChanged = { [weak input] mode in input?.setActive(mode == .trackpad) }
        afiServer.onTrackpadEvent = { [weak input] event in input?.handle(event) }
        input.onPermissionChanged = { [weak self] granted in
            Task { @MainActor in self?.inputPermission = granted }
        }
        capture.consumer = encoder
        encoder.onConfiguration = { [weak server, weak afiServer] configuration in
            server?.sendVideoConfiguration(configuration)
            afiServer?.sendVideoConfiguration(configuration)
        }
        encoder.onFrame = { [weak server, weak afiServer] frame in
            let header = VideoFrameHeader(
                streamID: frame.streamID,
                sequence: frame.sequence,
                presentationTime: frame.presentationTime,
                isKeyframe: frame.isKeyframe
            )
            let modernAccepted = server?.sendVideoFrame(
                frame.data,
                header: header
            ) ?? false
            let afiAccepted = afiServer?.sendVideoFrame(frame.data, header: header) ?? false
            return modernAccepted || afiAccepted
        }
    }

    func start() async {
        // Discovery must remain available even when screen-recording permission or
        // ScreenCaptureKit display enumeration is unavailable.
        do {
            try server.start()
            listenerReady = true
        } catch {
            errorMessage = "Local network listener failed: \(error.localizedDescription)"
            return
        }
        do {
            try afiServer.start()
        } catch {
            // Compatibility is additive. Its failure must never take down the
            // modern listener, display discovery, or normal Skeldri workflow.
            SkeldriLogger.network.error("Afi compatibility unavailable: \(error.localizedDescription)")
        }
        do {
            screenPairs = try await DisplayManager().availableDisplays(); displays = screenPairs.map(\.1)
            selectedDisplayID = displays.first?.id; showOverlayForSelection()
            if connected { publishDisplays() }
        } catch {
            errorMessage = "Display enumeration failed: \(error.localizedDescription)"
        }
    }

    func selectDisplay(_ id: UInt32?) { showOverlayForSelection() }
    func toggleOverlay() { annotationsVisible.toggle(); annotationsVisible ? showOverlayForSelection() : overlay.hide() }
    func clear() {
        drawingState.clear()
        overlay.annotationView.strokes = []
        server.sendControl(.clear)
        afiServer.sendControl(.clear)
    }
    func requestInputPermission() { input.requestPermission() }
    func refreshInputPermission() { inputPermission = input.hasPermission }

    private func startStreaming(displayID: UInt32) async -> Bool {
        guard capturePermission else {
            errorMessage = "Screen Recording permission is required."
            return false
        }
        guard let display = screenPairs.first(where: { $0.1.id == displayID })?.0 else {
            errorMessage = "The selected display is no longer available."
            return false
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let ownBundleID = Bundle.main.bundleIdentifier
            try await capture.start(display: display, excluding: content.applications.filter { $0.bundleIdentifier == ownBundleID })
            return true
        } catch {
            errorMessage = "Capture failed: \(error.localizedDescription)"
            return false
        }
    }

    private func stopStreaming() async { await capture.stop(); encoder.invalidate() }

    private func showOverlayForSelection() {
        guard annotationsVisible, let id = selectedDisplayID,
              let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == id }) else { return }
        overlay.show(on: screen)
    }

    private func publishDisplays() {
        server.sendControl(.displays(displays))
        afiServer.sendControl(.displays(displays))
        if let id = selectedDisplayID, let descriptor = displays.first(where: { $0.id == id }) {
            server.sendControl(.display(descriptor))
            afiServer.sendControl(.display(descriptor))
        }
    }

    /// Coalesces rapid taps and gives capture lifecycle operations one serial owner.
    /// If a newer request arrives while capture is stopping or starting, the loop
    /// immediately converges on the newest requested display.
    private func requestDisplaySelection(id: UInt32) {
        guard displays.contains(where: { $0.id == id }) else {
            publishDisplays()
            return
        }
        guard selectedDisplayID != id else {
            publishDisplays()
            return
        }
        requestedDisplayID = id
        scheduleReconciliation()
    }

    private func scheduleReconciliation() {
        guard !reconciliationIsRunning else { return }
        reconciliationIsRunning = true
        Task { @MainActor [weak self] in await self?.reconcileStreamingState() }
    }

    private func reconcileStreamingState() async {
        while true {
            if requestedDisplayID != nil {
                if streamingDisplayID != nil {
                    await stopStreaming()
                    streamingDisplayID = nil
                    continue
                }

                // Read after the await above so intermediate taps are coalesced.
                guard let target = requestedDisplayID else { continue }
                requestedDisplayID = nil
                selectedDisplayID = target
                showOverlayForSelection()
                publishDisplays()
                continue
            }

            if !videoConnected, streamingDisplayID != nil {
                await stopStreaming()
                streamingDisplayID = nil
                continue
            }

            if videoConnected, streamingDisplayID == nil, let target = selectedDisplayID {
                let started = await startStreaming(displayID: target)
                if started { streamingDisplayID = target }

                // Connection or selection state may have changed while awaiting.
                if !videoConnected || requestedDisplayID != nil || selectedDisplayID != target {
                    if started { await stopStreaming() }
                    streamingDisplayID = nil
                    continue
                }
            }

            reconciliationIsRunning = false
            return
        }
    }

    private func apply(_ packet: ControlPacket) {
        switch packet {
        case let .strokeBegin(id, style, point): drawingState.begin(id: id, style: style, point: point)
        case let .strokePoints(id, points): drawingState.append(id: id, points: points)
        case let .strokeEnd(id): drawingState.finish(id: id)
        case let .deleteStrokes(ids): drawingState.delete(ids: ids)
        case .clear: drawingState.clear()
        case let .canvasSnapshot(strokes): drawingState.replace(with: strokes)
        case let .ping(id, sentAt):
            server.sendControl(.pong(id: id, sentAt: sentAt))
            afiServer.sendControl(.pong(id: id, sentAt: sentAt))
        case let .selectDisplay(id): requestDisplaySelection(id: id)
        default: break
        }
        overlay.annotationView.strokes = drawingState.strokes
    }
}
