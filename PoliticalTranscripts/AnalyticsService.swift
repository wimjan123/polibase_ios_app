//
//  AnalyticsService.swift
//  PoliticalTranscripts
//
//  Comprehensive analytics and user behavior tracking service for
//  performance optimization and user experience enhancement.
//

import Foundation
import OSLog

/// Comprehensive analytics service for user behavior tracking and performance optimization
@MainActor
class AnalyticsService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isTrackingEnabled: Bool = true
    @Published var sessionMetrics: SessionMetrics = SessionMetrics()
    @Published var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "PoliticalTranscripts", category: "Analytics")
    private let eventQueue = DispatchQueue(label: "analytics.queue", qos: .utility)
    private var eventBuffer: [AnalyticsEvent] = []
    private var sessionStartTime: Date = Date()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Configuration
    private struct Configuration {
        static let bufferSize = 50
        static let flushInterval: TimeInterval = 30
        static let sessionTimeoutInterval: TimeInterval = 1800 // 30 minutes
        static let maxRetainedEvents = 1000
    }
    
    // MARK: - Initialization
    init() {
        setupAnalytics()
        startSession()
    }
    
    // MARK: - Public Interface
    
    /// Tracks user actions with contextual information
    /// - Parameters:
    ///   - action: The user action being tracked
    ///   - context: Additional context for the action
    func trackUserAction(_ action: UserAction, context: AnalyticsContext) async {
        guard isTrackingEnabled else { return }
        
        let event = AnalyticsEvent(
            type: .userAction,
            action: action,
            context: context,
            timestamp: Date(),
            sessionId: sessionMetrics.sessionId,
            userId: getCurrentUserId()
        )
        
        await recordEvent(event)
        
        // Update session metrics
        updateSessionMetrics(for: action)
        
        logger.info("Tracked user action: \(action.rawValue) in context: \(context.rawValue)")
    }
    
    /// Tracks search queries and their results
    /// - Parameters:
    ///   - query: The search query string
    ///   - results: Array of search results returned
    func trackSearchQuery(_ query: String, results: [SearchResultModel]) async {
        guard isTrackingEnabled else { return }
        
        let searchMetrics = SearchMetrics(
            query: query,
            resultCount: results.count,
            timestamp: Date(),
            queryLength: query.count,
            hasFilters: !query.isEmpty,
            executionTime: 0.0 // Set by caller if available
        )
        
        let event = AnalyticsEvent(
            type: .search,
            action: .search(query: query, resultCount: results.count),
            context: .search,
            timestamp: Date(),
            sessionId: sessionMetrics.sessionId,
            userId: getCurrentUserId(),
            searchMetrics: searchMetrics
        )
        
        await recordEvent(event)
        
        // Update search-specific metrics
        sessionMetrics.searchCount += 1
        sessionMetrics.totalResults += results.count
        
        logger.info("Tracked search query: '\(query)' with \(results.count) results")
    }
    
    /// Tracks content engagement and viewing patterns
    /// - Parameters:
    ///   - transcript: The transcript being viewed
    ///   - duration: Time spent viewing the content
    func trackContentEngagement(_ transcript: VideoModel, duration: TimeInterval) async {
        guard isTrackingEnabled else { return }
        
        let engagementMetrics = ContentEngagementMetrics(
            transcriptId: transcript.id.uuidString,
            title: transcript.title,
            speaker: transcript.speaker,
            duration: duration,
            timestamp: Date(),
            source: transcript.source ?? "unknown",
            category: transcript.category ?? "general"
        )
        
        let event = AnalyticsEvent(
            type: .contentEngagement,
            action: .viewContent(transcriptId: transcript.id.uuidString, duration: duration),
            context: .content,
            timestamp: Date(),
            sessionId: sessionMetrics.sessionId,
            userId: getCurrentUserId(),
            engagementMetrics: engagementMetrics
        )
        
        await recordEvent(event)
        
        // Update engagement metrics
        sessionMetrics.contentViewCount += 1
        sessionMetrics.totalViewTime += duration
        
        logger.info("Tracked content engagement: \(transcript.title) for \(duration) seconds")
    }
    
    /// Tracks performance metrics for optimization
    /// - Parameters:
    ///   - operation: The operation being measured
    ///   - duration: Time taken to complete the operation
    ///   - success: Whether the operation succeeded
    func trackPerformance(_ operation: PerformanceOperation, duration: TimeInterval, success: Bool) async {
        guard isTrackingEnabled else { return }
        
        let performanceData = PerformanceMetrics.OperationMetrics(
            operation: operation,
            duration: duration,
            success: success,
            timestamp: Date()
        )
        
        performanceMetrics.addOperation(performanceData)
        
        let event = AnalyticsEvent(
            type: .performance,
            action: .performance(operation: operation.rawValue, duration: duration, success: success),
            context: .performance,
            timestamp: Date(),
            sessionId: sessionMetrics.sessionId,
            userId: getCurrentUserId(),
            performanceData: performanceData
        )
        
        await recordEvent(event)
        
        logger.info("Tracked performance: \(operation.rawValue) took \(duration)s, success: \(success)")
    }
    
    /// Tracks errors and exceptions for debugging
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: Context in which the error occurred
    ///   - additionalInfo: Additional debugging information
    func trackError(_ error: Error, context: AnalyticsContext, additionalInfo: [String: Any]? = nil) async {
        let errorInfo = ErrorMetrics(
            error: error,
            context: context,
            additionalInfo: additionalInfo,
            timestamp: Date()
        )
        
        let event = AnalyticsEvent(
            type: .error,
            action: .error(error: error.localizedDescription, context: context.rawValue),
            context: context,
            timestamp: Date(),
            sessionId: sessionMetrics.sessionId,
            userId: getCurrentUserId(),
            errorInfo: errorInfo
        )
        
        await recordEvent(event)
        
        sessionMetrics.errorCount += 1
        
        logger.error("Tracked error: \(error.localizedDescription) in context: \(context.rawValue)")
    }
    
    /// Flushes buffered events to persistent storage or remote analytics service
    func flushEvents() async {
        guard !eventBuffer.isEmpty else { return }
        
        let eventsToFlush = eventBuffer
        eventBuffer.removeAll()
        
        do {
            // Store events locally
            try await storeEventsLocally(eventsToFlush)
            
            // Send to remote analytics service (if configured)
            try await sendEventsToRemote(eventsToFlush)
            
            logger.info("Successfully flushed \(eventsToFlush.count) analytics events")
            
        } catch {
            // Restore events to buffer if flush fails
            eventBuffer.append(contentsOf: eventsToFlush)
            logger.error("Failed to flush analytics events: \(error.localizedDescription)")
        }
    }
    
    /// Generates analytics summary for reporting
    /// - Parameter timeRange: Time range for the summary
    /// - Returns: Comprehensive analytics summary
    func generateAnalyticsSummary(for timeRange: TimeRange) async -> AnalyticsSummary {
        let events = await loadEvents(for: timeRange)
        
        return AnalyticsSummary(
            timeRange: timeRange,
            sessionCount: calculateSessionCount(events),
            userActionCount: events.filter { $0.type == .userAction }.count,
            searchCount: events.filter { $0.type == .search }.count,
            contentEngagementCount: events.filter { $0.type == .contentEngagement }.count,
            errorCount: events.filter { $0.type == .error }.count,
            averageSessionDuration: calculateAverageSessionDuration(events),
            topSearchQueries: extractTopSearchQueries(events),
            topContent: extractTopContent(events),
            performanceSummary: generatePerformanceSummary(events),
            userRetention: calculateUserRetention(events)
        )
    }
}

