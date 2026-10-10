import Foundation
import Testing
@testable import RustCodeRemote

@Suite struct MobileSessionTests {
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
