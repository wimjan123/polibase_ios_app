import Foundation

// MARK: - App Configuration
struct AppConfiguration {
    static let shared = AppConfiguration()
    
    // API Configuration
    let apiBaseURL: String
    let apiKey: String?
    let apiVersion: String
    
    // Rate Limiting Configuration
    let maxRequestsPerMinute: Int = 100
    let maxRequestsPerTenMinutes: Int = 10
    let maxRequestsPerFiveMinutes: Int = 5
    
    // Cache Configuration
    let maxCacheSize: Int = 100 * 1024 * 1024 // 100MB
    let cacheExpirationDays: Int = 7
    
    // Video Configuration
    let supportedVideoFormats: [String] = ["mp4", "mov", "m4v"]
    let defaultVideoQuality: VideoQuality = .medium
    
    private init() {
        // Load from environment or plist
        self.apiBaseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "https://api.politicaltranscripts.com"
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String
        self.apiVersion = "v1"
    }
}

// MARK: - Video Quality Enum
enum VideoQuality: String, CaseIterable {
    case low = "360p"
    case medium = "720p"
    case high = "1080p"
    
    var resolution: (width: Int, height: Int) {
        switch self {
        case .low:
            return (width: 640, height: 360)
        case .medium:
            return (width: 1280, height: 720)
        case .high:
            return (width: 1920, height: 1080)
        }
    }
}

// MARK: - App State Enum
enum AppState {
    case loading
    case loaded
    case error(Error)
    case offline
}

// MARK: - Navigation Destinations
enum NavigationDestination {
    case search
    case videoDetail(VideoModel)
    case playlist(PlaylistModel)
    case settings
}
