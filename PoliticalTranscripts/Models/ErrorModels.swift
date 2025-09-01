import Foundation

// MARK: - API Error Types
enum APIError: Error, LocalizedError, Identifiable {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case serverError(Int, String?)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case unauthorized
    case notFound
    case badRequest(String?)
    case forbidden
    case timeout
    case offline
    case unknown(Error)
    
    var id: String {
        switch self {
        case .invalidURL: return "invalid_url"
        case .noData: return "no_data"
        case .decodingError: return "decoding_error"
        case .networkError: return "network_error"
        case .serverError: return "server_error"
        case .rateLimitExceeded: return "rate_limit_exceeded"
        case .unauthorized: return "unauthorized"
        case .notFound: return "not_found"
        case .badRequest: return "bad_request"
        case .forbidden: return "forbidden"
        case .timeout: return "timeout"
        case .offline: return "offline"
        case .unknown: return "unknown"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .noData:
            return "No data received from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            if let message = message {
                return "Server error (\(code)): \(message)"
            }
            return "Server error with code: \(code)"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "API rate limit exceeded. Please try again in \(Int(retryAfter)) seconds."
            }
            return "API rate limit exceeded. Please try again later."
        case .unauthorized:
            return "Unauthorized access. Please check your credentials."
        case .notFound:
            return "Requested resource not found"
        case .badRequest(let message):
            return message ?? "Invalid request"
        case .forbidden:
            return "Access forbidden. You don't have permission to access this resource."
        case .timeout:
            return "Request timed out. Please check your connection and try again."
        case .offline:
            return "No internet connection. Please check your network settings."
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError, .timeout, .offline:
            return "Check your internet connection and try again."
        case .rateLimitExceeded:
            return "Wait a moment before making another request."
        case .unauthorized:
            return "Please log in again or check your account settings."
        case .serverError:
            return "The server is experiencing issues. Please try again later."
        case .notFound:
            return "The content you're looking for may have been moved or deleted."
        case .forbidden:
            return "Contact support if you believe you should have access to this content."
        default:
            return "Please try again. If the problem persists, contact support."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .timeout, .serverError, .rateLimitExceeded, .offline:
            return true
        case .unauthorized, .forbidden, .notFound, .badRequest, .invalidURL, .decodingError:
            return false
        case .noData, .unknown:
            return true
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .offline, .networkError, .timeout, .rateLimitExceeded:
            return .warning
        case .serverError, .unknown:
            return .error
        case .unauthorized, .forbidden:
            return .critical
        case .notFound, .badRequest, .noData:
            return .info
        case .invalidURL, .decodingError:
            return .error
        }
    }
}

// MARK: - Core Data Error Types
enum CoreDataError: Error, LocalizedError, Identifiable {
    case saveError(Error)
    case fetchError(Error)
    case deleteError(Error)
    case contextNotAvailable
    case modelMismatch
    case migrationFailed(Error)
    case concurrencyViolation
    case diskSpaceFull
    
