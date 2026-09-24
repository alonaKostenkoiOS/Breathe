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
    @AppStorage(AppLanguage.defaultsKey, store: AppLanguage.sharedDefaults) private var languageCode = AppLanguage.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(\.locale, selectedLanguage.locale)
                .id(languageCode)
                .tint(.breatheAccent)
        }
    }

    private var selectedLanguage: AppLanguage { AppLanguage(rawValue: languageCode) ?? .system }
}

/// Routes between onboarding and the main tabbed experience depending on
/// whether a quit plan exists.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showProgramRescue = false

    var body: some View {
        Group {
            if environment.recoveryStore.primaryProgram == nil {
                ProgramSelectionView()
            } else if let program = environment.recoveryStore.primaryProgram,
                      program.programID.definition.safetyPolicy.requiresScreening,
                      !environment.recoveryStore.state.acknowledgedSafetyWarnings.contains(program.programID) {
                ProgramSafetyGate(program: program)
            } else if environment.recoveryStore.primaryProgram?.programID == .nicotine,
                      !environment.planStore.isOnboardingComplete {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .onOpenURL { url in if url.scheme == "breathe", url.host == "rescue" { showProgramRescue = true } }
        .fullScreenCover(isPresented: $showProgramRescue) {
            if let program = environment.recoveryStore.primaryProgram {
                if program.programID == .nicotine {
                    CravingRescueView(personalReason: environment.planStore.profile?.personalReason, entryPoint: .widget)
                } else { ProgramRescueView(program: program) }
            }
        }
    }
}

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    private var isNicotine: Bool { environment.recoveryStore.primaryProgram?.programID == .nicotine }
    var body: some View {
        TabView {
            Group { if isNicotine { DashboardView() } else { ProgramHomeView() } }
                .tabItem { Label("Home", systemImage: "house.fill") }

            Group { if isNicotine { CravingsView() } else { ProgramUrgesView() } }
                .tabItem { Label(isNicotine ? "Cravings" : "Urges", systemImage: "waveform.path.ecg") }

            Group { if isNicotine { MilestonesView() } else { ProgramProgressView() } }
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
