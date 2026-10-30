import Foundation

/// FNV-1a 64-bit.
///
/// Why not `Hasher` / `hashValue`: Swift seeds its hasher randomly **per process**. The widget
/// extension and the app are separate processes, so they would disagree about today's quote — and
/// the pick would change on every launch. Any stable-hash requirement in this app must use this.
public enum StableHash {
    public static let offsetBasis: UInt64 = 0xcbf2_9ce4_8422_2325
    public static let prime: UInt64 = 0x0000_0100_0000_01b3

    public static func fnv1a(_ string: String) -> UInt64 {
        var hash = offsetBasis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }

    /// Convenience for joining components with a separator that cannot appear in an id.
    public static func fnv1a(_ components: [String]) -> UInt64 {
        fnv1a(components.joined(separator: "|"))
    }
}
