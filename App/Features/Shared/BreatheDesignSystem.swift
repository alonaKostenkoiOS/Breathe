import SwiftUI
import UIKit

enum AppLayoutMode: Sendable {
    case compact, regular, expanded

    static func resolve(size: CGSize, dynamicTypeSize: DynamicTypeSize) -> AppLayoutMode {
        if dynamicTypeSize.isAccessibilitySize { return .compact }
        if size.width < 375 || size.height < 700 { return .compact }
        if size.width >= 700 { return .expanded }
        return .regular
    }
}

struct AppLayoutMetrics: Sendable, Equatable {
    let mode: AppLayoutMode
    let availableSize: CGSize
    let accessibilityText: Bool

    static let fallback = AppLayoutMetrics(mode: .regular, availableSize: CGSize(width: 390, height: 844), accessibilityText: false)

    var screenPadding: CGFloat { switch mode { case .compact: 16; case .regular: 20; case .expanded: 28 } }
    var sectionSpacing: CGFloat { switch mode { case .compact: 20; case .regular: 28; case .expanded: 32 } }
    var cardPadding: CGFloat { switch mode { case .compact: 14; case .regular: 16; case .expanded: 20 } }
    var cardRadius: CGFloat { mode == .compact ? 16 : 20 }
    var buttonHeight: CGFloat { switch mode { case .compact: 52; case .regular: 56; case .expanded: 58 } }
    var controlRadius: CGFloat { mode == .compact ? 12 : 14 }
    var internalSpacing: CGFloat { mode == .compact ? 10 : 12 }
    var compactSpacing: CGFloat { mode == .compact ? 6 : 8 }
    var majorSpacing: CGFloat { mode == .compact ? 24 : 32 }
    var heroImageHeight: CGFloat {
        guard !accessibilityText else { return 0 }
        let proposed = availableSize.height * (mode == .compact ? 0.29 : 0.34)
        return min(max(proposed, mode == .compact ? 200 : 240), mode == .compact ? 250 : 330)
    }
    var botanicalHeight: CGFloat { accessibilityText ? 0 : (mode == .compact ? 130 : 180) }
    var metricColumns: [GridItem] {
        if accessibilityText || availableSize.width - screenPadding * 2 < 350 { return [GridItem(.flexible())] }
        return [GridItem(.flexible()), GridItem(.flexible())]
    }
    var chartHeight: CGFloat { mode == .compact ? 190 : (mode == .expanded ? 240 : 210) }
    var breathingDiameter: CGFloat {
        let widthLimit = availableSize.width - screenPadding * 4
        let heightLimit = availableSize.height * (mode == .compact ? 0.25 : 0.31)
        return min(max(min(widthLimit, heightLimit), 150), mode == .compact ? 190 : 230)
    }
    var maxContentWidth: CGFloat { mode == .expanded ? 720 : .infinity }
}

private struct AppLayoutMetricsKey: EnvironmentKey { static let defaultValue = AppLayoutMetrics.fallback }
extension EnvironmentValues {
    var appLayoutMetrics: AppLayoutMetrics {
        get { self[AppLayoutMetricsKey.self] }
        set { self[AppLayoutMetricsKey.self] = newValue }
    }
}

enum AppTypography {
    static func heroTitle(for mode: AppLayoutMode) -> Font { .system(mode == .compact ? .title : .largeTitle, design: .serif, weight: .bold) }
    static func screenTitle(for mode: AppLayoutMode) -> Font { .system(mode == .compact ? .title2 : .title, weight: .bold) }
    static func sectionTitle(for mode: AppLayoutMode) -> Font { .system(mode == .compact ? .headline : .title3, weight: .semibold) }
    static func body(for mode: AppLayoutMode) -> Font { mode == .compact ? .subheadline : .body }
    static func callout(for mode: AppLayoutMode) -> Font { mode == .compact ? .subheadline : .callout }
    static func button(for mode: AppLayoutMode) -> Font { .headline.weight(.semibold) }
    static func caption(for mode: AppLayoutMode) -> Font { .caption }
    static func metric(for mode: AppLayoutMode) -> Font { (mode == .compact ? Font.title : .largeTitle).weight(.semibold) }
}

