import Foundation

extension PromptMeterModel {
    var menuTodayUsageItems: [MenuTodayUsageItem] {
        let providerOrder: [ProviderIconKind] = [.codex, .claude]
        return providerOrder.compactMap { provider in
            guard shouldShowTodayUsage(for: provider),
                  let snapshot = todayTokenUsages[provider],
                  !snapshot.isEmpty else {
                return nil
            }

            return MenuTodayUsageItem(
                id: provider.providerID,
                provider: provider,
                systemIcon: nil,
                title: provider.displayName,
                value: L10n.format(.menuTodayUsageTokensFormat, Self.compactTokenText(snapshot.totalTokens)),
                metrics: todayUsageMetrics(snapshot),
                progress: nil
            )
        }
    }

    func lowestSessionRemainingStatuses(limit: Int) -> [MenuBarSessionStatus] {
        var statuses: [MenuBarSessionStatus] = []

        if case .connected(let snapshot) = codexState,
           let primary = snapshot.primary {
            statuses.append(
                MenuBarSessionStatus(
                    remainingPercent: primary.remainingPercent,
                    icon: .codex,
                    providerName: ProviderIconKind.codex.displayName
                )
            )
        }

        if case .connected(let snapshot) = claudeState,
           let session = snapshot.session {
            statuses.append(
                MenuBarSessionStatus(
                    remainingPercent: session.remainingPercent,
                    icon: .claude,
                    providerName: ProviderIconKind.claude.displayName
                )
            )
        }

        if case .connected(let snapshot) = geminiState,
           let primary = snapshot.primary {
            statuses.append(
                MenuBarSessionStatus(
                    remainingPercent: primary.remainingPercent,
                    icon: .gemini,
                    providerName: ProviderIconKind.gemini.displayName
                )
            )
        }

        return Array(statuses.sorted { $0.remainingPercent < $1.remainingPercent }.prefix(limit))
    }

    private func shouldShowTodayUsage(for provider: ProviderIconKind) -> Bool {
        switch provider {
        case .codex:
            if case .missingCLI = codexState { return false }
            return true
        case .claude:
            if case .missingCLI = claudeState { return false }
            return true
        case .gemini:
            return false
        }
    }

    private func todayUsageMetrics(_ snapshot: LocalTokenUsageSnapshot) -> [MenuTodayUsageMetric] {
        var metrics = [
            MenuTodayUsageMetric(label: L10n.tr(.menuTodayUsageIn), value: Self.compactTokenText(snapshot.inputTokens)),
            MenuTodayUsageMetric(label: L10n.tr(.menuTodayUsageOut), value: Self.compactTokenText(snapshot.outputTokens))
        ]

        if snapshot.cacheTokens > 0 {
            metrics.append(MenuTodayUsageMetric(label: L10n.tr(.menuTodayUsageCache), value: Self.compactTokenText(snapshot.cacheTokens)))
        }

        if let estimatedCostAmount = snapshot.estimatedCostAmount,
           let estimatedCostUnit = snapshot.estimatedCostUnit {
            metrics.append(MenuTodayUsageMetric(label: L10n.tr(.menuTodayUsageEstimated), value: Self.compactCostText(estimatedCostAmount, unit: estimatedCostUnit)))
        }

        return metrics
    }

    private static func compactTokenText(_ value: Int) -> String {
        PromptMetrics.compactCount(value)
    }

    private static func compactCostText(_ value: Double, unit: LocalTokenUsageCostUnit) -> String {
        switch unit {
        case .usd:
            if value < 0.01 {
                return String(format: "$%.4f", value)
            }
            if value < 100 {
                return String(format: "$%.2f", value)
            }
            return String(format: "$%.0f", value)
        case .credits:
            if value < 10 {
                return String(format: "%.2f cr", value)
            }
            if value < 100 {
                return String(format: "%.1f cr", value)
            }
            return "\(Int(value.rounded())) cr"
        }
    }
}
