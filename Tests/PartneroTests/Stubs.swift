import Foundation
@testable import Partnero

final class StubTransport: Transport, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [Result<(Int, String), Error>]
    private(set) var requests: [URLRequest] = []

    init(status: Int = 200, body: String = StubTransport.claimed) {
        responses = [.success((status, body))]
    }

    init(error: Error) {
        responses = [.failure(error)]
    }

    static let claimed = #"{"status":1,"data":{"status":"claimed","app_user_id":"user_8f2k"}}"#
    static let alreadyClaimed = #"{"status":1,"data":{"status":"already_claimed","app_user_id":"user_8f2k"}}"#

    var lastBody: [String: String]? {
        lock.lock()
        defer { lock.unlock() }

        guard let data = requests.last?.httpBody else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data) as? [String: String]
    }

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return requests.count
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let next: Result<(Int, String), Error> = {
            lock.lock()
            defer { lock.unlock() }

            requests.append(request)

            return responses.count > 1 ? responses.removeFirst() : responses[0]
        }()

        let (status, body) = try next.get()

        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

final class MemoryStorage: KeyValueStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func string(forKey key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        return values[key]
    }

    func set(_ value: String, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }

        values[key] = value
    }
}

struct FixedClock: Clock {
    let date: Date

    func now() -> Date {
        date
    }
}

/// Foundation helpers for the test files, which import `Testing` and so leave Foundation out:
/// the Command Line Tools ship `_Testing_Foundation` without its module, which breaks importing both.
func link(_ string: String) -> URL {
    URL(string: string)!
}

func clock(_ secondsSince1970: TimeInterval) -> FixedClock {
    FixedClock(date: Date(timeIntervalSince1970: secondsSince1970))
}

let offline: Error = URLError(.notConnectedToInternet)
let cancelled: Error = URLError(.cancelled)

extension Client {
    static func stub(
        transport: StubTransport = StubTransport(),
        storage: MemoryStorage = MemoryStorage(),
        clock: FixedClock = FixedClock(date: Date(timeIntervalSince1970: 1_794_900_000)),
        programId: String = "YB9YT4ER",
        baseURL: URL = Configuration.defaultBaseURL,
        referralParameter: String = "ref"
    ) -> Client {
        Client(
            configuration: Configuration(programId: programId, baseURL: baseURL, referralParameter: referralParameter),
            transport: transport,
            storage: storage,
            clock: clock,
            platform: "ios"
        )
    }
}
