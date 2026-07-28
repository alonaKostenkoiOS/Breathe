import SwiftUI
import BreatheCore

@main
struct BreatheApp: App {
    // A seeded, fully in-memory environment is used when the app is launched
    // by the screenshot UI test, so captures are deterministic and never
    // touch real storage.
    @State private var environment = ProcessInfo.processInfo.arguments.contains("-uiTestSeed")
        ? AppEnvironment.preview()
        : AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .tint(.breatheAccent)
        }
    }
}

/// Routes between onboarding and the main tabbed experience depending on
/// whether a quit plan exists.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        if environment.planStore.isOnboardingComplete {
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
                .tabItem { Label("Home", systemImage: "house.fill") }

            CravingsView()
                .tabItem { Label("Cravings", systemImage: "waveform.path.ecg") }

            MilestonesView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppEnvironment.preview())
}