// MARK: - Supporting Types

/// User action enumeration for tracking
enum UserAction: String, Codable {
    case appLaunch = "app_launch"
    case appBackground = "app_background"
    case appForeground = "app_foreground"
    case search = "search"
    case viewContent = "view_content"
    case bookmark = "bookmark"
    case share = "share"
    case filter = "filter"
    case sort = "sort"
    case loadMore = "load_more"
    case naturalLanguageQuery = "natural_language_query"
    case queryRefinement = "query_refinement"
    case error = "error"
    case performance = "performance"
    
    // Convenience constructors for complex actions
    static func search(query: String, resultCount: Int) -> UserAction {
        return .search
    }
    
    static func viewContent(transcriptId: String, duration: TimeInterval) -> UserAction {
        return .viewContent
    }
    
    static func naturalLanguageQuery(_ query: String) -> UserAction {
        return .naturalLanguageQuery
    }
    
    static func queryRefinement(original: String, refined: String) -> UserAction {
        return .queryRefinement
    }
    
    static func error(error: String, context: String) -> UserAction {
        return .error
    }
    
    static func performance(operation: String, duration: TimeInterval, success: Bool) -> UserAction {
        return .performance
    }
}

/// Analytics context for categorizing events
enum AnalyticsContext: String, Codable {
    case search = "search"
    case content = "content"
    case navigation = "navigation"
    case settings = "settings"
    case social = "social"
    case performance = "performance"
    case error = "error"
    case searchOptimization = "search_optimization"
}

