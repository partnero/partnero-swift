import Testing
@testable import Partnero

@Suite struct ClaimRequestTests {
    @Test func postsTheClaimToTheProgramsEndpoint() async throws {
        let transport = StubTransport()

        let result = try await Client.stub(transport: transport).claim(code: " SAM20 ", appUserId: " user_8f2k ", codeType: .auto)

        #expect(result == ClaimResult(status: .claimed, appUserId: "user_8f2k"))

        let request = try #require(transport.requests.last)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://app.partnero.com/api/pub/v1/mobile/YB9YT4ER/claims")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "partnero-swift/\(Partnero.version)")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(transport.lastBody == [
            "app_user_id": "user_8f2k",
            "code": "SAM20",
            "code_type": "auto",
            "platform": "ios",
            "first_seen_at": "2026-11-17T07:20:00.000Z",
        ])
    }

    @Test func sendsTheCodeType() async throws {
        let transport = StubTransport()

        try await Client.stub(transport: transport).claim(code: "SAM20", appUserId: "user_8f2k", codeType: .promotionCode)

        #expect(transport.lastBody?["code_type"] == "promotion_code")
    }

    @Test func usesTheBaseURLOverride() async throws {
        let transport = StubTransport()
        let client = Client.stub(transport: transport, baseURL: link("https://staging.example.com/"))

        try await client.claim(code: "SAM20", appUserId: "user_8f2k", codeType: .auto)

        #expect(transport.requests.last?.url?.absoluteString == "https://staging.example.com/api/pub/v1/mobile/YB9YT4ER/claims")
    }

    @Test func acceptsAnEmailAsTheAppUserId() async throws {
        let transport = StubTransport()

        try await Client.stub(transport: transport).claim(code: "SAM20", appUserId: "jane@example.com", codeType: .auto)

        #expect(transport.lastBody?["app_user_id"] == "jane@example.com")
    }

    @Test(arguments: [
        ("", "user_8f2k", PartneroError.Field.code),
        ("   ", "user_8f2k", PartneroError.Field.code),
        ("SAM 20", "user_8f2k", PartneroError.Field.code),
        (String(repeating: "A", count: 101), "user_8f2k", PartneroError.Field.code),
        ("SAM20", "", PartneroError.Field.appUserId),
        ("SAM20", "$RCAnonymousID:8c1f2b", PartneroError.Field.appUserId),
        ("SAM20", "user name", PartneroError.Field.appUserId),
        ("SAM20", String(repeating: "a", count: 256), PartneroError.Field.appUserId),
    ])
    func rejectsInvalidInputWithoutARequest(code: String, appUserId: String, field: PartneroError.Field) async {
        let transport = StubTransport()

        await #expect(throws: PartneroError.invalidInput(field: field)) {
            try await Client.stub(transport: transport).claim(code: code, appUserId: appUserId, codeType: .auto)
        }
        #expect(transport.requestCount == 0)
    }

    @Test func rejectsABlankPublicId() async {
        let transport = StubTransport()

        await #expect(throws: PartneroError.invalidInput(field: .programId)) {
            try await Client.stub(transport: transport, programId: "  ").claim(code: "SAM20", appUserId: "user_8f2k", codeType: .auto)
        }
        #expect(transport.requestCount == 0)
    }
}

@Suite struct ClaimResponseTests {
    @Test func reportsAnAlreadyClaimedUser() async throws {
        let result = try await Client.stub(transport: StubTransport(body: StubTransport.alreadyClaimed))
            .claim(code: "SAM20", appUserId: "user_8f2k", codeType: .auto)

        #expect(result.status == .alreadyClaimed)
    }

