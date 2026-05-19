enum LocalTokenUsagePricing {
    struct Estimate: Sendable {
        let amount: Double
        let unit: LocalTokenUsageCostUnit
    }

    struct Rate: Sendable {
        let inputPerMillion: Double
        let cachedInputPerMillion: Double
        let cacheCreationPerMillion: Double
        let outputPerMillion: Double
        let cachedInputIsIncludedInInput: Bool
        let unit: LocalTokenUsageCostUnit
    }

    static func estimatedCost(
        provider: ProviderIconKind,
        modelName: String?,
        inputTokens: Int,
        cacheReadTokens: Int,
        cacheCreationTokens: Int,
        outputTokens: Int
    ) -> Estimate? {
        guard let rate = rate(provider: provider, modelName: modelName) else { return nil }
        let billableInput = rate.cachedInputIsIncludedInInput
            ? max(0, inputTokens - cacheReadTokens)
            : inputTokens

        let amount = cost(tokens: billableInput, rate: rate.inputPerMillion)
            + cost(tokens: cacheReadTokens, rate: rate.cachedInputPerMillion)
            + cost(tokens: cacheCreationTokens, rate: rate.cacheCreationPerMillion)
            + cost(tokens: outputTokens, rate: rate.outputPerMillion)
        return Estimate(amount: amount, unit: rate.unit)
    }

    private static func rate(provider: ProviderIconKind, modelName: String?) -> Rate? {
        let normalized = (modelName ?? "").lowercased()
        switch provider {
        case .codex:
            return codexRate(modelName: normalized)
        case .claude:
            return claudeRate(modelName: normalized)
        case .gemini:
            return nil
        }
    }

    private static func codexRate(modelName: String) -> Rate {
        if modelName.contains("5.5-pro") {
            return Rate(
                inputPerMillion: 30.00,
                cachedInputPerMillion: 30.00,
                cacheCreationPerMillion: 0,
                outputPerMillion: 180.00,
                cachedInputIsIncludedInInput: true,
                unit: .usd
            )
        }

        if modelName.isEmpty || modelName.contains("5.5") {
            return Rate(
                inputPerMillion: 5.00,
                cachedInputPerMillion: 0.50,
                cacheCreationPerMillion: 0,
                outputPerMillion: 30.00,
                cachedInputIsIncludedInInput: true,
                unit: .usd
            )
        }

        if modelName.contains("5.4-pro") {
            return Rate(
                inputPerMillion: 30.00,
                cachedInputPerMillion: 30.00,
                cacheCreationPerMillion: 0,
                outputPerMillion: 180.00,
                cachedInputIsIncludedInInput: true,
                unit: .usd
            )
        }

        if modelName.contains("5.4-nano") || modelName.contains("nano") {
            return Rate(
                inputPerMillion: 0.20,
                cachedInputPerMillion: 0.02,
                cacheCreationPerMillion: 0,
                outputPerMillion: 1.25,
                cachedInputIsIncludedInInput: true,
                unit: .usd
            )
        }

        if modelName.contains("5.4-mini") || modelName.contains("mini") {
            return Rate(
                inputPerMillion: 0.75,
                cachedInputPerMillion: 0.075,
                cacheCreationPerMillion: 0,
                outputPerMillion: 4.50,
                cachedInputIsIncludedInInput: true,
                unit: .usd
            )
        }

        if modelName.contains("5.4") {
            return Rate(
                inputPerMillion: 2.50,
                cachedInputPerMillion: 0.25,
                cacheCreationPerMillion: 0,
                outputPerMillion: 15.00,
                cachedInputIsIncludedInInput: true,
                unit: .usd
            )
        }

        if modelName.contains("5.3") || modelName.contains("5.2") {
            return Rate(
                inputPerMillion: 1.75,
                cachedInputPerMillion: 0.175,
                cacheCreationPerMillion: 0,
                outputPerMillion: 14.00,
                cachedInputIsIncludedInInput: true,
                unit: .usd
            )
        }

        return Rate(
            inputPerMillion: 1.25,
            cachedInputPerMillion: 0.125,
            cacheCreationPerMillion: 0,
            outputPerMillion: 10.00,
            cachedInputIsIncludedInInput: true,
            unit: .usd
        )
    }

    private static func claudeRate(modelName: String) -> Rate {
        if modelName.contains("opus") {
            return Rate(
                inputPerMillion: 15.00,
                cachedInputPerMillion: 1.50,
                cacheCreationPerMillion: 18.75,
                outputPerMillion: 75.00,
                cachedInputIsIncludedInInput: false,
                unit: .usd
            )
        }

        if modelName.contains("haiku") {
            return Rate(
                inputPerMillion: 1.00,
                cachedInputPerMillion: 0.10,
                cacheCreationPerMillion: 1.25,
                outputPerMillion: 5.00,
                cachedInputIsIncludedInInput: false,
                unit: .usd
            )
        }

        return Rate(
            inputPerMillion: 3.00,
            cachedInputPerMillion: 0.30,
            cacheCreationPerMillion: 3.75,
            outputPerMillion: 15.00,
            cachedInputIsIncludedInInput: false,
            unit: .usd
        )
    }

    private static func cost(tokens: Int, rate: Double) -> Double {
        guard tokens > 0, rate > 0 else { return 0 }
        return Double(tokens) / 1_000_000 * rate
    }
}
