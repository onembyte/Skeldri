import SwiftUI

/// Branded entry point for local Mac discovery. Networking remains owned by the
/// app model; this view is deliberately presentation-only.
struct DiscoveryView: View {
    @ObservedObject var model: iPadAppModel
    @State private var showingPrivacy = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            DiscoveryBackground()

            ScrollView {
                VStack(spacing: 28) {
                    header

                    if model.discovery.presentation != .macs {
                        statusCard
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(model.macs) { mac in
                                MacConnectionCard(mac: mac, waiting: model.awaitingMacApproval) { model.connect(mac) }
                            }
                        }
                        .frame(maxWidth: 620)
                    }

                    if model.awaitingMacApproval {
                        approvalBanner
                    }

                    refreshHint

                    Button("Privacy") { showingPrivacy = true }
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.top, 42)
                .padding(.bottom, 30)
            }
            .refreshable { model.refreshDiscovery() }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingPrivacy) { PrivacyNoticeView() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            FlowingRuneMark()
                .frame(width: 116, height: 92)
                .accessibilityHidden(true)

            Text("Skeldri")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .tracking(-0.8)

            Text("Your Mac, shaped by touch.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
        }
    }

    private var approvalBanner: some View {
        HStack(spacing: 14) {
            Label("Approve this connection from the Skeldri menu on your Mac", systemImage: "lock.shield")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Button("Cancel") { model.cancelConnectionRequest() }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.cyan)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .background(.ultraThinMaterial, in: Capsule())
    }

    /// Says why the list is empty and what to do: a Mac app is required, and
    /// without Local Network access nothing can ever appear.
    @ViewBuilder private var statusCard: some View {
        VStack(spacing: 14) {
            switch model.discovery.presentation {
            case .macs:
                EmptyView()
            case .searching, .searchingWithHelp:
                ProgressView()
                    .tint(Color.cyan)
                    .accessibilityHidden(true)
                statusText(title: "Looking for your Mac…",
                           detail: "Open Skeldri on your Mac and keep both devices on the same Wi\u{2011}Fi network.")
                if model.discovery.presentation == .searchingWithHelp {
                    searchHelp
                }
            case .localNetworkDenied:
                statusSymbol("wifi.exclamationmark")
                statusText(title: "Allow Local Network access",
                           detail: "Skeldri finds your Mac over your local network. Turn on Local Network for Skeldri in Settings.")
                statusButton("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            case .unavailable:
                statusSymbol("exclamationmark.triangle")
                statusText(title: "Can't search for Macs right now",
                           detail: "Check that Wi\u{2011}Fi is on, then search again.")
                statusButton("Search Again") { model.refreshDiscovery() }
            }
        }
        .frame(maxWidth: 620, minHeight: 150)
        .padding(24)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.75)
        }
    }

    private var searchHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Still nothing?").font(.system(.subheadline, design: .rounded, weight: .semibold))
            Label("Skeldri for Mac is required. Get it from the Mac App Store.", systemImage: "macbook")
            Label("Use the same Wi\u{2011}Fi network on both. Guest and public networks often hide devices from each other.",
                  systemImage: "wifi")
            Label("Pull down to search again.", systemImage: "arrow.down")
        }
        .font(.system(.footnote, design: .rounded))
        .foregroundStyle(.white.opacity(0.75))
        .frame(maxWidth: 460, alignment: .leading)
        .padding(.top, 4)
    }

    private func statusSymbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(.title2, weight: .medium))
            .foregroundStyle(.cyan)
            .accessibilityHidden(true)
    }

    private func statusText(title: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(.headline, design: .rounded))
            Text(detail)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 460)
        .accessibilityElement(children: .combine)
    }

    private func statusButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .foregroundStyle(.black)
    }

    private var refreshHint: some View {
        Label("Pull to refresh", systemImage: "arrow.down")
            .font(.system(.caption2, design: .monospaced, weight: .medium))
            .textCase(.uppercase)
            .tracking(1.1)
            .foregroundStyle(.white.opacity(0.6))
    }
}

private struct MacConnectionCard: View {
    let mac: DiscoveredMac
    let waiting: Bool
    let connect: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.07))
                Image(systemName: "macbook")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.cyan)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text(mac.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle().fill(.cyan).frame(width: 6, height: 6)
                    Text("Available")
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.52))
            }

            Spacer(minLength: 16)

            Button(action: connect) {
                HStack(spacing: 7) {
                    Text("Connect")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 17)
                .frame(height: 40)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.84, blue: 0.88), Color(red: 0.10, green: 0.36, blue: 1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .shadow(color: .blue.opacity(0.28), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(waiting)
            .opacity(waiting ? 0.45 : 1)
            .accessibilityLabel("Connect to \(mac.name)")
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.75)
        }
    }
}

private struct DiscoveryBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.018, green: 0.035, blue: 0.11), Color(red: 0.025, green: 0.055, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.cyan.opacity(0.11))
                .frame(width: 380, height: 380)
                .blur(radius: 90)
                .offset(x: -260, y: -220)

            Circle()
                .fill(.blue.opacity(0.12))
                .frame(width: 440, height: 440)
                .blur(radius: 110)
                .offset(x: 300, y: 260)
        }
        .ignoresSafeArea()
    }
}

/// Compact vector interpretation of the app icon. Keeping this code-native
/// avoids loading a large app-icon bitmap into the discovery hierarchy.
private struct FlowingRuneMark: View {
    var body: some View {
        Canvas { context, size in
            let gradient = Gradient(colors: [
                Color(red: 0.10, green: 0.92, blue: 0.91),
                Color(red: 0.08, green: 0.36, blue: 1)
            ])

            for index in 0..<3 {
                let inset = CGFloat(index) * 7
                var path = Path()
                path.move(to: CGPoint(x: 13 + inset, y: 8 + inset * 0.35))
                path.addCurve(
                    to: CGPoint(x: size.width * 0.82, y: size.height * 0.50),
                    control1: CGPoint(x: 12 + inset, y: size.height * 0.31),
                    control2: CGPoint(x: size.width * 0.58, y: size.height * 0.29 + inset * 0.2)
                )
                path.addCurve(
                    to: CGPoint(x: 13 + inset, y: size.height - 8 - inset * 0.35),
                    control1: CGPoint(x: size.width * 0.58, y: size.height * 0.71 - inset * 0.2),
                    control2: CGPoint(x: 12 + inset, y: size.height * 0.69)
                )
                context.stroke(
                    path,
                    with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)),
                    style: SwiftUI.StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .shadow(color: .cyan.opacity(0.30), radius: 12)
    }
}
