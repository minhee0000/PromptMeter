import SwiftUI

struct ProviderIconView: View {
    let kind: ProviderIconKind
    var tint: Color = MenuPalette.panelPrimaryText.opacity(0.86)

    var body: some View {
        Image(kind.assetName)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }
}
