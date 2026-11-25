import Foundation

struct Configuration: Sendable, Equatable {
    static let defaultBaseURL = URL(string: "https://app.partnero.com")!
    static let defaultReferralParameter = "aff"

    let programId: String
    let baseURL: URL
    let referralParameter: String

    init(
        programId: String,
        baseURL: URL = Configuration.defaultBaseURL,
        referralParameter: String = Configuration.defaultReferralParameter
    ) {
        self.programId = programId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = baseURL
        self.referralParameter = referralParameter.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
