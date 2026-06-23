import SwiftUI
import BreatheCore

@main
struct BreatheApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
    }
}

/// Routes between onboarding and the main tabbed experience depending on
/// whether a quit plan exists.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        if environment.planStore.hasPlan {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Today", systemImage: "lungs.fill") }

            MilestonesView()
                .tabItem { Label("Recovery", systemImage: "heart.fill") }

            CravingsView()
                .tabItem { Label("Cravings", systemImage: "bolt.heart") }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppEnvironment.preview())
}
