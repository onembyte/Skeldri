import SwiftUI

struct DrawingCanvasRepresentable: UIViewRepresentable {
    @ObservedObject var model: iPadAppModel
    @ObservedObject var drawingState: DrawingState

    func makeUIView(context: Context) -> TouchDrawingUIView { let view = TouchDrawingUIView(); view.onPacket = { model.handleLocal($0) }; return view }
    func updateUIView(_ view: TouchDrawingUIView, context: Context) { view.strokes = drawingState.strokes; view.style = model.style; view.mode = model.mode; view.videoAspectRatio = model.videoAspectRatio }
}

struct TrackpadRepresentable: UIViewRepresentable {
    @ObservedObject var model: iPadAppModel

    func makeUIView(context: Context) -> TrackpadUIView {
        let view = TrackpadUIView()
        view.onMove = { [weak model] in model?.sendTrackpadMove(deltaX: $0, deltaY: $1) }
        view.onScroll = { [weak model] in model?.sendTrackpadScroll(deltaX: $0, deltaY: $1) }
        view.onButton = { [weak model] in model?.sendTrackpadButton($0, isDown: $1, clickCount: $2) }
        return view
    }

    func updateUIView(_ uiView: TrackpadUIView, context: Context) {
        uiView.motionSettings = model.trackpadMotionSettings
    }
}

/// Collapsible trackpad tuning controls. The compact button keeps the pointing
/// surface unobstructed until the user explicitly asks for configuration.
private struct TrackpadSettingsPanel: View {
    @ObservedObject var model: iPadAppModel
    @State private var expanded = false

    var body: some View {
        HStack(spacing: 8) {
            GlassIconButton(
                accessibilityLabel: expanded ? "Hide trackpad settings" : "Show trackpad settings",
                selected: expanded,
                action: { withAnimation(.snappy(duration: 0.24)) { expanded.toggle() } }
            ) {
                Image(systemName: "slider.horizontal.3")
            }

            if expanded {
                VStack(spacing: 12) {
                    settingSlider(
                        symbol: "scope",
                        accessibilityLabel: "Trackpad sensitivity",
                        value: $model.trackpadSensitivity,
                        range: 0.5...2.0
                    )
                    settingSlider(
                        symbol: "speedometer",
                        accessibilityLabel: "Trackpad speed",
                        value: $model.trackpadSpeed,
                        range: 0.5...2.5
                    )
                    Button {
                        model.trackpadAccelerationEnabled.toggle()
                    } label: {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(model.trackpadAccelerationEnabled ? Color.accentColor : Color.primary)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.055), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pointer acceleration")
                    .accessibilityValue(model.trackpadAccelerationEnabled ? "On" : "Off")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .liquidGlassPanel(in: Capsule())
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }

    private func settingSlider(
        symbol: String,
        accessibilityLabel: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
            Slider(value: value, in: range)
                .frame(width: 112)
                .accessibilityLabel(accessibilityLabel)
        }
    }
}

struct DrawingScreen: View {
    @ObservedObject var model: iPadAppModel
    var body: some View {
        ZStack {
            if model.inputMode == .drawing {
                Color.black.ignoresSafeArea()
                VideoDisplayView(decoder: model.decoder).ignoresSafeArea()
                DrawingCanvasRepresentable(model: model, drawingState: model.drawingState).ignoresSafeArea()
                DisplaySidebar(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.leading, 14)
                DrawingToolbar(model: model)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 14)
            } else {
                Color(uiColor: .systemGray4).ignoresSafeArea()
                TrackpadRepresentable(model: model).ignoresSafeArea()
                TrackpadSettingsPanel(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.leading, 14)
            }

            GlassIconButton(accessibilityLabel: "Back to Mac selection", action: model.disconnect) {
                Image(systemName: "chevron.left")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 14)
            .padding(.top, 14)

            GlassIconButton(
                accessibilityLabel: model.inputMode == .drawing ? "Switch to trackpad" : "Switch to drawing",
                selected: model.inputMode == .trackpad,
                action: model.toggleInputMode
            ) {
                Image(systemName: model.inputMode == .drawing ? "hand.point.up.left" : "pencil.tip")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 14)
            .padding(.top, 14)
        }
        .ignoresSafeArea(edges: .vertical)
    }
}
