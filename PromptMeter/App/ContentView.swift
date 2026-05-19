import SwiftUI

struct ContentView: View {
    @ObservedObject var model: PromptMeterModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                MenuTodayUsageCard(
                    items: model.menuTodayUsageItems,
                    statusText: model.providerRefreshLabel
                )

                ForEach(model.providerUsages) { provider in
                    MenuProviderPanel(provider: provider, isLoading: model.isRefreshingProviders)
                }

                MenuFooterActions(model: model)
            }
            .padding(.horizontal, MenuLayout.sidePadding)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .frame(width: MenuLayout.popoverWidth, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .background(menuBackground)
    }

    private var menuBackground: some View {
        ZStack {
            MenuPalette.background
            LinearGradient(
                colors: [
                    MenuPalette.backgroundHighlight,
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView(model: PromptMeterModel(autoRefreshProviders: false))
                .previewDisplayName("Light")
                .preferredColorScheme(.light)

            ContentView(model: PromptMeterModel(autoRefreshProviders: false))
                .previewDisplayName("Dark")
                .preferredColorScheme(.dark)
        }
        .frame(width: MenuLayout.popoverWidth)
        .fixedSize(horizontal: false, vertical: true)
        .previewLayout(.sizeThatFits)
    }
}
#endif