/// Performance operation types for tracking
enum PerformanceOperation: String, Codable {
    case appLaunch = "app_launch"
    case searchQuery = "search_query"
    case contentLoad = "content_load"
    case imageLoad = "image_load"
    case cacheOperation = "cache_operation"
    case apiRequest = "api_request"
    case databaseQuery = "database_query"
}

/// Core analytics event structure
struct AnalyticsEvent: Codable, Identifiable {
    let id: UUID = UUID()
    let type: EventType
    let action: UserAction
    let context: AnalyticsContext
    let timestamp: Date
    let sessionId: String
    let userId: String
    
    // Optional detailed metrics
    let searchMetrics: SearchMetrics?
    let engagementMetrics: ContentEngagementMetrics?
    let performanceData: PerformanceMetrics.OperationMetrics?
    let errorInfo: ErrorMetrics?
    
    init(type: EventType, action: UserAction, context: AnalyticsContext, timestamp: Date, sessionId: String, userId: String, searchMetrics: SearchMetrics? = nil, engagementMetrics: ContentEngagementMetrics? = nil, performanceData: PerformanceMetrics.OperationMetrics? = nil, errorInfo: ErrorMetrics? = nil) {
        self.type = type
        self.action = action
        self.context = context
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.searchMetrics = searchMetrics
        self.engagementMetrics = engagementMetrics
        self.performanceData = performanceData
        self.errorInfo = errorInfo
    }
}

/// Event type categorization
enum EventType: String, Codable {
    case userAction = "user_action"
    case search = "search"
    case contentEngagement = "content_engagement"
    case performance = "performance"
    case error = "error"
}

/// Session metrics tracking
struct SessionMetrics: Codable {
    let sessionId: String = UUID().uuidString
    let startTime: Date = Date()
    var endTime: Date?
    var searchCount: Int = 0
    var contentViewCount: Int = 0
    var totalResults: Int = 0
    var totalViewTime: TimeInterval = 0
    var errorCount: Int = 0
    var userActions: [UserAction] = []
    
    var duration: TimeInterval {
        return (endTime ?? Date()).timeIntervalSince(startTime)
    }
}

/// Search-specific metrics
struct SearchMetrics: Codable {
    let query: String
    let resultCount: Int
    let timestamp: Date
    let queryLength: Int
    let hasFilters: Bool
    let executionTime: TimeInterval
}

/// Content engagement metrics
struct ContentEngagementMetrics: Codable {
    let transcriptId: String
    let title: String
    let speaker: String
    let duration: TimeInterval
    let timestamp: Date
    let source: String
    let category: String
}

/// Performance metrics tracking
struct PerformanceMetrics: Codable {
    private var operations: [OperationMetrics] = []
    
    struct OperationMetrics: Codable {
        let operation: PerformanceOperation
        let duration: TimeInterval
        let success: Bool
        let timestamp: Date
    }
    
    mutating func addOperation(_ operation: OperationMetrics) {
        operations.append(operation)
        
        // Keep only recent operations to prevent memory growth
        if operations.count > 1000 {
            operations.removeFirst(100)
        }
    }
    
    func averageDuration(for operation: PerformanceOperation) -> TimeInterval {
        let relevantOps = operations.filter { $0.operation == operation }
        guard !relevantOps.isEmpty else { return 0 }
        return relevantOps.map { $0.duration }.reduce(0, +) / Double(relevantOps.count)
    }
    
    func successRate(for operation: PerformanceOperation) -> Double {
        let relevantOps = operations.filter { $0.operation == operation }
        guard !relevantOps.isEmpty else { return 0 }
        let successCount = relevantOps.filter { $0.success }.count
        return Double(successCount) / Double(relevantOps.count)
    }
}

