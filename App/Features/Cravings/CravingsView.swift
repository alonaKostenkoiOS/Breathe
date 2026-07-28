import SwiftUI
import Charts
import BreatheCore

struct CravingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: CravingsViewModel?
    @State private var isLogging = false
    @State private var showRescue = false

    var body: some View {
        NavigationStack {
            Group { if let model { content(model) } else { ProgressView().tint(.breatheAccent) } }
                .navigationTitle("Cravings")
                .toolbarBackground(Color.breatheBackground, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        BreatheIconButton(icon: "plus", label: "Log a craving", action: { isLogging = true })
                    }
                }
        }
        .onAppear { if model == nil { model = CravingsViewModel(environment: environment) } }
        .task { await model?.load() }
        .sheet(isPresented: $isLogging) {
            LogCravingView { intensity, trigger, resisted, note in
                await model?.log(intensity: intensity, trigger: trigger, didResist: resisted, note: note)
            } onRescue: { showRescue = true }
        }
        .fullScreenCover(isPresented: $showRescue) {
            CravingRescueView(personalReason: environment.planStore.profile?.personalReason)
        }
    }

    private func content(_ model: CravingsViewModel) -> some View {
        BreatheScreen {
            VStack(alignment: .leading, spacing: BreatheSpacing.lg) {
                BreatheBanner(icon: "waveform.path.ecg", title: "Notice without judgment",
                              message: "Each entry helps reveal when a little extra support could help.")
                if model.hasLoadError {
                    BreatheEmptyState(icon: "arrow.clockwise", title: "We couldn’t load your history",
                                      message: "Your data is still on this device. Try loading it again.",
                                      actionTitle: "Try Again", action: { Task { await model.load() } })
                } else if model.cravings.isEmpty {
                    BreatheEmptyState(icon: "waveform.path.ecg", title: "No cravings logged yet",
                                      message: "When you record difficult moments, Breathe can start finding your personal patterns.",
                                      actionTitle: "Log a craving", action: { isLogging = true })
                } else {
                    insightSummary(model)
                    weeklyTrend(model.cravings)
                    history(model)
                }
            }.padding(.bottom, BreatheSpacing.xl)
        }
    }

    private func insightSummary(_ model: CravingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: BreatheSpacing.sm) {
            BreatheSectionHeader(title: "Your recent pattern")
            BreatheCard(tint: .breatheSurfaceSoft) {
                VStack(alignment: .leading, spacing: BreatheSpacing.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Int(model.insights.resistanceRate * 100))%").font(.breatheMetric).monospacedDigit()
                        Text("of cravings passed without smoking").font(.breatheCallout).foregroundStyle(Color.breatheTextSecondary)
                    }
                    if let top = model.insights.topTrigger {
                        Label("Your most common recent trigger was \(top.label.lowercased()).", systemImage: top.symbol)
                            .font(.breatheCallout).foregroundStyle(Color.breatheTextSecondary)
                    }
                }
            }
        }
    }

    private func weeklyTrend(_ cravings: [Craving]) -> some View {
        let recent = cravings.filter { $0.date > Date().addingTimeInterval(-7 * 86_400) }
        return VStack(alignment: .leading, spacing: BreatheSpacing.sm) {
            BreatheSectionHeader(title: "This week", detail: "A simple view of your difficult moments.")
            BreatheCard {
                Chart(recent) { item in
                    BarMark(x: .value("Day", item.date, unit: .day), y: .value("Intensity", item.intensity))
                        .foregroundStyle(Color.breatheAccentMedium)
                        .cornerRadius(4)
                }.frame(height: 150).chartLegend(.hidden)
                Text(recent.isEmpty ? "No cravings recorded in the last seven days." : "You logged \(recent.count) difficult moments in the last seven days.")
                    .font(.breatheCallout).foregroundStyle(Color.breatheTextSecondary).padding(.top, BreatheSpacing.xs)
            }
        }
    }

    private func history(_ model: CravingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: BreatheSpacing.sm) {
            BreatheSectionHeader(title: "History")
            ForEach(model.cravings) { craving in
                BreatheCard {
                    HStack(spacing: BreatheSpacing.sm) {
                        Image(systemName: craving.didResist ? "checkmark.shield.fill" : "heart.fill")
                            .foregroundStyle(Color.breatheAccent).frame(width: 32)
                        VStack(alignment: .leading, spacing: BreatheSpacing.xxs) {
                            Text(LocalizedStringKey(craving.trigger.label)).font(.headline)
                            Text(craving.date, format: .dateTime.weekday(.wide).hour().minute())
                                .font(.breatheCaption).foregroundStyle(Color.breatheTextSecondary)
                        }
                        Spacer(); Text("\(craving.intensity)/5").font(.breatheCallout.weight(.semibold)).monospacedDigit()
                    }
                }.contextMenu { Button("Delete", role: .destructive) { Task { await model.delete(craving) } } }
            }
        }
    }
}

#Preview { CravingsView().environment(AppEnvironment.preview()) }
