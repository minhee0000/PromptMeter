import AppKit
import SwiftUI

enum SettingsLayout {
    static let windowWidth: CGFloat = 520
    static let windowHeight: CGFloat = 600
    static let sidePadding: CGFloat = 24
}

enum SettingsPalette {
    static let background = MenuPalette.background
    static let backgroundHighlight = MenuPalette.backgroundHighlight
    static let panel = MenuPalette.panel
    static let panelStroke = MenuPalette.panelStroke
    static let divider = MenuPalette.panelDivider
    static let controlFill = MenuPalette.controlFill
    static let selectedFill = MenuPalette.selectedFill
    static let hoverFill = MenuPalette.hoverFill
    static let primaryText = MenuPalette.primaryText
    static let secondaryText = MenuPalette.secondaryText
    static let mutedText = MenuPalette.mutedText
    static let panelPrimaryText = MenuPalette.panelPrimaryText
    static let panelSecondaryText = MenuPalette.panelSecondaryText
    static let panelMutedText = MenuPalette.panelMutedText
    static let panelControlFill = MenuPalette.panelControlFill
    static let toggleTint = Color(nsColor: .controlAccentColor)
    static let accent = MenuPalette.codexAccent
    static let orange = MenuPalette.claudeAccent
}
