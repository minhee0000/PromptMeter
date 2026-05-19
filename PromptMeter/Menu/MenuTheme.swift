import AppKit
import SwiftUI

enum MenuLayout {
    static let popoverWidth: CGFloat = 320
    static let sidePadding: CGFloat = 16
    static let panelPadding: CGFloat = 13
    static let providerPanelMinHeight: CGFloat = 111
    static let metricTitleWidth: CGFloat = 50
    static let metricBarWidth: CGFloat = 86
    static let metricValueWidth: CGFloat = 38
    static let metricResetWidth: CGFloat = 64
    static let paceMarkerWidth: CGFloat = 2
    static let paceMarkerHeight: CGFloat = 5
}

enum MenuPalette {
    static let background = Color.adaptive(
        light: .rgba(0.890, 0.890, 0.870),
        dark: .rgba(0.150, 0.145, 0.148)
    )
    static let backgroundHighlight = Color.adaptive(
        light: .rgba(1, 1, 1, 0.34),
        dark: .rgba(1, 1, 1, 0.055)
    )
    static let panel = Color.adaptive(
        light: .rgba(0.088, 0.092, 0.094, 0.97),
        dark: .rgba(0.070, 0.073, 0.075, 0.985)
    )
    static let panelStroke = Color.adaptive(
        light: .rgba(0, 0, 0, 0.36),
        dark: .rgba(1, 1, 1, 0.105)
    )
    static let panelDivider = Color.adaptive(
        light: .rgba(1, 1, 1, 0.10),
        dark: .rgba(1, 1, 1, 0.09)
    )
    static let controlFill = Color.adaptive(
        light: .rgba(0, 0, 0, 0.055),
        dark: .rgba(0, 0, 0, 0.22)
    )
    static let selectedFill = Color.adaptive(
        light: .rgba(1, 1, 1, 0.38),
        dark: .rgba(0, 0, 0, 0.30)
    )
    static let hoverFill = Color.adaptive(
        light: .rgba(0, 0, 0, 0.055),
        dark: .rgba(0, 0, 0, 0.24)
    )
    static let trackpadSurface = Color.adaptive(
        light: .rgba(0.805, 0.815, 0.792, 0.96),
        dark: .rgba(0.185, 0.180, 0.176, 0.96)
    )
    static let trackpadSurfaceStroke = Color.adaptive(
        light: .rgba(1, 1, 1, 0.38),
        dark: .rgba(1, 1, 1, 0.08)
    )
    static let track = Color.adaptive(
        light: .rgba(0, 0, 0, 0.09),
        dark: .rgba(0, 0, 0, 0.22)
    )
    static let panelControlFill = Color.adaptive(
        light: .rgba(1, 1, 1, 0.08),
        dark: .rgba(1, 1, 1, 0.075)
    )
    static let panelTrack = Color.adaptive(
        light: .rgba(1, 1, 1, 0.11),
        dark: .rgba(1, 1, 1, 0.105)
    )
    static let primaryText = Color.adaptive(
        light: .rgba(0.07, 0.075, 0.085, 0.90),
        dark: .rgba(1, 1, 1, 0.92)
    )
    static let secondaryText = Color.adaptive(
        light: .rgba(0.07, 0.075, 0.085, 0.56),
        dark: .rgba(1, 1, 1, 0.48)
    )
    static let mutedText = Color.adaptive(
        light: .rgba(0.07, 0.075, 0.085, 0.38),
        dark: .rgba(1, 1, 1, 0.34)
    )
    static let metricTitleText = Color.adaptive(
        light: .rgba(0.07, 0.075, 0.085, 0.66),
        dark: .rgba(1, 1, 1, 0.68)
    )
    static let iconSecondary = Color.adaptive(
        light: .rgba(0.07, 0.075, 0.085, 0.52),
        dark: .rgba(1, 1, 1, 0.56)
    )
    static let skeletonFill = Color.adaptive(
        light: .rgba(0, 0, 0, 0.075),
        dark: .rgba(1, 1, 1, 0.09)
    )
    static let shimmer = Color.adaptive(
        light: .rgba(1, 1, 1, 0.62),
        dark: .rgba(1, 1, 1, 0.28)
    )
    static let panelPrimaryText = Color.adaptive(
        light: .rgba(1, 1, 1, 0.96),
        dark: .rgba(1, 1, 1, 0.92)
    )
    static let panelSecondaryText = Color.adaptive(
        light: .rgba(1, 1, 1, 0.66),
        dark: .rgba(1, 1, 1, 0.48)
    )
    static let panelMutedText = Color.adaptive(
        light: .rgba(1, 1, 1, 0.46),
        dark: .rgba(1, 1, 1, 0.34)
    )
    static let panelMetricTitleText = Color.adaptive(
        light: .rgba(1, 1, 1, 0.74),
        dark: .rgba(1, 1, 1, 0.68)
    )
    static let panelIconSecondary = Color.adaptive(
        light: .rgba(1, 1, 1, 0.66),
        dark: .rgba(1, 1, 1, 0.56)
    )
    static let panelSkeletonFill = Color.adaptive(
        light: .rgba(1, 1, 1, 0.10),
        dark: .rgba(1, 1, 1, 0.09)
    )
    static let panelShimmer = Color.adaptive(
        light: .rgba(1, 1, 1, 0.30),
        dark: .rgba(1, 1, 1, 0.28)
    )
    static let paceMarker = Color.adaptive(
        light: .rgba(0.96, 0.66, 0.18, 0.95),
        dark: .rgba(1.00, 0.74, 0.28, 0.94)
    )
    static let codexAccent = Color.adaptive(
        light: .rgba(0.06, 0.60, 0.68),
        dark: .rgba(0.34, 0.82, 0.88)
    )
    static let codexProgressAccent = Color.adaptive(
        light: .rgba(0.133, 0.773, 0.369),
        dark: .rgba(0.133, 0.773, 0.369)
    )
    static let lowQuotaProgressAccent = Color.adaptive(
        light: .rgba(0.973, 0.443, 0.443),
        dark: .rgba(0.973, 0.443, 0.443)
    )
    static let claudeProgressAccent = Color.adaptive(
        light: .rgba(0.165, 0.471, 0.839),
        dark: .rgba(0.165, 0.471, 0.839)
    )
    static let geminiProgressAccent = Color.adaptive(
        light: .rgba(0.588, 0.439, 0.980),
        dark: .rgba(0.588, 0.439, 0.980)
    )
    static let claudeAccent = Color.adaptive(
        light: .rgba(0.77, 0.38, 0.20),
        dark: .rgba(0.93, 0.58, 0.39)
    )
}

private extension Color {
    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        })
    }
}

private extension NSColor {
    static func rgba(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
