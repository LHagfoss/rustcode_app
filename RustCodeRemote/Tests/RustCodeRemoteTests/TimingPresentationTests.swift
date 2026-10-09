import Foundation
import Testing
@testable import RustCodeRemote

@Suite struct TimingPresentationTests {
    @Test func usesOnlyAuthoritativeWorkTimeAndPreservesUnknownOutcomes() {
        #expect(TimingPresentation.turnLabel(TurnTiming(turnID: "t", elapsedWorkMilliseconds: 32000, outcome: "failed")) == "Failed · Worked for 32s")
        #expect(TimingPresentation.turnLabel(TurnTiming(turnID: "t", outcome: "future")) == "Outcome: future")
        #expect(TimingPresentation.turnLabel(TurnTiming(turnID: "t", startedAt: "2026-10-09T18:41:00+02:00")) == "Working")
        #expect(TimingPresentation.duration(61000) == "1m 1s")
        #expect(TimingPresentation.duration(0) == "0s")
    }

    @Test func thinkingAggregateAppearsOnceAcrossMultipleThinkingBlocks() {
        let blocks = AssistantBlock.parse("<think>Plan</think>Answer<think>Check</think>Done")
        let labels = blocks.indices.map { TimingPresentation.thinkingLabel(at: $0, in: blocks, milliseconds: 4000) }
        #expect(labels == ["Thinking · 4s", nil, "Thinking", nil])
    }

    @Test func parsesCompletionTimestampsWithOffsetsAndFractions() throws {
        let offset = try #require(TimingPresentation.date("2026-10-09T18:40:32+02:00"))
        let utc = try #require(TimingPresentation.date("2026-10-09T16:40:32Z"))
        #expect(offset == utc)
        #expect(TimingPresentation.date("2026-10-09T16:40:32.123Z") != nil)
        #expect(TimingPresentation.date("future-format") == nil)
    }
}
