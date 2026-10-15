import Testing

struct PermissionPromptingTests {
    @Test func grantedPermissionNeedsNoAction() {
        #expect(PermissionPrompting.action(isGranted: true, hasRequestedBefore: false) == .none)
        #expect(PermissionPrompting.action(isGranted: true, hasRequestedBefore: true) == .none)
    }

    @Test func firstRequestUsesTheSystemPrompt() {
        #expect(PermissionPrompting.action(isGranted: false, hasRequestedBefore: false) == .request)
    }

    /// macOS shows its Screen Recording and pointer-control prompts only once;
    /// a second request fails silently, so the person must use System Settings.
    @Test func laterRequestsGoToSystemSettings() {
        #expect(PermissionPrompting.action(isGranted: false, hasRequestedBefore: true) == .openSettings)
    }
}

struct SetupGuidePresentationTests {
    @Test func presentsOnFirstLaunch() {
        #expect(SetupGuidePresentation.presentsAtLaunch(completedRevision: nil))
    }

    @Test func staysClosedOnceTheCurrentGuideWasCompleted() {
        #expect(!SetupGuidePresentation.presentsAtLaunch(completedRevision: SetupGuidePresentation.currentRevision))
    }

    @Test func presentsAgainWhenTheGuideGainsARevision() {
        #expect(SetupGuidePresentation.presentsAtLaunch(completedRevision: SetupGuidePresentation.currentRevision - 1))
    }
}

struct DisplayEnumerationPolicyTests {
    /// Enumerating displays through ScreenCaptureKit raises the Screen Recording
    /// prompt, so launching without permission must not enumerate.
    @Test func waitsForScreenRecordingPermission() {
        #expect(!DisplayEnumerationPolicy.shouldEnumerate(
            hasCapturePermission: false, hasDisplays: false, isEnumerating: false
        ))
    }

    @Test func enumeratesOnceAfterPermissionIsGranted() {
        #expect(DisplayEnumerationPolicy.shouldEnumerate(
            hasCapturePermission: true, hasDisplays: false, isEnumerating: false
        ))
        #expect(!DisplayEnumerationPolicy.shouldEnumerate(
            hasCapturePermission: true, hasDisplays: false, isEnumerating: true
        ))
        #expect(!DisplayEnumerationPolicy.shouldEnumerate(
            hasCapturePermission: true, hasDisplays: true, isEnumerating: false
        ))
    }
}
