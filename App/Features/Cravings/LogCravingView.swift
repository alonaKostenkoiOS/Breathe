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
            BreatheScreen {
                if saved { confirmation } else { form }
            }
            .navigationTitle("Log a craving")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BreatheIconButton(icon: "xmark", label: "Close", action: { dismiss() })
                }
            }
        }.presentationDragIndicator(.visible).presentationCornerRadius(BreatheRadius.hero)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: BreatheSpacing.lg) {
            BreatheSectionHeader(title: "How strong is it?", detail: "Choose the closest match.")
            HStack(spacing: BreatheSpacing.xs) {
                ForEach(1...5, id: \.self) { value in
                    Button { intensity = value; BreatheFeedback.selection() } label: {
                        VStack(spacing: 5) {
                            Text("\(value)").font(.title3.bold())
                            Text(LocalizedStringKey(intensityLabel(value))).font(.caption2).lineLimit(1).minimumScaleFactor(0.65)
                        }.frame(maxWidth: .infinity, minHeight: 58)
                    }.buttonStyle(.plain)
                        .background(intensity == value ? Color.breatheAccentSoft : .breatheSurface, in: RoundedRectangle(cornerRadius: BreatheRadius.control))
                        .overlay(RoundedRectangle(cornerRadius: BreatheRadius.control).stroke(intensity == value ? Color.breatheAccent : .breatheDivider, lineWidth: intensity == value ? 2 : 1))
                        .accessibilityLabel("Intensity \(value)")
                        .accessibilityValue(Text(LocalizedStringKey(intensityLabel(value))))
                        .accessibilityAddTraits(intensity == value ? .isSelected : [])
                }
            }
            BreatheSectionHeader(title: "What brought it on?")
            BreatheFlowLayout(spacing: BreatheSpacing.xs) {
                ForEach(Craving.Trigger.allCases, id: \.self) { value in
                    BreatheChip(title: LocalizedStringKey(value.label), icon: value.symbol,
                                selected: trigger == value) { trigger = value; BreatheFeedback.selection() }
                }
            }
            BreatheSectionHeader(title: "What happened?")
            VStack(spacing: BreatheSpacing.xs) {
                outcomeCard(.resisted, "I resisted", "shield.checkered")
                outcomeCard(.smoked, "I smoked", "arrow.counterclockwise")
                outcomeCard(.ongoing, "Still dealing with it", "wind")
            }
            VStack(alignment: .leading, spacing: BreatheSpacing.xs) {
                Text("Note (optional)").font(.headline)
                TextField("Anything you want to remember?", text: $note, axis: .vertical)
                    .lineLimit(2...4).padding(BreatheSpacing.sm)
                    .background(Color.breatheSurface, in: RoundedRectangle(cornerRadius: BreatheRadius.input))
                    .overlay(RoundedRectangle(cornerRadius: BreatheRadius.input).stroke(Color.breatheDivider))
            }
            BreathePrimaryButton(title: outcome == .ongoing ? "Open Craving Rescue" : "Save craving",
                                 icon: outcome == .ongoing ? "wind" : "checkmark", disabled: saving) { save() }
        }.padding(.bottom, BreatheSpacing.xl)
    }

    private var confirmation: some View {
        VStack(spacing: BreatheSpacing.lg) {
            Spacer(minLength: BreatheSpacing.hero)
            Image(systemName: outcome == .resisted ? "checkmark.circle.fill" : "heart.circle.fill")
                .font(.system(size: 64)).foregroundStyle(Color.breatheAccent)
            Text(outcome == .resisted ? "You made it through." : "Your progress still matters.")
                .font(.breatheLargeTitle).multilineTextAlignment(.center)
            Text("Logging this moment helps Breathe understand what support works for you.")
                .foregroundStyle(Color.breatheTextSecondary).multilineTextAlignment(.center)
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
