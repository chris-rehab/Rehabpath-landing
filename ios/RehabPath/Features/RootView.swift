import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.data.isOnboarded {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .animation(.default, value: model.data.isOnboarded)
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "checklist") }
            JourneyView()
                .tabItem { Label("Progress", systemImage: "chart.bar") }
            CareTeamView()
                .tabItem { Label("Care team", systemImage: "person.2") }
            PrivacyView()
                .tabItem { Label("Privacy", systemImage: "lock.shield") }
        }
    }
}
