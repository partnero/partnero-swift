import Foundation

struct Client: Sendable {
    static let firstSeenAtKey = "com.partnero.first_seen_at"

    /// Mirrors the claim endpoint's validation, so bad input fails without a request.
    static let maxCodeLength = 100
    static let maxAppUserIdLength = 255

    let configuration: Configuration
    let transport: any Transport
    let storage: any KeyValueStorage
    let clock: any Clock
    let platform: String

    init(
        configuration: Configuration,
        transport: any Transport = URLSessionTransport(),
        storage: any KeyValueStorage = UserDefaultsStorage(),
        clock: any Clock = SystemClock(),
        platform: String = Client.currentPlatform
    ) {
        self.configuration = configuration
        self.transport = transport
        self.storage = storage
        self.clock = clock
        self.platform = platform

        recordFirstSeenAt()
    }

    var firstSeenAt: String? {
        storage.string(forKey: Self.firstSeenAtKey)
    }

    @discardableResult
    func claim(code: String, appUserId: String, codeType: CodeType) async throws -> ClaimResult {
        let request = try makeRequest(code: code, appUserId: appUserId, codeType: codeType)

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PartneroError.network(message: error.localizedDescription)
        }

        return try Self.result(from: data, response: response)
    }

    func claim(url: URL, appUserId: String) async throws -> ClaimResult? {
        guard let code = try code(from: url) else {
            return nil
        }

        return try await claim(code: code, appUserId: appUserId, codeType: .auto)
    }

    func code(from url: URL) throws -> String? {
        guard !configuration.referralParameter.isEmpty else {
            throw PartneroError.invalidInput(field: .referralParameter)
        }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = items.first { $0.name.caseInsensitiveCompare(configuration.referralParameter) == .orderedSame }?.value
        let code = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return code.isEmpty ? nil : code
    }

    func makeRequest(code: String, appUserId: String, codeType: CodeType) throws -> URLRequest {
        let programId = configuration.programId
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let appUserId = appUserId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !programId.isEmpty, programId.allSatisfy(Self.isIdentifierCharacter) else {
            throw PartneroError.invalidInput(field: .programId)
        }
        guard !code.isEmpty, code.count <= Self.maxCodeLength, code.allSatisfy(Self.isIdentifierCharacter) else {
            throw PartneroError.invalidInput(field: .code)
        }
        guard Self.isValidAppUserId(appUserId) else {
            throw PartneroError.invalidInput(field: .appUserId)
        }

        var body: [String: String] = [
            "app_user_id": appUserId,
            "code": code,
            "code_type": codeType.rawValue,
            "platform": platform,
        ]
        body["first_seen_at"] = firstSeenAt

        var request = URLRequest(url: endpoint(programId: programId), timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("partnero-swift/\(Partnero.version)", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        return request
    }

    private func endpoint(programId: String) -> URL {
        configuration.baseURL
            .appendingPathComponent("api/pub/v1/mobile")
            .appendingPathComponent(programId)
            .appendingPathComponent("claims")
    }

    private func recordFirstSeenAt() {
        guard firstSeenAt == nil else {
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        storage.set(formatter.string(from: clock.now()), forKey: Self.firstSeenAtKey)
    }

    static func result(from data: Data, response: HTTPURLResponse) throws -> ClaimResult {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let message = json?["message"] as? String

        switch response.statusCode {
        case 200..<300:
            guard
                let payload = json?["data"] as? [String: Any],
                let status = (payload["status"] as? String).flatMap(ClaimResult.Status.init(rawValue:)),
                let appUserId = payload["app_user_id"] as? String
            else {
                throw PartneroError.server(status: response.statusCode, message: "Unexpected response from Partnero.")
            }

            return ClaimResult(status: status, appUserId: appUserId)
        case 400, 422:
            let serverField = (json?["errors"] as? [String: Any])?.keys.sorted().first
            throw PartneroError.invalidInput(field: serverField.flatMap(PartneroError.Field.init(serverName:)) ?? .request)
        case 404:
            throw PartneroError.codeNotFound
        case 409:
            throw PartneroError.codeConflict(message: message ?? "The code matches more than one partner.")
        case 429:
            throw PartneroError.rateLimited
        default:
            throw PartneroError.server(status: response.statusCode, message: message)
        }
    }

    static func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber || character == "-" || character == "_" || character == ".")
    }

    /// Partnero customer keys are an email address, or letters, numbers, `-`, `_` and `.`.
    static func isValidAppUserId(_ value: String) -> Bool {
        guard !value.isEmpty, value.utf8.count <= maxAppUserIdLength else {
            return false
        }

        if value.allSatisfy(isIdentifierCharacter) {
            return true
        }

        let parts = value.split(separator: "@", omittingEmptySubsequences: false)

        return parts.count == 2
            && !parts[0].isEmpty
            && parts[1].contains(".")
            && !value.contains(where: { $0.isWhitespace || "{}()<>".contains($0) })
    }

    static var currentPlatform: String {
        #if os(iOS) || os(visionOS)
        return "ios"
        #else
        return "other"
        #endif
    }
}
