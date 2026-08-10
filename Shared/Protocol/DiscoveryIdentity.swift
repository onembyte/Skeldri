import Foundation

/// Produces a deterministic discovery identity without coupling the rule to
/// Network.framework, allowing duplicate handling to be tested independently.
enum DiscoveryIdentity {
    static func key(stableID: String?, serviceName: String) -> String {
        if let stableID, !stableID.isEmpty { return "id:\(stableID)" }
        return "legacy:\(canonicalLegacyName(serviceName).lowercased())"
    }

    /// Bonjour appends numeric suffixes when two local processes advertise the
    /// same name. Legacy peers lack a stable TXT identifier, so collapse only
    /// that well-known auto-rename shape as a compatibility fallback.
    static func canonicalLegacyName(_ name: String) -> String {
        name.replacingOccurrences(
            of: #" \([0-9]+\)$"#,
            with: "",
            options: .regularExpression
        )
    }
}