    @Test(arguments: [
        (400, #"{"status":0,"message":"The code format is invalid.","errors":{"code":["The code format is invalid."]}}"#, PartneroError.invalidInput(field: .code)),
        (400, #"{"status":0,"message":"Invalid","errors":{"app_user_id":["Invalid"]}}"#, PartneroError.invalidInput(field: .appUserId)),
        (400, #"{"status":0,"message":"Invalid"}"#, PartneroError.invalidInput(field: .request)),
        (404, #"{"status":0,"message":"Code not found"}"#, PartneroError.codeNotFound),
        (409, #"{"status":0,"message":"The code matches more than one partner"}"#, PartneroError.codeConflict(message: "The code matches more than one partner")),
        (429, #"{"message":"Too Many Attempts."}"#, PartneroError.rateLimited),
        (500, #"{"status":0,"message":"Failed to claim code"}"#, PartneroError.server(status: 500, message: "Failed to claim code")),
        (502, "<html>Bad gateway</html>", PartneroError.server(status: 502, message: nil)),
        (200, #"{"status":1}"#, PartneroError.server(status: 200, message: "Unexpected response from Partnero.")),
    ])
    func mapsErrorResponses(status: Int, body: String, error: PartneroError) async {
        await #expect(throws: error) {
            try await Client.stub(transport: StubTransport(status: status, body: body))
                .claim(code: "SAM20", appUserId: "user_8f2k", codeType: .auto)
        }
    }

    @Test func reportsTransportFailuresAsNetworkErrors() async {
        await #expect {
            try await Client.stub(transport: StubTransport(error: offline))
                .claim(code: "SAM20", appUserId: "user_8f2k", codeType: .auto)
        } throws: { error in
            if case .network = error as? PartneroError { return true }
            return false
        }
    }

    @Test func reportsCancellationAsCancellation() async {
        await #expect(throws: CancellationError.self) {
            try await Client.stub(transport: StubTransport(error: cancelled))
                .claim(code: "SAM20", appUserId: "user_8f2k", codeType: .auto)
        }
    }
}

@Suite struct FirstSeenTests {
    @Test func isRecordedOnceAndNeverOverwritten() {
        let storage = MemoryStorage()

        _ = Client.stub(storage: storage, clock: clock(1_794_900_000))
        _ = Client.stub(storage: storage, clock: clock(1_800_000_000))

        #expect(storage.string(forKey: Client.firstSeenAtKey) == "2026-11-17T07:20:00.000Z")
    }
}

@Suite struct DeepLinkTests {
    @Test(arguments: [
        ("https://example.com/?ref=SAM20", "SAM20"),
        ("https://example.com/pricing?utm_source=x&REF=SAM20", "SAM20"),
        ("myapp://claim?ref=%20SAM20%20", "SAM20"),
    ])
    func readsTheCode(string: String, code: String) throws {
        #expect(try Client.stub().code(from: link(string)) == code)
    }

    @Test(arguments: ["https://example.com/", "https://example.com/?ref=", "https://example.com/?aff=SAM20"])
    func returnsNilWithoutACode(string: String) throws {
        #expect(try Client.stub().code(from: link(string)) == nil)
    }

    @Test func usesTheProgramsReferralParameter() throws {
        let client = Client.stub(referralParameter: "aff")

        #expect(try client.code(from: link("https://example.com/?aff=SAM20&ref=OTHER")) == "SAM20")
    }

    @Test func claimsTheCodeInALink() async throws {
        let transport = StubTransport()

        let result = try await Client.stub(transport: transport).claim(url: link("https://example.com/?ref=SAM20"), appUserId: "user_8f2k")

        #expect(result?.status == .claimed)
        #expect(transport.lastBody?["code"] == "SAM20")
    }

    @Test func doesNotCallPartneroForALinkWithoutACode() async throws {
        let transport = StubTransport()

        let result = try await Client.stub(transport: transport).claim(url: link("https://example.com/"), appUserId: "user_8f2k")

        #expect(result == nil)
        #expect(transport.requestCount == 0)
    }
}

@Suite struct PublicAPITests {
    @Test func buildsRevenueCatAttributes() {
        #expect(Partnero.revenueCatAttributes(code: " SAM20 ") == ["partnero_code": "SAM20"])
        #expect(Partnero.revenueCatAttributes(code: "  ").isEmpty)
    }
}
