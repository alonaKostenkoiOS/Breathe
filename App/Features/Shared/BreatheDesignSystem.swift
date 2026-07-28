import SwiftUI
import UIKit

enum BreatheSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let screen: CGFloat = 20
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let hero: CGFloat = 40
}

enum BreatheRadius {
    static let control: CGFloat = 12
    static let input: CGFloat = 14
    static let card: CGFloat = 18
    static let hero: CGFloat = 24
    static let button: CGFloat = 15
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

extension Font {
    static let breatheBrandTitle = Font.system(size: 42, weight: .bold, design: .serif)
    static let breatheLargeTitle = Font.system(size: 34, weight: .bold, design: .serif)
    static let breatheScreenTitle = Font.system(size: 28, weight: .bold)
    static let breatheSectionTitle = Font.system(size: 20, weight: .semibold)
    static let breatheBody = Font.system(size: 17)
    static let breatheCallout = Font.system(size: 15)
    static let breatheCaption = Font.system(size: 13)
    static let breatheMetric = Font.system(size: 32, weight: .semibold)
}

struct BreatheScreen<Content: View>: View {
    var scrollable = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.breatheBackground.ignoresSafeArea()
            if scrollable {
                ScrollView {
                    content().frame(maxWidth: 680, alignment: .leading)
                        .padding(.horizontal, BreatheSpacing.screen)
                        .padding(.vertical, BreatheSpacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                content().padding(.horizontal, BreatheSpacing.screen)
            }
        }
        .foregroundStyle(Color.breatheText)
    }
}

struct BreathePrimaryButton: View {
    let title: LocalizedStringKey
    var icon: String?
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: BreatheSpacing.xs) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(BreathePrimaryButtonStyle())
        .disabled(disabled)
    }
}

private struct BreathePrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(configuration.isPressed ? Color.breatheAccentPressed : .breatheAccent,
                        in: RoundedRectangle(cornerRadius: BreatheRadius.button))
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct BreatheSecondaryButton: View {
    let title: LocalizedStringKey
    var icon: String?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { if let icon { Image(systemName: icon) }; Text(title).font(.headline) }
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(Color.breatheAccent)
                .background(Color.breatheAccentSoft, in: RoundedRectangle(cornerRadius: BreatheRadius.button))
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
    var body: some View {
        content().frame(maxWidth: .infinity, alignment: .leading).padding(BreatheSpacing.md)
            .background(tint, in: RoundedRectangle(cornerRadius: BreatheRadius.card))
            .overlay(RoundedRectangle(cornerRadius: BreatheRadius.card).stroke(Color.breatheDivider, lineWidth: 1))
            .shadow(color: elevated ? .black.opacity(0.05) : .clear, radius: 12, y: 4)
    }
}

struct BreatheMetricCard: View {
    let icon: String
    let value: String
    let title: LocalizedStringKey
    var tint: Color = .breatheAccentSoft
    var body: some View {
        BreatheCard(tint: tint) {
            VStack(alignment: .leading, spacing: BreatheSpacing.xs) {
                Image(systemName: icon).font(.title3).foregroundStyle(Color.breatheAccent)
                Text(value).font(.breatheMetric).monospacedDigit().minimumScaleFactor(0.75)
                    .contentTransition(.numericText())
                Text(title).font(.breatheCaption).foregroundStyle(Color.breatheTextSecondary)
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
    var body: some View {
        Button(action: action) {
            HStack(spacing: BreatheSpacing.sm) {
                if let icon { Image(systemName: icon).foregroundStyle(Color.breatheAccent).frame(width: 26) }
                VStack(alignment: .leading, spacing: BreatheSpacing.xxs) {
                    Text(title).font(.body.weight(.semibold)).multilineTextAlignment(.leading)
                    if let detail { Text(detail).font(.breatheCaption).foregroundStyle(Color.breatheTextSecondary).multilineTextAlignment(.leading) }
                }
                Spacer(minLength: BreatheSpacing.xs)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(selected ? Color.breatheAccent : .breatheTextTertiary)
            }.frame(minHeight: 48).padding(BreatheSpacing.md)
        }
        .buttonStyle(.plain)
        .background(selected ? Color.breatheAccentSoft : .breatheSurface,
                    in: RoundedRectangle(cornerRadius: BreatheRadius.card))
        .overlay(RoundedRectangle(cornerRadius: BreatheRadius.card)
            .stroke(selected ? Color.breatheAccent : .breatheDivider, lineWidth: selected ? 2 : 1))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct BreatheChip: View {
    let title: LocalizedStringKey
    var icon: String?
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon) }
                Text(title)
                if selected { Image(systemName: "checkmark").font(.caption.bold()) }
            }.padding(.horizontal, 14).frame(minHeight: 44)
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
    var body: some View {
        VStack(alignment: .leading, spacing: BreatheSpacing.xxs) {
            Text(title).font(.breatheSectionTitle)
            if let detail { Text(detail).font(.breatheCallout).foregroundStyle(Color.breatheTextSecondary) }
        }.accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
    }
}

struct BreatheEmptyState: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?
    var body: some View {
        BreatheCard(tint: .breatheSurfaceSoft) {
            VStack(spacing: BreatheSpacing.sm) {
                Image(systemName: icon).font(.system(size: 36)).foregroundStyle(Color.breatheAccent)
                Text(title).font(.breatheSectionTitle).multilineTextAlignment(.center)
                Text(message).font(.breatheCallout).foregroundStyle(Color.breatheTextSecondary).multilineTextAlignment(.center)
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
    var body: some View {
        HStack(alignment: .top, spacing: BreatheSpacing.sm) {
            Image(systemName: icon).foregroundStyle(Color.breatheAccent)
            VStack(alignment: .leading, spacing: BreatheSpacing.xxs) {
                Text(title).font(.headline)
                Text(message).font(.breatheCallout).foregroundStyle(Color.breatheTextSecondary)
            }
        }.padding(BreatheSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: BreatheRadius.card))
    }
}

@MainActor enum BreatheFeedback {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

struct BreatheFlowLayout: Layout {
    var spacing: CGFloat = BreatheSpacing.xs
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
