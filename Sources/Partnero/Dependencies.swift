import Foundation

protocol Transport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

protocol KeyValueStorage: Sendable {
    func string(forKey key: String) -> String?
    func set(_ value: String, forKey key: String)
}

protocol Clock: Sendable {
    func now() -> Date
}

struct URLSessionTransport: Transport {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return (data, response)
    }
}

/// `UserDefaults` is documented as thread-safe.
struct UserDefaultsStorage: KeyValueStorage, @unchecked Sendable {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func set(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}

struct SystemClock: Clock {
    func now() -> Date {
        Date()
    }
}
