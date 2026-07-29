import SwiftUI

struct CravingRescueView: View {
    let personalReason: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var remaining = 60
    @State private var expanding = false
    @State private var finished = false

    var body: some View {
        BreatheScreen { metrics in
            VStack(spacing: metrics.sectionSpacing) {
                HStack {
                    BreatheIconButton(icon: "xmark", label: "Close rescue", action: { dismiss() })
                    Spacer()
                    Text("Craving Rescue").font(.headline)
                    Spacer(); Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
                }
                if finished { checkIn(metrics) } else { breathing(metrics) }
            }
        }
        .interactiveDismissDisabled(!finished)
        .task { await runTimer() }
    }

    private func breathing(_ metrics: AppLayoutMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            ZStack {
                Circle().fill(Color.breatheAccentSoft).frame(width: metrics.breathingDiameter, height: metrics.breathingDiameter)
                    .scaleEffect(reduceMotion ? 1 : (expanding ? 1 : 0.68))
                Circle().stroke(Color.breatheAccentMedium, lineWidth: 2)
                    .frame(width: metrics.breathingDiameter * 0.82, height: metrics.breathingDiameter * 0.82)
                VStack(spacing: metrics.compactSpacing) {
                    Text(expanding ? "Breathe in" : "Breathe out").font(AppTypography.sectionTitle(for: metrics.mode))
                    Text("\(remaining)s").font(AppTypography.metric(for: metrics.mode)).monospacedDigit()
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 4), value: expanding)
            Text("This moment will pass. Stay with your breath.")
                .font(AppTypography.body(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let personalReason, !personalReason.isEmpty {
                BreatheBanner(icon: "heart.fill", title: "Remember why you started", message: LocalizedStringKey(personalReason), tint: .breatheYellow)
            }
            BreatheBanner(icon: "figure.walk", title: "Try this now", message: "Stand up, change rooms, and take a sip of water.")
        }
    }

    private func checkIn(_ metrics: AppLayoutMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            Image(systemName: "leaf.circle.fill").font(.system(size: metrics.mode == .compact ? 48 : 58)).foregroundStyle(Color.breatheAccent)
            Text("How are you feeling now?").font(AppTypography.heroTitle(for: metrics.mode)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text("Whatever the answer, taking this pause mattered.").font(AppTypography.body(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
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
