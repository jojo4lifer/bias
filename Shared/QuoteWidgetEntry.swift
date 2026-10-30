import SwiftUI
import BiasCore

/// One day's worth of widget state.
///
/// Deliberately **not** a `TimelineEntry`: that conformance lives in the widget target, so this
/// type and the views that render it have no WidgetKit dependency. That is what lets the whole app
/// be type-checked on a machine without iOS SDKs.
struct QuoteWidgetEntry {
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

/// Real widget point sizes on a standard-size iPhone. Used by the preview screen so a screenshot of
/// the app is a faithful picture of the widget.
enum WidgetSize {
    static let small = CGSize(width: 158, height: 158)
    static let medium = CGSize(width: 338, height: 158)
    static let accessoryRectangular = CGSize(width: 172, height: 76)
}
