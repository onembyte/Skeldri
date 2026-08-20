import Foundation
import Testing

struct LectureSourceCatalogTests {
    private func candidate(
        id: UInt32,
        title: String? = "Document",
        application: String? = "Preview",
        bundle: String? = "com.apple.Preview",
        width: Int = 900,
        height: Int = 1200,
        isOnScreen: Bool = true,
        layer: Int = 0
    ) -> LectureWindowCandidate {
        LectureWindowCandidate(
            id: id, title: title, applicationName: application, bundleIdentifier: bundle,
            width: width, height: height, isOnScreen: isOnScreen, layer: layer
        )
    }

    @Test func excludesSkeldriOwnWindowsToPreventRecursiveCapture() {
        let candidates = [
            candidate(id: 1, title: "Manual"),
            candidate(id: 2, title: "Annotations", application: "Skeldri", bundle: "com.onembyte.skeldri.mac"),
            candidate(id: 3, title: "Skeldri", application: "Skeldri", bundle: "com.onembyte.skeldri.mac")
        ]

        let sources = LectureSourceCatalog.windowSources(
            from: candidates, excludingBundleIdentifier: "com.onembyte.skeldri.mac"
        )

        #expect(sources.map(\.id) == [1])
    }

    @Test func dropsWindowsThatCannotPresentAReadablePage() {
        let candidates = [
            candidate(id: 1, title: "Readable"),
            candidate(id: 2, title: "Offscreen", isOnScreen: false),
            candidate(id: 3, title: "Menu bar item", layer: 25),
            candidate(id: 4, title: "Sliver", width: LectureSourceCatalog.minimumWindowDimension - 1),
            candidate(id: 5, title: "Short", height: LectureSourceCatalog.minimumWindowDimension - 1)
        ]

        let sources = LectureSourceCatalog.windowSources(from: candidates, excludingBundleIdentifier: nil)

        #expect(sources.map(\.id) == [1])
        #expect(sources.allSatisfy { $0.kind == .window })
    }

    @Test func namesStayWithinTheDescriptorTransportBounds() throws {
        let candidates = [
            candidate(id: 1, title: String(repeating: "a", count: 400), application: "Editor"),
            candidate(id: 2, title: "   ", application: "   ")
        ]

        let sources = LectureSourceCatalog.windowSources(from: candidates, excludingBundleIdentifier: nil)
        let byID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })

        let long = try #require(byID[1])
        #expect(long.name.utf8.count <= 256)
        // A descriptor the peer would reject on decode is not worth offering.
        let encoded = try JSONEncoder().encode(long)
        #expect(try JSONDecoder().decode(LectureSourceDescriptor.self, from: encoded) == long)

        let unnamed = try #require(byID[2])
        #expect(unnamed.name == "Window 2")
    }

    @Test func combinesApplicationAndTitleAndOrdersStably() {
        let candidates = [
            candidate(id: 9, title: "Zebra", application: "Preview"),
            candidate(id: 4, title: "Alpha", application: "Preview"),
            candidate(id: 7, title: nil, application: "Numbers")
        ]

        let sources = LectureSourceCatalog.windowSources(from: candidates, excludingBundleIdentifier: nil)

        #expect(sources.map(\.name) == ["Numbers", "Preview — Alpha", "Preview — Zebra"])
    }

    @Test func displaySourcesCarryTheDisplayKindAndSafeBounds() {
        let source = LectureSourceCatalog.displaySource(
            from: DisplayDescriptor(id: 7, name: "Studio Display", width: 2560, height: 1440)
        )

        #expect(source == LectureSourceDescriptor(
            id: 7, kind: .display, name: "Studio Display", width: 2560, height: 1440
        ))
    }

    @Test func windowAndDisplayIdentifiersAreOnlyUniqueTogetherWithTheirKind() {
        // CGWindowID and CGDirectDisplayID are both UInt32 and share no namespace,
        // so a lookup keyed on id alone can resolve to the wrong capture source.
        let window = LectureSourceCatalog.windowSources(
            from: [candidate(id: 7, title: "Manual")], excludingBundleIdentifier: nil
        ).first
        let display = LectureSourceCatalog.displaySource(
            from: DisplayDescriptor(id: 7, name: "Studio Display", width: 2560, height: 1440)
        )

        #expect(window?.id == display.id)
        #expect(window != display)
        #expect(window?.kind != display.kind)
        // Anything keying a collection on a source — a picker list, a lookup —
        // must use the qualified identity or these two collapse into one.
        #expect(window?.qualifiedIdentity != display.qualifiedIdentity)
        #expect(display.qualifiedIdentity == "display:7")
        #expect(window?.qualifiedIdentity == "window:7")
    }
}
