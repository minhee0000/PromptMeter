struct LocalTokenUsageSnapshot: Equatable, Sendable {
    let provider: ProviderIconKind
    let inputTokens: Int
    let cacheReadTokens: Int
    let cacheCreationTokens: Int
    let outputTokens: Int
    let reasoningOutputTokens: Int
    let reasoningEffort: String?
    let reportedTotalTokens: Int?
    let estimatedCostAmount: Double?
    let estimatedCostUnit: LocalTokenUsageCostUnit?

    var totalTokens: Int {
        reportedTotalTokens ?? (inputTokens + cacheReadTokens + cacheCreationTokens + outputTokens)
    }

    var cacheTokens: Int {
        cacheReadTokens + cacheCreationTokens
    }

    var isEmpty: Bool {
        totalTokens == 0
    }

    static func + (lhs: LocalTokenUsageSnapshot, rhs: LocalTokenUsageSnapshot) -> LocalTokenUsageSnapshot {
        LocalTokenUsageSnapshot(
            provider: lhs.provider,
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens,
            cacheCreationTokens: lhs.cacheCreationTokens + rhs.cacheCreationTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            reasoningOutputTokens: lhs.reasoningOutputTokens + rhs.reasoningOutputTokens,
            reasoningEffort: lhs.reasoningEffort ?? rhs.reasoningEffort,
            reportedTotalTokens: lhs.totalTokens + rhs.totalTokens,
            estimatedCostAmount: combinedCost(lhs.estimatedCostAmount, rhs.estimatedCostAmount),
            estimatedCostUnit: lhs.estimatedCostUnit ?? rhs.estimatedCostUnit
        )
    }

    static func - (lhs: LocalTokenUsageSnapshot, rhs: LocalTokenUsageSnapshot) -> LocalTokenUsageSnapshot {
        LocalTokenUsageSnapshot(
            provider: lhs.provider,
            inputTokens: max(0, lhs.inputTokens - rhs.inputTokens),
            cacheReadTokens: max(0, lhs.cacheReadTokens - rhs.cacheReadTokens),
            cacheCreationTokens: max(0, lhs.cacheCreationTokens - rhs.cacheCreationTokens),
            outputTokens: max(0, lhs.outputTokens - rhs.outputTokens),
            reasoningOutputTokens: max(0, lhs.reasoningOutputTokens - rhs.reasoningOutputTokens),
            reasoningEffort: lhs.reasoningEffort ?? rhs.reasoningEffort,
            reportedTotalTokens: max(0, lhs.totalTokens - rhs.totalTokens),
            estimatedCostAmount: subtractedCost(lhs.estimatedCostAmount, rhs.estimatedCostAmount),
            estimatedCostUnit: lhs.estimatedCostUnit ?? rhs.estimatedCostUnit
        )
    }

    static func empty(provider: ProviderIconKind) -> LocalTokenUsageSnapshot {
        LocalTokenUsageSnapshot(
            provider: provider,
            inputTokens: 0,
            cacheReadTokens: 0,
            cacheCreationTokens: 0,
            outputTokens: 0,
            reasoningOutputTokens: 0,
            reasoningEffort: nil,
            reportedTotalTokens: nil,
            estimatedCostAmount: nil,
            estimatedCostUnit: nil
        )
    }

    private static func combinedCost(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard lhs != nil || rhs != nil else { return nil }
        return (lhs ?? 0) + (rhs ?? 0)
    }

    private static func subtractedCost(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard lhs != nil || rhs != nil else { return nil }
        return max(0, (lhs ?? 0) - (rhs ?? 0))
    }
}

enum LocalTokenUsageCostUnit: String, Equatable, Sendable {
    case usd
    case credits
}
