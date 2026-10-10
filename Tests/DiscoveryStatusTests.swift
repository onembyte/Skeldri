import Testing

struct DiscoveryStatusTests {
    @Test func startsBySearching() {
        #expect(DiscoveryStatus().presentation == .searching)
    }

    @Test func listsMacsOnceFound() {
        var status = DiscoveryStatus()
        status.browserChanged(to: .ready)
        status.macsChanged(count: 2)
        #expect(status.presentation == .macs)
        status.macsChanged(count: 0)
        #expect(status.presentation == .searching)
    }

    /// Without Local Network access the list can never fill, so the person
    /// must be told how to turn it on rather than watch a spinner forever.
    @Test func localNetworkDenialIsExplained() {
        var status = DiscoveryStatus()
        status.browserChanged(to: .localNetworkDenied)
        #expect(status.presentation == .localNetworkDenied)
        status.helpDelayElapsed()
        #expect(status.presentation == .localNetworkDenied)
    }

    @Test func searchingAddsHelpAfterTheDelay() {
        var status = DiscoveryStatus()
        status.browserChanged(to: .ready)
        status.helpDelayElapsed()
        #expect(status.presentation == .searchingWithHelp)
        status.macsChanged(count: 1)
        #expect(status.presentation == .macs)
    }

    @Test func aFailedBrowserIsReportedUnlessMacsAreListed() {
        var status = DiscoveryStatus()
        status.browserChanged(to: .unavailable)
        #expect(status.presentation == .unavailable)
        status.macsChanged(count: 1)
        #expect(status.presentation == .macs)
    }

    /// Pull to refresh, or coming back from Settings, starts a new search:
    /// earlier denial, failure, and help no longer apply.
    @Test func restartClearsEarlierConditions() {
        var status = DiscoveryStatus()
        status.browserChanged(to: .localNetworkDenied)
        status.helpDelayElapsed()
        status.macsChanged(count: 1)
        status.restart()
        #expect(status.presentation == .searching)
    }
}

struct ApprovalWaitTests {
    @Test func timeoutGivesUpTheWaitingAttemptOnce() {
        var wait = ApprovalWait()
        let attempt = wait.begin()
        #expect(wait.isWaiting)
        let first = wait.timeoutFired(for: attempt)
        let again = wait.timeoutFired(for: attempt)
        #expect(first)
        #expect(!wait.isWaiting)
        #expect(!again)
    }

    @Test func timeoutAfterTheMacDecidedIsIgnored() {
        var wait = ApprovalWait()
        let attempt = wait.begin()
        wait.end()
        let gaveUp = wait.timeoutFired(for: attempt)
        #expect(!gaveUp)
    }

    /// A timer left over from an earlier attempt must not cancel a newer one.
    @Test func staleTimeoutDoesNotCancelANewerAttempt() {
        var wait = ApprovalWait()
        let first = wait.begin()
        wait.end()
        let second = wait.begin()
        let staleGaveUp = wait.timeoutFired(for: first)
        #expect(!staleGaveUp)
        #expect(wait.isWaiting)
        let currentGaveUp = wait.timeoutFired(for: second)
        #expect(currentGaveUp)
    }

    /// The Mac rejects an unanswered request after 60 seconds; the iPad waits
    /// a little longer so the Mac's own decision normally arrives first.
    @Test func iPadOutwaitsTheMacsDecisionTimeout() {
        #expect(ApprovalWait.timeout > ApprovalWait.macDecisionTimeout)
    }
}
