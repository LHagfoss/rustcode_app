import Foundation
import Testing
@testable import RustCodeRemote

@Suite struct MobileSessionTests {
    @Test func catalogKeepsInsertionAndFutureActionWithoutGuessingSupport() throws {
        let raw = #"{"name":"/future","description":"Host-only command","insertion":"/future ","action":"future_action"}"#
        let choice = try JSONDecoder().decode(SessionCommandChoice.self, from: Data(raw.utf8))
        #expect(choice.insertion == "/future ")
        #expect(choice.action == "future_action")
    }

    @Test func gatewayOperationsDoNotTargetAnExistingSession() throws {
        for command in [RemoteCommand.listDirectories(path: nil), .createSession(path: "/Users/me/Project with spaces")] {
            let raw = try WireCodec().encode(command, requestID: RequestID("new-session"))
            let request = try JSONDecoder().decode(WireRequest.self, from: Data(raw.utf8))
            #expect(request.sessionID == nil)
            #expect(request.registrationEpoch == nil)
            if case .createSession(let path) = request.operation { #expect(path.path == "/Users/me/Project with spaces") }
        }
    }

    @Test func directoryResponsePreservesCanonicalPathAndTruncation() throws {
        let json = #"{"kind":"response","protocol_version":1,"request_id":"d","result":{"type":"directories","path":"/Users/me","parent":"/Users","directories":[{"name":"My Project","path":"/Users/me/My Project"}],"truncated":true}}"#
        let decoded = try WireCodec().decode(json)
        guard case .reply(_, .directories(let listing)) = decoded else { Issue.record("Missing directories"); return }
        #expect(listing.path == "/Users/me")
        #expect(listing.directories.first?.name == "My Project")
        #expect(listing.truncated)
    }

    @Test func demoCreationIsIdempotentAndSurvivesDisconnect() async throws {
        let client = DemoRemoteClient()
        let credential = try await client.pair(.scanned("demo"), deviceName: "test")
        try await client.connect(using: credential)
        let listing = try await client.browseDirectories(path: nil)
        let id = RequestID("create-once")
        let created = try await client.createSession(directory: listing.directories[0].path, requestID: id)
        await client.disconnect()
        try await client.connect(using: credential)
        let again = try await client.createSession(directory: listing.path, requestID: id)
        #expect(again == created)
        #expect(again.workspace == "/Users/demo/Projects")
        let attached = try await client.attach(created.ref, resumeAfter: nil)
        guard case .snapshot(let snapshot) = attached.start else { Issue.record("Missing persisted demo session"); return }
        #expect(snapshot.session == created.ref)
        #expect(created.turnCount == 0)
        await client.disconnect()
    }
}

@Suite struct MobileToolIdentityTests {
    @Test func lateToolStartAndResultUpsertOneNamedRowAndRetainDistinctCalls() {
        let session = SessionRef(sessionID: "tools", registrationEpoch: 1)
        var snapshot = SessionSnapshot(session: session)
        let first = TranscriptItem(id: "tool:call-1", .tool(ToolCall(name: "run_command", summary: "pwd", status: .running)))
        _ = snapshot.apply(.init(session: session, sequence: 1, event: .itemAppended(first)))
        _ = snapshot.apply(.init(session: session, sequence: 2, event: .toolFinished(itemID: first.id, succeeded: true, isPending: false, output: "same output", isOutputTruncated: false)))
        // A repeated named start repairs a missing live start after late attachment.
        let second = TranscriptItem(id: "tool:call-2", .tool(ToolCall(name: "run_command", summary: "pwd", status: .running)))
        _ = snapshot.apply(.init(session: session, sequence: 3, event: .itemAppended(second)))
        _ = snapshot.apply(.init(session: session, sequence: 4, event: .itemAppended(second)))
        _ = snapshot.apply(.init(session: session, sequence: 5, event: .toolFinished(itemID: second.id, succeeded: true, isPending: false, output: "same output", isOutputTruncated: false)))
        #expect(snapshot.items.count == 2)
        for item in snapshot.items {
            guard case .tool(let tool) = item.content else { Issue.record("Missing tool"); continue }
            #expect(tool.name == "run_command")
            #expect(tool.output == "same output")
        }
    }
}
