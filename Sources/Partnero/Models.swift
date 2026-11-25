import Foundation

/// What a code is matched against. `auto` tries partner link keys and promotion codes.
public enum CodeType: String, Sendable, CaseIterable {
    case auto
    case link
    case promotionCode = "promotion_code"
}

public struct ClaimResult: Sendable, Equatable {
    public enum Status: String, Sendable {
        /// The user is now attributed to the code's partner.
        case claimed
        /// The user was already attributed, possibly to a different partner. Nothing changed.
        case alreadyClaimed = "already_claimed"
    }

    public let status: Status
    public let appUserId: String

    public init(status: Status, appUserId: String) {
        self.status = status
        self.appUserId = appUserId
    }
}

public enum PartneroError: Error, Sendable, Equatable {
    public enum Field: String, Sendable {
        case programId
        case referralParameter
        case code
        case clickId
        case appUserId
        case codeType
        case firstSeenAt
        case platform
        /// Partnero rejected the request without naming a field.
        case request

        init?(serverName: String) {
            switch serverName {
            case "app_user_id": self = .appUserId
            case "code": self = .code
            case "click_id": self = .clickId
            case "code_type": self = .codeType
            case "first_seen_at": self = .firstSeenAt
            case "platform": self = .platform
            default: return nil
            }
        }
    }

    /// `Partnero.configure` has not been called.
    case notConfigured
    /// A value was blank or malformed. Checked before any request, and again by Partnero.
    case invalidInput(field: Field)
    /// No active code or click matches, or mobile claims are turned off for the program.
    case codeNotFound
    /// The code matches more than one partner (pass a `CodeType`), or the program's claim window has closed.
    case codeConflict(message: String)
    /// Too many claims from this network for the program. Try again in a minute.
    case rateLimited
    /// The request did not reach Partnero or no response came back.
    case network(message: String)
    case server(status: Int, message: String?)
}

extension PartneroError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Partnero.configure(programId:) must be called before claiming a code."
        case .invalidInput(let field):
            return "The \(field.rawValue) is blank or not valid."
        case .codeNotFound:
            return "The referral code was not found."
        case .codeConflict(let message):
            return message
        case .rateLimited:
            return "Too many referral claims. Try again in a minute."
        case .network(let message):
            return message
        case .server(let status, let message):
            return message ?? "Partnero responded with HTTP \(status)."
        }
    }
}
