/// Listing displays through ScreenCaptureKit raises the Screen Recording prompt.
/// Doing it at launch asks for permission before the person has done anything,
/// so the Mac lists displays only once permission exists, and only once.
enum DisplayEnumerationPolicy {
    static func shouldEnumerate(hasCapturePermission: Bool, hasDisplays: Bool, isEnumerating: Bool) -> Bool {
        hasCapturePermission && !hasDisplays && !isEnumerating
    }
}
