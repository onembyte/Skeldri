/// What the iPad's list of Macs should tell the person. Pure, so every browser
/// condition is testable without Network.framework.
struct DiscoveryStatus: Equatable, Sendable {
    /// The Bonjour browser's condition, as reported by the network adapter.
    enum Browser: Equatable, Sendable {
        case starting
        case ready
        /// Local Network access is off for Skeldri; nothing can ever be found.
        case localNetworkDenied
        /// The browser failed and needs a new search.
        case unavailable
    }

    enum Presentation: Equatable, Sendable {
        case macs
        case searching
        /// Still nothing after `helpDelaySeconds`: add troubleshooting steps.
        case searchingWithHelp
        case localNetworkDenied
        case unavailable
    }

    /// How long to search before suggesting what might be wrong.
    static let helpDelaySeconds = 10

    private(set) var browser: Browser = .starting
    private(set) var macCount = 0
    private(set) var hasSearchedLong = false

    var presentation: Presentation {
        if browser == .localNetworkDenied { return .localNetworkDenied }
        if macCount > 0 { return .macs }
        if browser == .unavailable { return .unavailable }
        return hasSearchedLong ? .searchingWithHelp : .searching
    }

    mutating func browserChanged(to browser: Browser) { self.browser = browser }
    mutating func macsChanged(count: Int) { macCount = count }
    mutating func helpDelayElapsed() { hasSearchedLong = true }

    /// A new search (pull to refresh, or back from Settings) starts clean.
    mutating func restart() { self = DiscoveryStatus() }
}
