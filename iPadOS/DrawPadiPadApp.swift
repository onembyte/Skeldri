import SwiftUI
import UIKit

@main
struct DrawPadiPadApp: App {
    @StateObject private var model = iPadAppModel()
    var body: some Scene { WindowGroup { Group { if model.connected { DrawingScreen(model: model) } else { DiscoveryView(model: model) } }.task { model.start() }.alert("DrawPad", isPresented: $model.showingError) { Button("OK") {} } message: { Text(model.errorMessage ?? "Unknown error") } } }
}

@MainActor
final class iPadAppModel: ObservableObject {
    @Published var macs: [DiscoveredMac] = []
    @Published var connected = false { didSet { UIApplication.shared.isIdleTimerDisabled = connected } }
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var style = StrokeStyle.defaultPen
    @Published var mode: DrawingInteractionMode = .draw
    @Published var color = Color.red
    @Published var width = 0.005
    @Published var confirmingClear = false
    @Published var videoAspectRatio: CGFloat = 16 / 10
    let drawingState = DrawingState()
    let decoder = H264Decoder()
    private let network = iPadNetworkClient()

    init() {
        network.onServicesChanged = { [weak self] values in Task { @MainActor in self?.macs = values } }
        network.onStateChanged = { [weak self] value, error in Task { @MainActor in self?.connected = value; if let error { self?.errorMessage = error; self?.showingError = true } } }
        network.onControlPacket = { [weak self] packet in Task { @MainActor in self?.apply(packet) } }
        network.onVideoPacket = { [weak self] packet in
            guard let self else { return }
            if packet.type == .videoConfiguration, let configuration = try? JSONDecoder().decode(VideoConfiguration.self, from: packet.payload) { decoder.configure(configuration) }
            if packet.type == .videoFrame { decoder.decode(payload: packet.payload) }
        }
    }
    func start() { network.startBrowsing() }
    func connect(_ mac: DiscoveredMac) { network.connect(to: mac.endpoint) }
    func choosePen() { mode = .draw; style = StrokeStyle(tool: .pen, red: style.red, green: style.green, blue: style.blue, alpha: 1, normalizedWidth: Float(width)) }
    func chooseHighlighter() { mode = .draw; style = StrokeStyle(tool: .highlighter, red: style.red, green: style.green, blue: style.blue, alpha: 0.3, normalizedWidth: Float(max(width, 0.015))) }
    func updateColor(_ color: Color) { let resolved = UIColor(color); var r: CGFloat=0,g: CGFloat=0,b: CGFloat=0,a: CGFloat=0; resolved.getRed(&r, green:&g, blue:&b, alpha:&a); style = StrokeStyle(tool: style.tool, red: Float(r), green: Float(g), blue: Float(b), alpha: style.alpha, normalizedWidth: style.normalizedWidth) }
    func updateWidth(_ width: Double) { style = StrokeStyle(tool: style.tool, red: style.red, green: style.green, blue: style.blue, alpha: style.alpha, normalizedWidth: Float(width)) }
    func handleLocal(_ packet: ControlPacket) { apply(packet); network.send(packet) }
    func undo() { if let id = drawingState.undo() { network.send(.deleteStrokes(ids: [id])) } }
    func clear() { drawingState.clear(); network.send(.clear) }
    private func apply(_ packet: ControlPacket) {
        switch packet {
        case let .strokeBegin(id, style, point): drawingState.begin(id:id, style:style, point:point)
        case let .strokePoints(id, points): drawingState.append(id:id, points:points)
        case let .strokeEnd(id): drawingState.finish(id:id)
        case let .deleteStrokes(ids): drawingState.delete(ids:ids)
        case .clear: drawingState.clear()
        case let .canvasSnapshot(value): drawingState.replace(with:value)
        case let .display(display): videoAspectRatio = CGFloat(display.aspectRatio)
        case let .incompatibleVersion(expected): errorMessage = "Incompatible protocol version. Mac expects \(expected)."; showingError = true
        default: break
        }
    }
}
