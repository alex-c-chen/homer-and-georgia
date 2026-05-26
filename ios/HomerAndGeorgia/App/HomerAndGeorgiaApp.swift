import SwiftUI
import UIKit

@main
struct HomerAndGeorgiaApp: App {
    init() {
        // Large nav titles use the system sans-serif (default); we only keep the
        // transparent background so content scrolls cleanly under the bar.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
