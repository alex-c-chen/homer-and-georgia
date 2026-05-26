import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "calendar") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }

            UsageView()
                .tabItem { Label("Usage", systemImage: "chart.bar.fill") }
        }
        .tint(Theme.generalTint)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
