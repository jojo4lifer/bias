import WidgetKit
import SwiftUI
import BiasCore

/// One day's worth of widget state.
///
/// Lives in `Shared/` because two things consume it: the widget timeline, and the in-app preview
/// screen used to eyeball the widget without a Mac.
struct QuoteWidgetEntry: TimelineEntry {
    let date: Date
    let quote: Quote?
    let groupName: String
    let theme: ThemeSpec
    let language: AppLanguage

    static let empty = QuoteWidgetEntry(
        date: Date(),
        quote: nil,
        groupName: "",
        theme: ThemeCatalog.default,
        language: .en
    )
}

extension WidgetFamily {
    var kind: WidgetFamilyKind {
        switch self {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        case .systemLarge: return .medium
        case .systemExtraLarge: return .medium
        case .accessoryRectangular: return .accessoryRectangular
        case .accessoryInline: return .accessoryInline
        case .accessoryCircular: return .accessoryInline
        @unknown default: return .medium
        }
    }
}

/// Real widget point sizes on a standard-size iPhone, used by the preview screen so a screenshot
/// of the app is a faithful picture of the widget.
enum WidgetSize {
    static let small = CGSize(width: 158, height: 158)
    static let medium = CGSize(width: 338, height: 158)
    static let accessoryRectangular = CGSize(width: 172, height: 76)
}
