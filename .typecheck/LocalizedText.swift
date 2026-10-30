import Foundation

/// The languages the app ships in.
///
/// `zh-Hant` is not in v1 but the model supports it from day one so that adding it later is a
/// content job, not a migration.
public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case en
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    /// Maps an arbitrary locale identifier to a supported language.
    public init(localeIdentifier: String) {
        let lower = localeIdentifier.lowercased()
        guard lower.hasPrefix("zh") else {
            self = .en
            return
        }
        let traditionalMarkers = ["hant", "tw", "hk", "mo", "cht"]
        if traditionalMarkers.contains(where: { lower.contains($0) }) {
            self = .zhHant
        } else {
            self = .zhHans
        }
    }

    /// Languages that must be present on every quote before it can ship.
    public static let launchLanguages: [AppLanguage] = [.en, .zhHans]

    public var displayName: String {
        switch self {
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        }
    }
}

/// A string that exists in more than one language.
public struct LocalizedText: Codable, Hashable, Sendable {
    public let en: String
    public let zhHans: String?
    public let zhHant: String?

    public init(en: String, zhHans: String? = nil, zhHant: String? = nil) {
        self.en = en
        self.zhHans = zhHans
        self.zhHant = zhHant
    }

    /// Resolves with a sensible fallback chain: requested → Simplified Chinese → English.
    public func resolve(_ language: AppLanguage) -> String {
        switch language {
        case .en:
            return en
        case .zhHans:
            return nonEmpty(zhHans) ?? en
        case .zhHant:
            return nonEmpty(zhHant) ?? nonEmpty(zhHans) ?? en
        }
    }

    /// True when every launch language has real content.
    public var isCompleteForLaunch: Bool {
        !en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !(nonEmpty(zhHans) ?? "").isEmpty
    }

    /// Languages with missing content, for the linter.
    public var missingLaunchLanguages: [AppLanguage] {
        var missing: [AppLanguage] = []
        if en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append(.en) }
        if nonEmpty(zhHans) == nil { missing.append(.zhHans) }
        return missing
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}