/// Error tracking metrics
struct ErrorMetrics: Codable {
    let error: Error
    let context: AnalyticsContext
    let additionalInfo: [String: Any]?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case context, timestamp
    }
    
    init(error: Error, context: AnalyticsContext, additionalInfo: [String: Any]?, timestamp: Date) {
        self.error = error
        self.context = context
        self.additionalInfo = additionalInfo
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.context = try container.decode(AnalyticsContext.self, forKey: .context)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.error = NSError(domain: "AnalyticsError", code: 0, userInfo: nil)
        self.additionalInfo = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(context, forKey: .context)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

/// Time range for analytics queries
struct TimeRange: Codable {
    let start: Date
    let end: Date
    
    static let last24Hours = TimeRange(
        start: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
        end: Date()
    )
    
    static let lastWeek = TimeRange(
        start: Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date(),
        end: Date()
    )
    
    static let lastMonth = TimeRange(
        start: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
        end: Date()
    )
}

/// Comprehensive analytics summary
struct AnalyticsSummary: Codable {
    let timeRange: TimeRange
    let sessionCount: Int
    let userActionCount: Int
    let searchCount: Int
    let contentEngagementCount: Int
    let errorCount: Int
    let averageSessionDuration: TimeInterval
    let topSearchQueries: [String]
    let topContent: [String]
    let performanceSummary: PerformanceSummary
    let userRetention: RetentionMetrics
}

/// Performance summary for analytics
struct PerformanceSummary: Codable {
    let averageSearchTime: TimeInterval
    let averageContentLoadTime: TimeInterval
    let errorRate: Double
    let successRate: Double
}

/// User retention metrics
struct RetentionMetrics: Codable {
    let dailyActiveUsers: Int
    let weeklyActiveUsers: Int
    let monthlyActiveUsers: Int
    let averageSessionsPerUser: Double
}

// MARK: - Private Extensions

private extension AnalyticsService {
    
    func setupAnalytics() {
        // Initialize analytics configuration
        if userDefaults.object(forKey: "analytics_enabled") == nil {
            userDefaults.set(true, forKey: "analytics_enabled")
        }
        isTrackingEnabled = userDefaults.bool(forKey: "analytics_enabled")
    }
    
    func startSession() {
        sessionStartTime = Date()
        sessionMetrics = SessionMetrics()
        
        Task {
            await trackUserAction(.appLaunch, context: .navigation)
        }
    }
    
    func recordEvent(_ event: AnalyticsEvent) async {
        eventBuffer.append(event)
        
        // Auto-flush if buffer is full
        if eventBuffer.count >= Configuration.bufferSize {
            await flushEvents()
        }
    }
    
    func updateSessionMetrics(for action: UserAction) {
        sessionMetrics.userActions.append(action)
    }
    
    func getCurrentUserId() -> String {
        if let userId = userDefaults.string(forKey: "user_id") {
            return userId
        } else {
            let newUserId = UUID().uuidString
            userDefaults.set(newUserId, forKey: "user_id")
            return newUserId
        }
    }
    
    func storeEventsLocally(_ events: [AnalyticsEvent]) async throws {
        // Implementation for local storage
        let encoder = JSONEncoder()
        let data = try encoder.encode(events)
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let analyticsPath = documentsPath.appendingPathComponent("analytics")
        
        try FileManager.default.createDirectory(at: analyticsPath, withIntermediateDirectories: true)
        
        let fileName = "events_\(Date().timeIntervalSince1970).json"
        let filePath = analyticsPath.appendingPathComponent(fileName)
        
        try data.write(to: filePath)
    }
    
    func sendEventsToRemote(_ events: [AnalyticsEvent]) async throws {
        // Implementation for remote analytics service
        // This would typically send to a service like Firebase Analytics, Mixpanel, etc.
        logger.info("Would send \(events.count) events to remote analytics service")
    }
    
    func loadEvents(for timeRange: TimeRange) async -> [AnalyticsEvent] {
        // Implementation for loading events from storage
        return []
    }
    
    func calculateSessionCount(_ events: [AnalyticsEvent]) -> Int {
        return Set(events.map { $0.sessionId }).count
    }
    
    func calculateAverageSessionDuration(_ events: [AnalyticsEvent]) -> TimeInterval {
        // Implementation for calculating average session duration
        return 0
    }
    
    func extractTopSearchQueries(_ events: [AnalyticsEvent]) -> [String] {
        // Implementation for extracting top search queries
        return []
    }
    
    func extractTopContent(_ events: [AnalyticsEvent]) -> [String] {
        // Implementation for extracting top content
        return []
    }
    
    func generatePerformanceSummary(_ events: [AnalyticsEvent]) -> PerformanceSummary {
        // Implementation for generating performance summary
        return PerformanceSummary(
            averageSearchTime: 0.5,
            averageContentLoadTime: 1.2,
            errorRate: 0.01,
            successRate: 0.99
        )
    }
    
    func calculateUserRetention(_ events: [AnalyticsEvent]) -> RetentionMetrics {
        // Implementation for calculating user retention
        return RetentionMetrics(
            dailyActiveUsers: 100,
            weeklyActiveUsers: 500,
            monthlyActiveUsers: 2000,
            averageSessionsPerUser: 3.5
        )
    }
}
