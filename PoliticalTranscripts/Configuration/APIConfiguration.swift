import Foundation
import UIKit

// MARK: - API Configuration
struct APIConfiguration {
    static let shared = APIConfiguration()
    
    private let environment = EnvironmentManager.shared
    
    private init() {}
    
    // MARK: - Base Configuration
    var baseURL: URL {
        guard let url = URL(string: environment.apiBaseURL) else {
            fatalError("Invalid API base URL: \(environment.apiBaseURL)")
        }
        return url
    }
    
    var apiVersion: String {
        return environment.apiVersion
    }
    
    var apiKey: String? {
        return environment.apiKey
    }
    
    // MARK: - Endpoint Construction
    func url(for endpoint: APIEndpoint) -> URL {
        return baseURL
            .appendingPathComponent(apiVersion)
            .appendingPathComponent(endpoint.path)
    }
    
    // MARK: - Request Configuration
    var defaultHeaders: [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": userAgent
        ]
        
        if let apiKey = apiKey {
            headers["Authorization"] = "Bearer \(apiKey)"
        }
        
        return headers
    }
    
    private var userAgent: String {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "PoliticalTranscripts"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let systemVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        
        return "\(appName)/\(appVersion).\(buildNumber) (iOS \(systemVersion); \(deviceModel))"
    }
    
    // MARK: - Rate Limiting Configuration
    var rateLimitConfiguration: RateLimitConfiguration {
        return RateLimitConfiguration(
            maxRequestsPerMinute: 100,
            maxRequestsPerTenMinutes: 10,
            maxRequestsPerFiveMinutes: 5
        )
    }
    
    // MARK: - Timeout Configuration
    var timeoutConfiguration: TimeoutConfiguration {
        return TimeoutConfiguration(
            requestTimeout: environment.requestTimeoutInterval,
            resourceTimeout: environment.requestTimeoutInterval * 2
        )
    }
}

// MARK: - API Endpoints
enum APIEndpoint {
    case searchVideos(query: String, filters: SearchFilterModel?, page: Int, limit: Int)
    case getVideo(id: String)
    case getVideoTranscript(id: String)
    case getPlaylists
    case createPlaylist(PlaylistModel)
    case updatePlaylist(id: String, PlaylistModel)
    case deletePlaylist(id: String)
    case addVideoToPlaylist(playlistId: String, videoId: String)
    case removeVideoFromPlaylist(playlistId: String, videoId: String)
    case getSuggestions(query: String)
    case getSearchHistory
    case saveSearch(query: String, filters: SearchFilterModel?)
    
    var path: String {
        switch self {
        case .searchVideos:
            return "videos/search"
        case .getVideo(let id):
            return "videos/\(id)"
        case .getVideoTranscript(let id):
            return "videos/\(id)/transcript"
        case .getPlaylists:
            return "playlists"
        case .createPlaylist:
            return "playlists"
        case .updatePlaylist(let id, _):
            return "playlists/\(id)"
        case .deletePlaylist(let id):
            return "playlists/\(id)"
        case .addVideoToPlaylist(let playlistId, _):
            return "playlists/\(playlistId)/videos"
        case .removeVideoFromPlaylist(let playlistId, let videoId):
            return "playlists/\(playlistId)/videos/\(videoId)"
        case .getSuggestions:
            return "search/suggestions"
        case .getSearchHistory:
            return "search/history"
        case .saveSearch:
            return "search/history"
        }
    }
    
    var httpMethod: HTTPMethod {
        switch self {
        case .searchVideos, .getVideo, .getVideoTranscript, .getPlaylists, .getSuggestions, .getSearchHistory:
            return .GET
        case .createPlaylist, .addVideoToPlaylist, .saveSearch:
            return .POST
        case .updatePlaylist:
            return .PUT
        case .deletePlaylist, .removeVideoFromPlaylist:
            return .DELETE
        }
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Configuration Models
struct RateLimitConfiguration {
    let maxRequestsPerMinute: Int
    let maxRequestsPerTenMinutes: Int
    let maxRequestsPerFiveMinutes: Int
}

struct TimeoutConfiguration {
    let requestTimeout: TimeInterval
    let resourceTimeout: TimeInterval
}
