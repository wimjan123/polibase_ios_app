import Foundation

// MARK: - App Environment Configuration
enum AppEnvironment: String, CaseIterable {
    case development = "development"
    case staging = "staging"
    case production = "production"
    
    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }
    
    var displayName: String {
        switch self {
        case .development:
            return "Development"
        case .staging:
            return "Staging"
        case .production:
            return "Production"
        }
    }
}

// MARK: - Environment Manager
class EnvironmentManager: ObservableObject {
    static let shared = EnvironmentManager()
    
    @Published var currentEnvironment: AppEnvironment = .current
    
    private init() {}
    
    // MARK: - API Configuration
    var apiBaseURL: String {
        switch currentEnvironment {
        case .development:
            return Bundle.main.object(forInfoDictionaryKey: "DEV_API_BASE_URL") as? String ?? "http://localhost:8000"
        case .staging:
            return Bundle.main.object(forInfoDictionaryKey: "STAGING_API_BASE_URL") as? String ?? "https://api-staging.politicaltranscripts.com"
        case .production:
            return Bundle.main.object(forInfoDictionaryKey: "PROD_API_BASE_URL") as? String ?? "https://api.politicaltranscripts.com"
        }
    }
    
    var apiKey: String? {
        switch currentEnvironment {
        case .development:
            return Bundle.main.object(forInfoDictionaryKey: "DEV_API_KEY") as? String
        case .staging:
            return Bundle.main.object(forInfoDictionaryKey: "STAGING_API_KEY") as? String
        case .production:
            return Bundle.main.object(forInfoDictionaryKey: "PROD_API_KEY") as? String
        }
    }
    
    var apiVersion: String {
        return "v1"
    }
    
    // MARK: - Feature Flags
    var enableDebugLogging: Bool {
        switch currentEnvironment {
        case .development, .staging:
            return true
        case .production:
            return false
        }
    }
    
    var enableAnalytics: Bool {
        switch currentEnvironment {
        case .development:
            return false
        case .staging, .production:
            return true
        }
    }
    
    var enableCrashReporting: Bool {
        switch currentEnvironment {
        case .development:
            return false
        case .staging, .production:
            return true
        }
    }
    
    // MARK: - Performance Configuration
    var requestTimeoutInterval: TimeInterval {
        switch currentEnvironment {
        case .development:
            return 60.0 // Longer timeout for debugging
        case .staging, .production:
            return 30.0
        }
    }
    
    var cacheMaxSize: Int {
        switch currentEnvironment {
        case .development:
            return 50 * 1024 * 1024 // 50MB for development
        case .staging:
            return 75 * 1024 * 1024 // 75MB for staging
        case .production:
            return 100 * 1024 * 1024 // 100MB for production
        }
    }
    
    var maxConcurrentDownloads: Int {
        switch currentEnvironment {
        case .development:
            return 2
        case .staging:
            return 4
        case .production:
            return 6
        }
    }
    
    // MARK: - Debug Helpers
    func printConfiguration() {
        guard enableDebugLogging else { return }
        
        print("🔧 Environment Configuration")
        print("Environment: \(currentEnvironment.displayName)")
        print("API Base URL: \(apiBaseURL)")
        print("API Version: \(apiVersion)")
        print("Debug Logging: \(enableDebugLogging)")
        print("Analytics: \(enableAnalytics)")
        print("Crash Reporting: \(enableCrashReporting)")
        print("Request Timeout: \(requestTimeoutInterval)s")
        print("Cache Max Size: \(ByteCountFormatter.string(fromByteCount: Int64(cacheMaxSize), countStyle: .file))")
        print("Max Concurrent Downloads: \(maxConcurrentDownloads)")
    }
}
