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
    @State private var isShowingLaunch = !ProcessInfo.processInfo.arguments.contains("-uiTestSeed")
    @State private var isFinishingLaunch = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(environment)
                    .environment(\.locale, selectedLanguage.locale)
                    .id(languageCode)
                    .tint(.breatheAccent)

                if isShowingLaunch {
                    BreatheLaunchView(isFinishing: isFinishingLaunch)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .task {
                guard isShowingLaunch else { return }
                try? await Task.sleep(for: .seconds(1.65))
                withAnimation(.easeInOut(duration: 0.8)) {
                    isFinishingLaunch = true
                }
                try? await Task.sleep(for: .seconds(0.8))
                withAnimation(.easeOut(duration: 0.18)) { isShowingLaunch = false }
            }
        }
    }

    private var selectedLanguage: AppLanguage { AppLanguage(rawValue: languageCode) ?? .system }
}

/// A quiet brand moment shown while the local app state is being restored.
/// The SF Symbol stays crisp at every size and avoids text-bearing artwork.
private struct BreatheLaunchView: View {
    let isFinishing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isInhaling = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.breatheSky, Color.breatheBackground, Color.breatheBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .opacity(isFinishing ? 0 : 1)

            VStack(spacing: 30) {
                FreedomBreathingMark(isExpanded: isInhaling)
                    .frame(width: 210, height: 150)
                    .accessibilityHidden(true)

                Text(verbatim: "Breathe")
                    .font(.system(size: 48, weight: .bold, design: .serif))
                    .foregroundStyle(Color.breatheText)
                    .accessibilityAddTraits(.isHeader)
            }
            .scaleEffect(isFinishing && !reduceMotion ? 1.08 : 1)
            .blur(radius: isFinishing && !reduceMotion ? 14 : 0)
            .opacity(isFinishing ? 0 : 1)
        }
        .animation(.easeInOut(duration: reduceMotion ? 0.15 : 0.8), value: isFinishing)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                isInhaling = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "Breathe"))
    }
}

/// Two soft lung forms that open like wings: breath becoming freedom.
private struct FreedomBreathingMark: View {
    let isExpanded: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.breatheAccentMedium.opacity(0.20))
                .frame(width: isExpanded ? 205 : 150, height: isExpanded ? 116 : 92)
                .blur(radius: 22)

            HStack(spacing: isExpanded ? 18 : 7) {
                FreedomLungShape()
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.9), Color.breatheAccentMedium, Color.breatheAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .scaleEffect(x: -1, y: 1)

                FreedomLungShape()
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.9), Color.breatheAccentMedium, Color.breatheAccent],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    ))
            }
            .frame(width: 176, height: 128)
            .scaleEffect(x: isExpanded ? 1.08 : 0.92, y: isExpanded ? 1.04 : 0.94)
            .shadow(color: Color.breatheAccent.opacity(0.18), radius: 18, y: 8)

            VStack(spacing: -2) {
                Capsule()
                    .fill(Color.breatheAccent)
                    .frame(width: 5, height: 42)
                HStack(spacing: 15) {
                    Capsule().fill(Color.breatheAccent).frame(width: 30, height: 4).rotationEffect(.degrees(28))
                    Capsule().fill(Color.breatheAccent).frame(width: 30, height: 4).rotationEffect(.degrees(-28))
                }
            }
            .offset(y: -23)
        }
    }
}

private struct FreedomLungShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.62, y: rect.height * 0.06))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.72),
            control1: CGPoint(x: rect.width * 0.37, y: rect.height * 0.14),
            control2: CGPoint(x: rect.width * 0.08, y: rect.height * 0.39)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.77, y: rect.height * 0.94),
            control1: CGPoint(x: rect.width * 0.06, y: rect.height * 1.02),
            control2: CGPoint(x: rect.width * 0.52, y: rect.height * 1.03)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.62, y: rect.height * 0.06),
            control1: CGPoint(x: rect.width * 0.92, y: rect.height * 0.68),
            control2: CGPoint(x: rect.width * 0.80, y: rect.height * 0.24)
        )
        path.closeSubpath()
        return path
    }
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
