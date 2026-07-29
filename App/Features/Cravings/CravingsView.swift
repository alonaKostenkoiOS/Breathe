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
        BreatheScreen { metrics in
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
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
                    insightSummary(model, metrics)
                    weeklyTrend(model.cravings, metrics)
                    history(model, metrics)
                }
            }.padding(.bottom, metrics.majorSpacing)
        }
    }

    private func insightSummary(_ model: CravingsViewModel, _ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.internalSpacing) {
            BreatheSectionHeader(title: "Your recent pattern")
            BreatheCard(tint: .breatheSurfaceSoft) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: metrics.internalSpacing) { insightRate(model, metrics) }
                    VStack(alignment: .leading, spacing: metrics.compactSpacing) { insightRate(model, metrics) }
                }
                if let top = model.insights.topTrigger {
                    Label("Your most common recent trigger was \(top.label.lowercased()).", systemImage: top.symbol)
                        .font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder private func insightRate(_ model: CravingsViewModel, _ metrics: AppLayoutMetrics) -> some View {
        Text("\(Int(model.insights.resistanceRate * 100))%").font(AppTypography.metric(for: metrics.mode)).monospacedDigit()
        Text("of cravings passed without smoking").font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
    }

    private func weeklyTrend(_ cravings: [Craving], _ metrics: AppLayoutMetrics) -> some View {
        let recent = cravings.filter { $0.date > Date().addingTimeInterval(-7 * 86_400) }
        return VStack(alignment: .leading, spacing: metrics.internalSpacing) {
            BreatheSectionHeader(title: "This week", detail: "A simple view of your difficult moments.")
            BreatheCard {
                Chart(recent) { item in
                    BarMark(x: .value("Day", item.date, unit: .day), y: .value("Intensity", item.intensity))
                        .foregroundStyle(Color.breatheAccentMedium)
                        .cornerRadius(4)
                }.frame(height: metrics.chartHeight).chartLegend(.hidden)
                Text(recent.isEmpty ? "No cravings recorded in the last seven days." : "You logged \(recent.count) difficult moments in the last seven days.")
                    .font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, metrics.compactSpacing)
            }
        }
    }

    private func history(_ model: CravingsViewModel, _ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.internalSpacing) {
            BreatheSectionHeader(title: "History")
            ForEach(model.cravings) { craving in
                BreatheCard {
                    HStack(spacing: metrics.internalSpacing) {
                        Image(systemName: craving.didResist ? "checkmark.shield.fill" : "heart.fill")
                            .foregroundStyle(Color.breatheAccent).frame(width: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey(craving.trigger.label)).font(.headline)
                            Text(craving.date, format: .dateTime.weekday(.wide).hour().minute())
                                .font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
                        }
                        Spacer(); Text("\(craving.intensity)/5").font(AppTypography.callout(for: metrics.mode).weight(.semibold)).monospacedDigit()
                    }
                }.contextMenu { Button("Delete", role: .destructive) { Task { await model.delete(craving) } } }
            }
        }
    }
}

#Preview { CravingsView().environment(AppEnvironment.preview()) }
