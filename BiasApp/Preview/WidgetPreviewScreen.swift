import SwiftUI
import BiasCore

/// Renders the real widget views at their true point sizes.
///
/// Purpose: this machine cannot run a simulator, so CI boots one and takes a screenshot. Showing
/// the widget *inside the app* is the only way to photograph it without hand-placing a widget on a
/// simulated Home Screen. The views are shared with the widget extension, so what you see here is
/// what a fan sees.
///
/// Activated by launching with `-widgetPreview YES`; it is not reachable from the UI.
struct WidgetPreviewScreen: View {
    private let repository = QuoteRepository.shared
    private let language: AppLanguage = .en

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Widget preview")
                        .font(.title2.weight(.semibold))
                    Text("Rendered at real size from the same views the extension uses.")
                        .font(.footnote)
                        .opacity(0.7)
                }
                .foregroundStyle(.white)

                section("Medium · Home Screen") {
                    widgetPreview(.medium, size: WidgetSize.medium, cornerRadius: 22)
                }

                section("Small · Home Screen") {
                    widgetPreview(.small, size: WidgetSize.small, cornerRadius: 22)
                }

                section("Rectangular · Lock Screen") {
                    widgetPreview(.accessoryRectangular, size: WidgetSize.accessoryRectangular, cornerRadius: 14)
                        .padding(10)
                        .background(Color(white: 0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                section("Inline · Lock Screen") {
                    QuoteWidgetContent(entry: entry, family: .accessoryInline)
                        .frame(width: WidgetSize.accessoryRectangular.width, height: 22, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text("Unofficial fan project · not affiliated with any artist or agency")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(white: 0.09).ignoresSafeArea())
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
            content()
        }
    }

    private func widgetPreview(
        _ family: WidgetFamilyKind,
        size: CGSize,
        cornerRadius: CGFloat
    ) -> some View {
        QuoteWidgetContent(entry: entry, family: family)
            .frame(width: size.width, height: size.height)
            .background(entry.theme.gradient)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var entry: QuoteWidgetEntry {
        let groupId = repository.firstGroupId
        let quote = groupId.flatMap { repository.store.quote(for: $0, date: Date()) }
        let groupName = groupId.flatMap {
            repository.store.group(for: $0)?.name.resolve(language)
        } ?? ""
        return QuoteWidgetEntry(
            date: Date(),
            quote: quote,
            groupName: groupName,
            theme: ThemeCatalog.default,
            language: language
        )
    }
}
