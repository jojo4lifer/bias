import SwiftUI

@main
struct BiasApp: App {
    /// Launch argument used by CI to open the widget preview instead of the Today screen:
    ///   xcrun simctl launch booted com.example.bias -widgetPreview YES
    private let showWidgetPreview = UserDefaults.standard.bool(forKey: "widgetPreview")

    var body: some Scene {
        WindowGroup {
            if showWidgetPreview {
                WidgetPreviewScreen()
            } else {
                TodayView()
            }
        }
    }
}
