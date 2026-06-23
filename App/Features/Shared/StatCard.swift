import SwiftUI

/// A single headline statistic with an icon, value and caption. Reused across
/// the dashboard grid so every metric reads consistently.
struct StatCard: View {
    let icon: String
    let value: String
    let caption: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption): \(value)")
    }
}

#Preview {
    StatCard(icon: "dollarsign.circle.fill", value: "$124.50", caption: "Saved", tint: .green)
        .padding()
}