    var id: String {
        switch self {
        case .saveError: return "save_error"
        case .fetchError: return "fetch_error"
        case .deleteError: return "delete_error"
        case .contextNotAvailable: return "context_not_available"
        case .modelMismatch: return "model_mismatch"
        case .migrationFailed: return "migration_failed"
        case .concurrencyViolation: return "concurrency_violation"
        case .diskSpaceFull: return "disk_space_full"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .saveError(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchError(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .deleteError(let error):
            return "Failed to delete data: \(error.localizedDescription)"
        case .contextNotAvailable:
            return "Database context not available"
        case .modelMismatch:
            return "Database model mismatch. App update may be required."
        case .migrationFailed(let error):
            return "Database migration failed: \(error.localizedDescription)"
        case .concurrencyViolation:
            return "Database concurrency violation detected"
        case .diskSpaceFull:
            return "Device storage is full. Please free up space and try again."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .saveError, .deleteError:
            return "Try again. If the problem persists, restart the app."
        case .fetchError:
            return "Refresh the view or restart the app."
        case .contextNotAvailable, .concurrencyViolation:
            return "Restart the app to resolve this issue."
        case .modelMismatch, .migrationFailed:
            return "Update the app to the latest version."
        case .diskSpaceFull:
            return "Free up device storage by deleting unused files or apps."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .fetchError, .saveError, .deleteError:
            return .warning
        case .contextNotAvailable, .concurrencyViolation:
            return .error
        case .modelMismatch, .migrationFailed:
            return .critical
        case .diskSpaceFull:
            return .warning
        }
    }
}

// MARK: - Video Player Error Types
enum VideoPlayerError: Error, LocalizedError, Identifiable {
    case invalidURL
    case loadingFailed(Error)
    case playbackFailed(Error)
    case seekFailed
    case unsupportedFormat
    case networkUnavailable
    case insufficientBuffer
    case audioSessionFailed
    case permissionDenied
    
    var id: String {
        switch self {
        case .invalidURL: return "invalid_video_url"
        case .loadingFailed: return "video_loading_failed"
        case .playbackFailed: return "video_playback_failed"
        case .seekFailed: return "video_seek_failed"
        case .unsupportedFormat: return "unsupported_format"
        case .networkUnavailable: return "video_network_unavailable"
        case .insufficientBuffer: return "insufficient_buffer"
        case .audioSessionFailed: return "audio_session_failed"
        case .permissionDenied: return "permission_denied"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid video URL"
        case .loadingFailed(let error):
            return "Failed to load video: \(error.localizedDescription)"
        case .playbackFailed(let error):
            return "Video playback failed: \(error.localizedDescription)"
        case .seekFailed:
            return "Failed to seek to position in video"
        case .unsupportedFormat:
            return "Video format not supported"
        case .networkUnavailable:
            return "Network connection required for video playback"
        case .insufficientBuffer:
            return "Video buffering. Please wait or check your connection."
        case .audioSessionFailed:
            return "Audio session configuration failed"
        case .permissionDenied:
            return "Permission denied for media access"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidURL, .unsupportedFormat:
            return "Try a different video or contact support."
        case .loadingFailed, .playbackFailed:
            return "Check your internet connection and try again."
        case .seekFailed:
            return "Wait for the video to load completely before seeking."
        case .networkUnavailable, .insufficientBuffer:
            return "Check your internet connection and try again."
        case .audioSessionFailed:
            return "Check your device's audio settings and try again."
        case .permissionDenied:
            return "Grant media access permission in Settings."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .insufficientBuffer, .networkUnavailable:
            return .warning
        case .loadingFailed, .playbackFailed, .seekFailed:
            return .error
        case .invalidURL, .unsupportedFormat, .audioSessionFailed, .permissionDenied:
            return .critical
        }
    }
}

// MARK: - Search Error Types
enum SearchError: Error, LocalizedError, Identifiable {
    case emptyQuery
    case invalidFilters
    case noResults
    case searchTimeout
    case historyUnavailable
    
    var id: String {
        switch self {
        case .emptyQuery: return "empty_query"
        case .invalidFilters: return "invalid_filters"
        case .noResults: return "no_results"
        case .searchTimeout: return "search_timeout"
        case .historyUnavailable: return "history_unavailable"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Please enter a search term"
        case .invalidFilters:
            return "Invalid search filters applied"
        case .noResults:
            return "No results found for your search"
        case .searchTimeout:
            return "Search request timed out"
        case .historyUnavailable:
            return "Search history is not available"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyQuery:
            return "Enter a search term to find political transcripts."
        case .invalidFilters:
            return "Check your search filters and try again."
        case .noResults:
            return "Try different search terms or adjust your filters."
        case .searchTimeout:
            return "Check your connection and try searching again."
        case .historyUnavailable:
            return "Search history will be available after making searches."
        }
    }
    
    var severity: ErrorSeverity {
        .info
    }
}

// MARK: - Error Severity
enum ErrorSeverity {
    case info      // Informational, no action needed
    case warning   // Warning, user should be aware
    case error     // Error, but recoverable
    case critical  // Critical error, may require restart
    
    var color: String {
        switch self {
        case .info: return "blue"
        case .warning: return "orange"
        case .error: return "red"
        case .critical: return "purple"
        }
    }
    
    var systemImage: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
}

// MARK: - Error Handler Protocol
protocol ErrorHandling {
    func handle(_ error: Error)
    func canRecover(from error: Error) -> Bool
    func retryOperation() async throws
}

// MARK: - User Facing Error
struct UserFacingError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: ErrorSeverity
    let actionTitle: String?
    let action: (() -> Void)?
    let isRetryable: Bool
    
    init(from error: Error) {
        self.severity = Self.severity(for: error)
        self.title = Self.title(for: error)
        self.message = error.localizedDescription
        self.isRetryable = Self.isRetryable(error)
        
        if isRetryable {
            self.actionTitle = "Retry"
            self.action = { /* Will be set by the calling context */ }
        } else {
            self.actionTitle = "OK"
            self.action = nil
        }
    }
    
    private static func severity(for error: Error) -> ErrorSeverity {
        if let apiError = error as? APIError {
            return apiError.severity
        } else if let coreDataError = error as? CoreDataError {
            return coreDataError.severity
        } else if let videoError = error as? VideoPlayerError {
            return videoError.severity
        } else if let searchError = error as? SearchError {
            return searchError.severity
        }
        return .error
    }
    
    private static func title(for error: Error) -> String {
        switch error {
        case is APIError:
            return "Network Error"
        case is CoreDataError:
            return "Data Error"
        case is VideoPlayerError:
            return "Video Error"
        case is SearchError:
            return "Search Error"
        default:
            return "Error"
        }
    }
    
    private static func isRetryable(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            return apiError.isRetryable
        }
        return false
    }
}
