import Foundation

public enum TimingPresentation {
    public static func duration(_ milliseconds: UInt64) -> String {
        let seconds = milliseconds / 1000
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }

    public static func turnLabel(_ timing: TurnTiming, isWaiting: Bool = false) -> String {
        let status: String = switch timing.outcome {
        case "completed": "Completed"
        case "cancelled": "Cancelled"
        case "failed": "Failed"
        case .some(let value): "Outcome: \(value)"
        case nil: isWaiting ? "Waiting for you" : "Working"
        }
        guard let elapsed = timing.elapsedWorkMilliseconds else { return status }
        return "\(status) · Worked for \(duration(elapsed))"
    }

    /// The host reports a single aggregate for the assistant segment. Display it on
    /// the first thinking disclosure, even when that segment has several phases.
    public static func thinkingLabel(at index: Int, in blocks: [AssistantBlock], milliseconds: UInt64?) -> String? {
        guard blocks.indices.contains(index), case .thinking = blocks[index] else { return nil }
        let first = blocks.firstIndex { if case .thinking = $0 { true } else { false } }
        guard first == index, let milliseconds else { return "Thinking" }
        return "Thinking · \(duration(milliseconds))"
    }

    public static func date(_ timestamp: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestamp)
    }
}