extension Color {
    static let breatheBackground = Color("BackgroundPrimary")
    static let breatheBackgroundSecondary = Color("BackgroundSecondary")
    static let breatheSurface = Color("SurfacePrimary")
    static let breatheSurfaceSoft = Color("SurfaceSoft")
    static let breatheText = Color("TextPrimary")
    static let breatheTextSecondary = Color("TextSecondary")
    static let breatheTextTertiary = Color("TextTertiary")
    static let breatheAccent = Color("AccentPrimary")
    static let breatheAccentPressed = Color("AccentPressed")
    static let breatheAccentSoft = Color("AccentSoft")
    static let breatheAccentMedium = Color("AccentMedium")
    static let breatheSky = Color("SkySoft")
    static let breathePeach = Color("PeachSoft")
    static let breatheYellow = Color("YellowSoft")
    static let breatheDivider = Color("Divider")
    static let breatheDestructive = Color("Destructive")
}

struct BreatheScreen<Content: View>: View {
    var scrollable = true
    @ViewBuilder let content: (AppLayoutMetrics) -> Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            let mode = AppLayoutMode.resolve(size: proxy.size, dynamicTypeSize: dynamicTypeSize)
            let metrics = AppLayoutMetrics(mode: mode, availableSize: proxy.size, accessibilityText: dynamicTypeSize.isAccessibilitySize)
            ZStack {
                Color.breatheBackground.ignoresSafeArea()
                if scrollable {
                    ScrollView {
                        content(metrics).environment(\.appLayoutMetrics, metrics)
                            .frame(maxWidth: metrics.maxContentWidth, alignment: .leading)
                            .padding(.horizontal, metrics.screenPadding)
                            .padding(.vertical, metrics.cardPadding)
                            .frame(maxWidth: .infinity)
                    }.scrollDismissesKeyboard(.interactively)
                } else {
                    content(metrics).environment(\.appLayoutMetrics, metrics)
                        .frame(maxWidth: metrics.maxContentWidth, maxHeight: .infinity)
                        .padding(.horizontal, metrics.screenPadding)
                }
            }
            .foregroundStyle(Color.breatheText)
        }.background(Color.breatheBackground)
    }
}

struct BreathePrimaryButton: View {
    let title: LocalizedStringKey
    var icon: String?
    var disabled = false
    let action: () -> Void
    @Environment(\.appLayoutMetrics) private var metrics

    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.compactSpacing) {
                if let icon { Image(systemName: icon) }
                Text(title).font(AppTypography.button(for: metrics.mode)).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: metrics.buttonHeight)
            .padding(.vertical, metrics.accessibilityText ? 6 : 0)
        }
        .buttonStyle(BreathePrimaryButtonStyle())
        .disabled(disabled)
    }
}

private struct BreathePrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appLayoutMetrics) private var metrics
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(configuration.isPressed ? Color.breatheAccentPressed : .breatheAccent,
                        in: RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct BreatheSecondaryButton: View {
    let title: LocalizedStringKey
    var icon: String?
    let action: () -> Void
    @Environment(\.appLayoutMetrics) private var metrics
    var body: some View {
        Button(action: action) {
            HStack { if let icon { Image(systemName: icon) }; Text(title).font(AppTypography.button(for: metrics.mode)).fixedSize(horizontal: false, vertical: true) }
                .frame(maxWidth: .infinity, minHeight: metrics.buttonHeight)
                .padding(.vertical, metrics.accessibilityText ? 6 : 0)
                .foregroundStyle(Color.breatheAccent)
                .background(Color.breatheAccentSoft, in: RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous))
        }.buttonStyle(.plain)
    }
}

struct BreatheIconButton: View {
    let icon: String
    let label: LocalizedStringKey
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: icon).frame(width: 44, height: 44).contentShape(Rectangle()) }
            .buttonStyle(.plain).foregroundStyle(Color.breatheAccent).accessibilityLabel(label)
    }
}

struct BreatheCard<Content: View>: View {
    var tint: Color = .breatheSurface
    var elevated = false
    @ViewBuilder let content: () -> Content
    @Environment(\.appLayoutMetrics) private var metrics
    var body: some View {
        content().frame(maxWidth: .infinity, alignment: .leading).padding(metrics.cardPadding)
            .background(tint, in: RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous).stroke(Color.breatheDivider, lineWidth: 1))
            .shadow(color: elevated ? .black.opacity(0.05) : .clear, radius: 12, y: 4)
    }
}

