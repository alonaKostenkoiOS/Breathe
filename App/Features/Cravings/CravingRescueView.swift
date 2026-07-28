import SwiftUI

struct CravingRescueView: View {
    let personalReason: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var remaining = 60
    @State private var expanding = false
    @State private var finished = false

    var body: some View {
        BreatheScreen(scrollable: false) {
            VStack(spacing: BreatheSpacing.xl) {
                HStack {
                    BreatheIconButton(icon: "xmark", label: "Close rescue", action: { dismiss() })
                    Spacer()
                    Text("Craving Rescue").font(.headline)
                    Spacer(); Color.clear.frame(width: 44, height: 44)
                }
                Spacer()
                if finished { checkIn } else { breathing }
                Spacer()
            }
        }
        .interactiveDismissDisabled(!finished)
        .task { await runTimer() }
    }

    private var breathing: some View {
        VStack(spacing: BreatheSpacing.xl) {
            ZStack {
                Circle().fill(Color.breatheAccentSoft).frame(width: 220, height: 220)
                    .scaleEffect(reduceMotion ? 1 : (expanding ? 1 : 0.68))
                Circle().stroke(Color.breatheAccentMedium, lineWidth: 2).frame(width: 180, height: 180)
                VStack(spacing: BreatheSpacing.xs) {
                    Text(expanding ? "Breathe in" : "Breathe out").font(.breatheSectionTitle)
                    Text("\(remaining)s").font(.breatheMetric).monospacedDigit()
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 4), value: expanding)
            Text("This moment will pass. Stay with your breath.")
                .font(.breatheBody).foregroundStyle(Color.breatheTextSecondary).multilineTextAlignment(.center)
            if let personalReason, !personalReason.isEmpty {
                BreatheBanner(icon: "heart.fill", title: "Remember why you started", message: LocalizedStringKey(personalReason), tint: .breatheYellow)
            }
            BreatheBanner(icon: "figure.walk", title: "Try this now", message: "Stand up, change rooms, and take a sip of water.")
        }
    }

    private var checkIn: some View {
        VStack(spacing: BreatheSpacing.lg) {
            Image(systemName: "leaf.circle.fill").font(.system(size: 64)).foregroundStyle(Color.breatheAccent)
            Text("How are you feeling now?").font(.breatheLargeTitle).multilineTextAlignment(.center)
            Text("Whatever the answer, taking this pause mattered.").foregroundStyle(Color.breatheTextSecondary).multilineTextAlignment(.center)
            BreathePrimaryButton(title: "The craving passed") { BreatheFeedback.success(); dismiss() }
            BreatheSecondaryButton(title: "I need another minute") { remaining = 60; finished = false }
            Button("Close for now") { dismiss() }.frame(minHeight: 44).foregroundStyle(Color.breatheTextSecondary)
        }
    }

    private func runTimer() async {
        while !Task.isCancelled && remaining > 0 {
            expanding.toggle()
            try? await Task.sleep(for: .seconds(4))
            remaining = max(0, remaining - 4)
        }
        if remaining == 0 { withAnimation { finished = true }; BreatheFeedback.success() }
    }
}
