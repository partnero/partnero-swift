import Foundation

/// Claims Partnero referral codes from a mobile app.
///
/// Only the program's Program ID is used. Never put your Partnero API key in an app.
public enum Partnero {
    public static let version = "0.1.0"

    private static let shared = SharedClient()

    /// Call once at launch, before any claim. Records the first launch date the first time it runs.
    ///
    /// - Parameters:
    ///   - programId: The program's Program ID, shown on its Integration page in Partnero.
    ///   - baseURL: Overrides `https://app.partnero.com`, for example for staging.
    ///   - referralParameter: The query parameter that holds the code in your referral links, such as `aff`.
    public static func configure(programId: String, baseURL: URL? = nil, referralParameter: String = "ref") {
        shared.set(Client(configuration: Configuration(
            programId: programId,
            baseURL: baseURL ?? Configuration.defaultBaseURL,
            referralParameter: referralParameter
        )))
    }

    /// Attributes `appUserId` to the partner who owns `code`, a partner's referral link key or promotion code.
    ///
    /// Use the same ID your purchases are reported under, such as `Purchases.shared.appUserID`
    /// once the user is identified. Anonymous RevenueCat IDs are rejected, because they change on reinstall.
    ///
    /// Throws `PartneroError`, or `CancellationError` if the task is cancelled.
    @discardableResult
    public static func claim(code: String, appUserId: String, codeType: CodeType = .auto) async throws -> ClaimResult {
        try await client().claim(code: code, appUserId: appUserId, codeType: codeType)
    }

    /// Claims the code in a referral or deep link. Returns `nil` when the link has no code.
    @discardableResult
    public static func claim(url: URL, appUserId: String) async throws -> ClaimResult? {
        try await client().claim(url: url, appUserId: appUserId)
    }

    /// The code in a referral or deep link, or `nil` when it has none.
    public static func code(from url: URL) throws -> String? {
        try client().code(from: url)
    }

    /// Subscriber attributes for RevenueCat, so a purchase is still attributed if the claim never reached Partnero.
    ///
    /// ```swift
    /// Purchases.shared.attribution.setAttributes(Partnero.revenueCatAttributes(code: code))
    /// ```
    public static func revenueCatAttributes(code: String) -> [String: String] {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)

        return code.isEmpty ? [:] : ["partnero_code": code]
    }

    private static func client() throws -> Client {
        guard let client = shared.get() else {
            throw PartneroError.notConfigured
        }

        return client
    }
}

private final class SharedClient: @unchecked Sendable {
    private let lock = NSLock()
    private var client: Client?

    func get() -> Client? {
        lock.lock()
        defer { lock.unlock() }

        return client
    }

    func set(_ client: Client) {
        lock.lock()
        defer { lock.unlock() }

        self.client = client
    }
}
