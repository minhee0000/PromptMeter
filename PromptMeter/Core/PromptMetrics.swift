import Foundation

enum MeterStatus: String, Equatable, Sendable {
    case idle
    case healthy
    case warming
    case warning
    case critical
    case overflow

    static func make(tokens: Int, ratio: Double) -> MeterStatus {
        guard tokens > 0 else { return .idle }

        switch ratio {
        case 1...:
            return .overflow
        case 0.85..<1:
            return .critical
        case 0.65..<0.85:
            return .warning
        case 0.35..<0.65:
            return .warming
        default:
            return .healthy
        }
    }

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .healthy:
            return "Healthy"
        case .warming:
            return "Warming"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        case .overflow:
            return "Overflow"
        }
    }
}

struct PromptMetrics: Equatable, Sendable {
    let characterCount: Int
    let wordCount: Int
    let lineCount: Int
    let estimatedTokens: Int
    let contextLimit: Int
    let usageRatio: Double
    let remainingTokens: Int
    let status: MeterStatus

    init(text: String, contextLimit: Int) {
        let safeContextLimit = max(contextLimit, 1)
        let estimatedTokens = Self.estimateTokens(in: text)
        let usageRatio = Double(estimatedTokens) / Double(safeContextLimit)

        characterCount = text.count
        wordCount = Self.countWords(in: text)
        lineCount = text.isEmpty ? 0 : text.components(separatedBy: .newlines).count
        self.estimatedTokens = estimatedTokens
        self.contextLimit = safeContextLimit
        self.usageRatio = usageRatio
        remainingTokens = max(safeContextLimit - estimatedTokens, 0)
        status = MeterStatus.make(tokens: estimatedTokens, ratio: usageRatio)
    }

    static func estimateTokens(in text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        var score = 0.0
        for scalar in trimmed.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                score += 0.25
            } else if isDenseLanguageScalar(scalar) {
                score += 1.0
            } else if scalar.value < 128 {
                score += 0.25
            } else {
                score += 0.5
            }
        }

        return max(1, Int(score.rounded(.up)))
    }

    static func countWords(in text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return trimmed.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    static func compactCount(_ value: Int) -> String {
        switch value {
        case 1_000_000...:
            return String(format: "%.1fM", Double(value) / 1_000_000)
        case 10_000...:
            return String(format: "%.0fK", Double(value) / 1_000)
        case 1_000...:
            return String(format: "%.1fK", Double(value) / 1_000)
        default:
            return "\(value)"
        }
    }

    private static func isDenseLanguageScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30FF,
             0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xAC00...0xD7AF:
            return true
        default:
            return false
        }
    }
}
