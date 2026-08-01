import Foundation

public enum MacXbarError: Error, LocalizedError {
    case moduleNotFound(ModuleID)
    case moduleAlreadyRegistered(ModuleID)
    case invalidConfiguration(String)
    case executionFailed(String)
    case parsingFailed(String)
    case cacheMiss(String)
    case storageError(String)
    case networkError(String)
    case permissionDenied(String)
    case internalError(String)

    public var errorDescription: String? {
        switch self {
        case .moduleNotFound(let id):
            return "Module not found: \(id)"
        case .moduleAlreadyRegistered(let id):
            return "Module already registered: \(id)"
        case .invalidConfiguration(let msg):
            return "Invalid configuration: \(msg)"
        case .executionFailed(let msg):
            return "Execution failed: \(msg)"
        case .parsingFailed(let msg):
            return "Parsing failed: \(msg)"
        case .cacheMiss(let key):
            return "Cache miss for key: \(key)"
        case .storageError(let msg):
            return "Storage error: \(msg)"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .permissionDenied(let msg):
            return "Permission denied: \(msg)"
        case .internalError(let msg):
            return "Internal error: \(msg)"
        }
    }
}