struct BreatheMetricCard: View {
    let icon: String
    let value: String
    let title: LocalizedStringKey
    var tint: Color = .breatheAccentSoft
    @Environment(\.appLayoutMetrics) private var metrics
    var body: some View {
        BreatheCard(tint: tint) {
            VStack(alignment: .leading, spacing: metrics.compactSpacing) {
                Image(systemName: icon).font(.title3).foregroundStyle(Color.breatheAccent)
                Text(value).font(AppTypography.metric(for: metrics.mode)).monospacedDigit().minimumScaleFactor(0.8)
                    .contentTransition(.numericText())
                Text(title).font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }.accessibilityElement(children: .combine)
    }
}

struct BreatheSelectionCard: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    var icon: String?
    let selected: Bool
    let action: () -> Void
    @Environment(\.appLayoutMetrics) private var metrics
    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.internalSpacing) {
                if let icon { Image(systemName: icon).foregroundStyle(Color.breatheAccent).frame(width: 26) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body.weight(.semibold)).multilineTextAlignment(.leading)
                    if let detail { Text(detail).font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true) }
                }
                Spacer(minLength: metrics.compactSpacing)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(selected ? Color.breatheAccent : .breatheTextTertiary)
            }.frame(minHeight: 44).padding(metrics.cardPadding)
        }
        .buttonStyle(.plain)
        .background(selected ? Color.breatheAccentSoft : .breatheSurface,
                    in: RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous)
            .stroke(selected ? Color.breatheAccent : .breatheDivider, lineWidth: selected ? 2 : 1))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct BreatheChip: View {
    let title: LocalizedStringKey
    var icon: String?
    let selected: Bool
    let action: () -> Void
    @Environment(\.appLayoutMetrics) private var metrics
    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.compactSpacing) {
                if let icon { Image(systemName: icon) }
                Text(title)
                if selected { Image(systemName: "checkmark").font(.caption.bold()) }
            }.padding(.horizontal, metrics.cardPadding).frame(minHeight: 44)
        }.buttonStyle(.plain)
            .foregroundStyle(selected ? Color.breatheText : .breatheTextSecondary)
            .background(selected ? Color.breatheAccentSoft : .breatheSurface, in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.breatheAccent : .breatheDivider, lineWidth: selected ? 2 : 1))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct BreatheProgressBar: View {
    let value: Double
    var body: some View {
        ProgressView(value: min(max(value, 0), 1)).tint(Color.breatheAccent)
            .scaleEffect(x: 1, y: 1.5).accessibilityValue(Text("\(Int(value * 100)) percent"))
    }
}

struct BreatheSectionHeader: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    @Environment(\.appLayoutMetrics) private var metrics
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(AppTypography.sectionTitle(for: metrics.mode)).fixedSize(horizontal: false, vertical: true)
            if let detail { Text(detail).font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true) }
        }.accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
    }
}

struct BreatheEmptyState: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?
    @Environment(\.appLayoutMetrics) private var metrics
    var body: some View {
        BreatheCard(tint: .breatheSurfaceSoft) {
            VStack(spacing: metrics.internalSpacing) {
                Image(systemName: icon).font(.system(size: metrics.mode == .compact ? 30 : 36)).foregroundStyle(Color.breatheAccent)
                Text(title).font(AppTypography.sectionTitle(for: metrics.mode)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Text(message).font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action { BreatheSecondaryButton(title: actionTitle, action: action) }
            }.frame(maxWidth: .infinity)
        }.accessibilityElement(children: .contain)
    }
}

struct BreatheBanner: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var tint: Color = .breatheSky
    @Environment(\.appLayoutMetrics) private var metrics
    var body: some View {
        HStack(alignment: .top, spacing: metrics.internalSpacing) {
            Image(systemName: icon).foregroundStyle(Color.breatheAccent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(message).font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(metrics.cardPadding).frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous))
    }
}

@MainActor enum BreatheFeedback {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

struct BreatheFlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        var points: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += lineHeight + spacing; lineHeight = 0 }
            points.append(CGPoint(x: x, y: y)); x += size.width + spacing; lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: width, height: y + lineHeight), points)
    }
}
