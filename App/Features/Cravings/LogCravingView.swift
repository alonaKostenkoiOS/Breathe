import SwiftUI
import BreatheCore

struct LogCravingView: View {
    enum Outcome: String, CaseIterable { case resisted, smoked, ongoing }
    let onSave: (Int, Craving.Trigger, Bool, String?) async -> Void
    var onRescue: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var intensity = 3
    @State private var trigger: Craving.Trigger = .stress
    @State private var outcome: Outcome = .resisted
    @State private var note = ""
    @State private var saving = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            BreatheScreen { metrics in
                if saved { confirmation(metrics) } else { form(metrics) }
            }
            .navigationTitle("Log a craving")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BreatheIconButton(icon: "xmark", label: "Close", action: { dismiss() })
                }
            }
        }.presentationDragIndicator(.visible)
    }

    private func form(_ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            BreatheSectionHeader(title: "How strong is it?", detail: "Choose the closest match.")
            intensityChoices(metrics)
            BreatheSectionHeader(title: "What brought it on?")
            BreatheFlowLayout(spacing: metrics.compactSpacing) {
                ForEach(Craving.Trigger.allCases, id: \.self) { value in
                    BreatheChip(title: LocalizedStringKey(value.label), icon: value.symbol,
                                selected: trigger == value) { trigger = value; BreatheFeedback.selection() }
                }
            }
            BreatheSectionHeader(title: "What happened?")
            VStack(spacing: metrics.compactSpacing) {
                outcomeCard(.resisted, "I resisted", "shield.checkered")
                outcomeCard(.smoked, "I smoked", "arrow.counterclockwise")
                outcomeCard(.ongoing, "Still dealing with it", "wind")
            }
            VStack(alignment: .leading, spacing: metrics.compactSpacing) {
                Text("Note (optional)").font(.headline)
                TextField("Anything you want to remember?", text: $note, axis: .vertical)
                    .lineLimit(2...4).padding(metrics.internalSpacing)
                    .background(Color.breatheSurface, in: RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous).stroke(Color.breatheDivider))
            }
            BreathePrimaryButton(title: outcome == .ongoing ? "Open Craving Rescue" : "Save craving",
                                 icon: outcome == .ongoing ? "wind" : "checkmark", disabled: saving) { save() }
        }.padding(.bottom, metrics.majorSpacing)
    }

    @ViewBuilder private func intensityChoices(_ metrics: AppLayoutMetrics) -> some View {
        if metrics.accessibilityText {
            VStack(spacing: metrics.compactSpacing) {
                ForEach(1...5, id: \.self) { value in
                    BreatheSelectionCard(title: LocalizedStringKey("\(value) — \(intensityLabel(value))"), selected: intensity == value) {
                        intensity = value; BreatheFeedback.selection()
                    }
                }
            }
        } else {
            HStack(spacing: metrics.compactSpacing) {
                ForEach(1...5, id: \.self) { value in intensityChoice(value, metrics) }
            }
        }
    }

    private func intensityChoice(_ value: Int, _ metrics: AppLayoutMetrics) -> some View {
        Button { intensity = value; BreatheFeedback.selection() } label: {
            VStack(spacing: 4) {
                Text("\(value)").font(.headline)
                Text(LocalizedStringKey(intensityLabel(value))).font(AppTypography.caption(for: metrics.mode)).lineLimit(2).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, minHeight: metrics.buttonHeight)
        }.buttonStyle(.plain)
            .background(intensity == value ? Color.breatheAccentSoft : .breatheSurface, in: RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous).stroke(intensity == value ? Color.breatheAccent : .breatheDivider, lineWidth: intensity == value ? 2 : 1))
            .accessibilityLabel("Intensity \(value)").accessibilityValue(Text(LocalizedStringKey(intensityLabel(value))))
            .accessibilityAddTraits(intensity == value ? .isSelected : [])
    }

    private func confirmation(_ metrics: AppLayoutMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            Image(systemName: outcome == .resisted ? "checkmark.circle.fill" : "heart.circle.fill")
                .font(.system(size: metrics.mode == .compact ? 48 : 58)).foregroundStyle(Color.breatheAccent)
            Text(outcome == .resisted ? "You made it through." : "Your progress still matters.")
                .font(AppTypography.heroTitle(for: metrics.mode)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text("Logging this moment helps Breathe understand what support works for you.")
                .font(AppTypography.body(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            BreathePrimaryButton(title: "Done") { dismiss() }
            if outcome != .resisted, let onRescue {
                BreatheSecondaryButton(title: "Try Craving Rescue", icon: "wind") { dismiss(); onRescue() }
            }
        }
    }

    private func outcomeCard(_ value: Outcome, _ title: LocalizedStringKey, _ icon: String) -> some View {
        BreatheSelectionCard(title: title, icon: icon, selected: outcome == value) { outcome = value; BreatheFeedback.selection() }
    }

    private func save() {
        if outcome == .ongoing { dismiss(); onRescue?(); return }
        saving = true
        Task {
            await onSave(intensity, trigger, outcome == .resisted, note)
            BreatheFeedback.success()
            withAnimation(.easeInOut) { saving = false; saved = true }
        }
    }
}

private func intensityLabel(_ value: Int) -> String {
    switch value { case 1: "Mild"; case 2: "Noticeable"; case 3: "Strong"; case 4: "Very strong"; default: "Overwhelming" }
}

extension Craving.Trigger {
    var label: String {
        switch self { case .stress: "Stress"; case .coffee: "Coffee"; case .alcohol: "Alcohol"; case .afterMeal: "After a meal"; case .boredom: "Boredom"; case .social: "Social"; case .other: "Other" }
    }
    var symbol: String {
        switch self { case .stress: "brain.head.profile"; case .coffee: "cup.and.saucer.fill"; case .alcohol: "wineglass"; case .afterMeal: "fork.knife"; case .boredom: "clock"; case .social: "person.2.fill"; case .other: "ellipsis" }
    }
}

#Preview { LogCravingView { _, _, _, _ in } }
