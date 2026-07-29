import SwiftUI
import Testing
@testable import Breathe

@Suite("Responsive app layout")
struct AppLayoutTests {
    @Test func resolvesCompactFromNarrowOrShortContainers() {
        #expect(AppLayoutMode.resolve(size: CGSize(width: 374, height: 844), dynamicTypeSize: .large) == .compact)
        #expect(AppLayoutMode.resolve(size: CGSize(width: 390, height: 699), dynamicTypeSize: .large) == .compact)
    }

    @Test func resolvesRegularAndExpandedFromAvailableWidth() {
        #expect(AppLayoutMode.resolve(size: CGSize(width: 390, height: 844), dynamicTypeSize: .large) == .regular)
        #expect(AppLayoutMode.resolve(size: CGSize(width: 820, height: 1180), dynamicTypeSize: .large) == .expanded)
    }

    @Test func accessibilityTextUsesCompactComposition() {
        #expect(AppLayoutMode.resolve(size: CGSize(width: 820, height: 1180), dynamicTypeSize: .accessibility3) == .compact)
    }

    @Test func compactMetricsPreserveTouchTargetsAndHideDecorativeArtForAccessibility() {
        let metrics = AppLayoutMetrics(mode: .compact, availableSize: CGSize(width: 320, height: 568), accessibilityText: true)
        #expect(metrics.buttonHeight >= 52)
        #expect(metrics.heroImageHeight == 0)
        #expect(metrics.botanicalHeight == 0)
        #expect(metrics.metricColumns.count == 1)
        #expect(metrics.chartHeight <= 220)
    }
}
