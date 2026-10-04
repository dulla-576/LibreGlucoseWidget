import Foundation

public enum LibreLinkUpError: Error, Equatable, Sendable {
    case invalidConfiguration
    case invalidRegion
    case invalidCredentials
    case termsRequired
    case rateLimited
    case unauthorized
    case noConnections
    case malformedResponse
    case httpStatus(Int)
    case serviceStatus(Int)
    case transportFailure
}

extension LibreLinkUpError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "The LibreLinkUp service configuration is invalid."
        case .invalidRegion: "LibreLinkUp returned an invalid regional service."
        case .invalidCredentials: "LibreLinkUp did not accept the sign-in details."
        case .termsRequired: "Open LibreLinkUp and accept the latest terms, then try again."
        case .rateLimited: "LibreLinkUp is temporarily limiting requests. Try again later."
        case .unauthorized: "The LibreLinkUp session has expired."
        case .noConnections: "No shared LibreLinkUp glucose profile was found."
        case .malformedResponse: "LibreLinkUp returned an unsupported response."
        case let .httpStatus(code): "LibreLinkUp returned HTTP status \(code)."
        case let .serviceStatus(code): "LibreLinkUp returned service status \(code)."
        case .transportFailure: "The LibreLinkUp request could not be completed."
        }
    }
}
