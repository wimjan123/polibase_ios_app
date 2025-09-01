import Foundation
import Combine
import Charts
import SwiftUI

@MainActor
class AnalyticsDashboardService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var dashboardMetrics: DashboardMetrics = DashboardMetrics()
    @Published var performanceData: [PerformanceMetric] = []
    @Published var userEngagementData: [EngagementMetric] = []
    @Published var searchAnalytics: [SearchAnalytic] = []
    @Published var collaborationMetrics: [CollaborationMetric] = []
    @Published var contentMetrics: [ContentMetric] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date?
    
    // MARK: - Dependencies
    private let analyticsService: AnalyticsService
    private let collaborationService: CollaborationService
    private let smartSearchService: SmartSearchService
    private let personalizationEngine: PersonalizationEngine
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private let metricsQueue = DispatchQueue(label: "analytics.metrics", qos: .utility)
    
    // MARK: - Configuration
    private struct Config {
        static let refreshInterval: TimeInterval = 30.0
        static let dataRetentionDays = 30
        static let maxDataPoints = 100
        static let performanceThresholds = PerformanceThresholds(
            searchLatency: 2.0,
            loadTime: 3.0,
            memoryUsage: 100.0,
            cpuUsage: 80.0
        )
    }
    
    // MARK: - Initialization
    init(
        analyticsService: AnalyticsService,
        collaborationService: CollaborationService,
        smartSearchService: SmartSearchService,
        personalizationEngine: PersonalizationEngine
    ) {
        self.analyticsService = analyticsService
        self.collaborationService = collaborationService
        self.smartSearchService = smartSearchService
        self.personalizationEngine = personalizationEngine
        
        setupSubscriptions()
        startPerformanceMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Refresh all dashboard metrics
    func refreshDashboard() async {
        isLoading = true
        
        do {
            async let metricsTask = loadDashboardMetrics()
            async let performanceTask = loadPerformanceData()
            async let engagementTask = loadUserEngagementData()
            async let searchTask = loadSearchAnalytics()
            async let collaborationTask = loadCollaborationMetrics()
            async let contentTask = loadContentMetrics()
            
            let (metrics, performance, engagement, search, collaboration, content) = await (
                try metricsTask,
                try performanceTask,
                try engagementTask,
                try searchTask,
                try collaborationTask,
                try contentTask
            )
            
            await MainActor.run {
                self.dashboardMetrics = metrics
                self.performanceData = performance
                self.userEngagementData = engagement
                self.searchAnalytics = search
                self.collaborationMetrics = collaboration
                self.contentMetrics = content
                self.lastUpdated = Date()
                self.isLoading = false
            }
            
            await analyticsService.trackEvent("dashboard_refreshed", parameters: [
                "metrics_count": metrics.totalUsers + metrics.totalSessions + metrics.totalSearches,
                "performance_data_points": performance.count,
                "engagement_data_points": engagement.count
            ])
            
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("Failed to refresh dashboard: \(error)")
        }
    }
    
    /// Get performance insights and recommendations
    func getPerformanceInsights() -> [PerformanceInsight] {
        var insights: [PerformanceInsight] = []
        
        // Analyze search performance
        let recentSearchMetrics = performanceData
            .filter { $0.type == .searchLatency }
            .suffix(10)
        
        if let averageLatency = recentSearchMetrics.map({ $0.value }).average(),
           averageLatency > Config.performanceThresholds.searchLatency {
            insights.append(PerformanceInsight(
                type: .performance,
                severity: .warning,
                title: "Search Performance Issue",
                description: "Average search latency (\(String(format: "%.2f", averageLatency))s) exceeds threshold",
                recommendation: "Consider optimizing search queries or implementing additional caching",
                actionable: true
            ))
        }
        
        // Analyze memory usage
        let recentMemoryMetrics = performanceData
            .filter { $0.type == .memoryUsage }
            .suffix(10)
        
        if let averageMemory = recentMemoryMetrics.map({ $0.value }).average(),
           averageMemory > Config.performanceThresholds.memoryUsage {
            insights.append(PerformanceInsight(
                type: .memory,
                severity: .error,
                title: "High Memory Usage",
                description: "Average memory usage (\(String(format: "%.1f", averageMemory))MB) is high",
                recommendation: "Review caching strategies and implement memory optimization",
                actionable: true
            ))
        }
        
        // Analyze user engagement
        let recentEngagement = userEngagementData.suffix(7) // Last 7 days
        if let averageSessionDuration = recentEngagement.map({ $0.sessionDuration }).average(),
           averageSessionDuration < 60 {
            insights.append(PerformanceInsight(
                type: .engagement,
                severity: .info,
                title: "Low Session Duration",
                description: "Average session duration (\(Int(averageSessionDuration))s) could be improved",
                recommendation: "Enhance user onboarding and content discovery features",
                actionable: true
            ))
        }
        
        // Analyze search success rate
        let recentSearches = searchAnalytics.suffix(10)
        if let averageSuccessRate = recentSearches.map({ $0.successRate }).average(),
           averageSuccessRate < 0.8 {
            insights.append(PerformanceInsight(
                type: .search,
                severity: .warning,
                title: "Low Search Success Rate",
                description: "Search success rate (\(String(format: "%.1f", averageSuccessRate * 100))%) needs improvement",
                recommendation: "Enhance search algorithms and query optimization",
                actionable: true
            ))
        }
        
        // Analyze collaboration usage
        let collaborationUsage = collaborationMetrics.suffix(7)
        if collaborationUsage.isEmpty || collaborationUsage.allSatisfy({ $0.activeSessions == 0 }) {
            insights.append(PerformanceInsight(
                type: .collaboration,
                severity: .info,
                title: "Low Collaboration Usage",
                description: "Collaboration features are underutilized",
                recommendation: "Promote collaboration features and provide user training",
                actionable: true
            ))
        }
        
        return insights
    }
    
    /// Get trending content and popular searches
    func getTrendingInsights() -> TrendingInsights {
        let recentSearches = searchAnalytics.suffix(7)
        let popularQueries = recentSearches
            .flatMap { $0.topQueries }
            .sorted { $0.frequency > $1.frequency }
            .prefix(10)
        
        let trendingTopics = contentMetrics.suffix(7)
            .flatMap { $0.topCategories }
            .sorted { $0.viewCount > $1.viewCount }
            .prefix(5)
        
        let growingFeatures = userEngagementData.suffix(7)
            .flatMap { $0.featureUsage }
            .sorted { $0.growthRate > $1.growthRate }
            .prefix(3)
        
        return TrendingInsights(
            popularQueries: Array(popularQueries),
            trendingTopics: Array(trendingTopics),
            growingFeatures: Array(growingFeatures),
            generatedAt: Date()
        )
    }
    
    /// Export analytics data
    func exportAnalytics(timeRange: DateRange, format: ExportFormat) async throws -> URL {
        let exportData = AnalyticsExportData(
            timeRange: timeRange,
            dashboardMetrics: dashboardMetrics,
            performanceData: performanceData.filter { timeRange.contains($0.timestamp) },
            userEngagementData: userEngagementData.filter { timeRange.contains($0.timestamp) },
            searchAnalytics: searchAnalytics.filter { timeRange.contains($0.timestamp) },
            collaborationMetrics: collaborationMetrics.filter { timeRange.contains($0.timestamp) },
            contentMetrics: contentMetrics.filter { timeRange.contains($0.timestamp) },
            insights: getPerformanceInsights(),
            trending: getTrendingInsights(),
            exportedAt: Date()
        )
        
        let exporter = AnalyticsExporter()
        let exportURL = try await exporter.export(data: exportData, format: format)
        
        await analyticsService.trackEvent("analytics_exported", parameters: [
            "format": format.rawValue,
            "time_range": timeRange.description,
            "data_points": exportData.totalDataPoints
        ])
        
        return exportURL
    }
    
    /// Start real-time monitoring
    func startRealTimeMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Config.refreshInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshDashboard()
            }
        }
    }
    
    /// Stop real-time monitoring
    func stopRealTimeMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    /// Get health status of all services
    func getSystemHealth() -> SystemHealth {
        let searchHealth = getSearchServiceHealth()
        let collaborationHealth = getCollaborationServiceHealth()
        let analyticsHealth = getAnalyticsServiceHealth()
        let performanceHealth = getPerformanceHealth()
        
        let overallStatus: HealthStatus = [searchHealth, collaborationHealth, analyticsHealth, performanceHealth]
            .min() ?? .healthy
        
        return SystemHealth(
            overallStatus: overallStatus,
            searchService: searchHealth,
            collaborationService: collaborationHealth,
            analyticsService: analyticsHealth,
            performance: performanceHealth,
            lastChecked: Date()
        )
    }
}

// MARK: - Private Methods
private extension AnalyticsDashboardService {
    
    func setupSubscriptions() {
        // Subscribe to analytics service updates
        analyticsService.$totalEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.updateMetricsFromAnalytics()
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to collaboration updates
        collaborationService.$activeCollaborators
            .receive(on: DispatchQueue.main)
            .sink { [weak self] collaborators in
                Task {
                    await self?.updateCollaborationMetrics(collaborators: collaborators)
                }
            }
            .store(in: &cancellables)
    }
    
    func startPerformanceMonitoring() {
        // Start monitoring system performance
        Task {
            while !Task.isCancelled {
                await collectPerformanceMetrics()
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            }
        }
    }
    
    func loadDashboardMetrics() async throws -> DashboardMetrics {
        // Simulate loading dashboard metrics
        let metrics = DashboardMetrics(
            totalUsers: Int.random(in: 1000...5000),
            activeUsers: Int.random(in: 100...500),
            totalSessions: Int.random(in: 5000...20000),
            totalSearches: Int.random(in: 10000...50000),
            totalAnnotations: Int.random(in: 2000...10000),
            totalCollaborations: Int.random(in: 100...1000),
            averageSessionDuration: Double.random(in: 120...600),
            searchSuccessRate: Double.random(in: 0.7...0.95),
            userSatisfactionScore: Double.random(in: 3.5...5.0),
            systemUptime: Double.random(in: 0.95...0.999)
        )
        
        return metrics
    }
    
    func loadPerformanceData() async throws -> [PerformanceMetric] {
        var metrics: [PerformanceMetric] = []
        
        // Generate sample performance data for the last 24 hours
        let now = Date()
        for i in 0..<24 {
            let timestamp = now.addingTimeInterval(TimeInterval(-i * 3600))
            
            metrics.append(PerformanceMetric(
                timestamp: timestamp,
                type: .searchLatency,
                value: Double.random(in: 0.5...3.0),
                unit: "seconds"
            ))
            
            metrics.append(PerformanceMetric(
                timestamp: timestamp,
                type: .memoryUsage,
                value: Double.random(in: 50...150),
                unit: "MB"
            ))
            
            metrics.append(PerformanceMetric(
                timestamp: timestamp,
                type: .cpuUsage,
                value: Double.random(in: 20...90),
                unit: "percent"
            ))
            
            metrics.append(PerformanceMetric(
                timestamp: timestamp,
                type: .loadTime,
                value: Double.random(in: 1.0...5.0),
                unit: "seconds"
            ))
        }
        
        return metrics.sorted { $0.timestamp < $1.timestamp }
    }
    
    func loadUserEngagementData() async throws -> [EngagementMetric] {
        var metrics: [EngagementMetric] = []
        
        // Generate sample engagement data for the last 7 days
        let now = Date()
        for i in 0..<7 {
            let date = now.addingTimeInterval(TimeInterval(-i * 86400))
            
            metrics.append(EngagementMetric(
                date: date,
                activeUsers: Int.random(in: 50...200),
                newUsers: Int.random(in: 5...30),
                sessionCount: Int.random(in: 100...500),
                sessionDuration: Double.random(in: 120...600),
                pageViews: Int.random(in: 500...2000),
                featureUsage: generateFeatureUsage(),
                retentionRate: Double.random(in: 0.6...0.9)
            ))
        }
        
        return metrics.sorted { $0.date < $1.date }
    }
    
    func loadSearchAnalytics() async throws -> [SearchAnalytic] {
        var analytics: [SearchAnalytic] = []
        
        // Generate sample search analytics for the last 7 days
        let now = Date()
        for i in 0..<7 {
            let date = now.addingTimeInterval(TimeInterval(-i * 86400))
            
            analytics.append(SearchAnalytic(
                date: date,
                totalSearches: Int.random(in: 500...2000),
                uniqueSearches: Int.random(in: 300...1500),
                successRate: Double.random(in: 0.7...0.95),
                averageLatency: Double.random(in: 0.5...2.5),
                topQueries: generateTopQueries(),
                zeroResultQueries: Int.random(in: 10...100),
                aiEnhancedSearches: Int.random(in: 100...500)
            ))
        }
        
        return analytics.sorted { $0.date < $1.date }
    }
    
    func loadCollaborationMetrics() async throws -> [CollaborationMetric] {
        var metrics: [CollaborationMetric] = []
        
        // Generate sample collaboration metrics for the last 7 days
        let now = Date()
        for i in 0..<7 {
            let date = now.addingTimeInterval(TimeInterval(-i * 86400))
            
            metrics.append(CollaborationMetric(
                date: date,
                activeSessions: Int.random(in: 5...50),
                totalCollaborators: Int.random(in: 20...200),
                averageSessionDuration: Double.random(in: 600...3600),
                documentsShared: Int.random(in: 10...100),
                conflictsResolved: Int.random(in: 0...20),
                invitationsSent: Int.random(in: 5...50),
                collaborationScore: Double.random(in: 3.0...5.0)
            ))
        }
        
        return metrics.sorted { $0.date < $1.date }
    }
    
    func loadContentMetrics() async throws -> [ContentMetric] {
        var metrics: [ContentMetric] = []
        
        // Generate sample content metrics for the last 7 days
        let now = Date()
        for i in 0..<7 {
            let date = now.addingTimeInterval(TimeInterval(-i * 86400))
            
            metrics.append(ContentMetric(
                date: date,
                totalViews: Int.random(in: 1000...5000),
                uniqueViews: Int.random(in: 500...3000),
                averageViewDuration: Double.random(in: 30...300),
                bookmarkCount: Int.random(in: 50...500),
                annotationCount: Int.random(in: 100...1000),
                shareCount: Int.random(in: 20...200),
                topCategories: generateTopCategories(),
                popularContent: generatePopularContent()
            ))
        }
        
        return metrics.sorted { $0.date < $1.date }
    }
    
    func updateMetricsFromAnalytics() async {
        // Update dashboard metrics based on analytics service data
        await MainActor.run {
            // This would update metrics based on real analytics data
            self.lastUpdated = Date()
        }
    }
    
    func updateCollaborationMetrics(collaborators: [Collaborator]) async {
        // Update collaboration metrics based on active collaborators
        let today = Date()
        
        if let todayMetric = collaborationMetrics.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            await MainActor.run {
                if let index = self.collaborationMetrics.firstIndex(where: { $0.date == todayMetric.date }) {
                    self.collaborationMetrics[index].totalCollaborators = collaborators.count
                }
            }
        }
    }
    
    func collectPerformanceMetrics() async {
        let now = Date()
        
        // Collect real performance metrics
        let memoryUsage = getMemoryUsage()
        let cpuUsage = getCPUUsage()
        
        let newMetrics = [
            PerformanceMetric(
                timestamp: now,
                type: .memoryUsage,
                value: memoryUsage,
                unit: "MB"
            ),
            PerformanceMetric(
                timestamp: now,
                type: .cpuUsage,
                value: cpuUsage,
                unit: "percent"
            )
        ]
        
        await MainActor.run {
            self.performanceData.append(contentsOf: newMetrics)
            
            // Keep only recent data
            let oneDayAgo = Date().addingTimeInterval(-86400)
            self.performanceData = self.performanceData.filter { $0.timestamp > oneDayAgo }
        }
    }
    
    func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        } else {
            return 0.0
        }
    }
    
    func getCPUUsage() -> Double {
        // Simplified CPU usage calculation
        return Double.random(in: 20...80)
    }
    
    func generateFeatureUsage() -> [FeatureUsage] {
        let features = ["Search", "Bookmarks", "Annotations", "Collaboration", "Export"]
        return features.map { feature in
            FeatureUsage(
                featureName: feature,
                usageCount: Int.random(in: 10...200),
                growthRate: Double.random(in: -0.1...0.5)
            )
        }
    }
    
    func generateTopQueries() -> [QueryFrequency] {
        let queries = [
            "healthcare policy", "climate change", "economic recovery",
            "foreign relations", "education reform", "immigration policy"
        ]
        return queries.map { query in
            QueryFrequency(
                query: query,
                frequency: Int.random(in: 10...100)
            )
        }
    }
    
    func generateTopCategories() -> [CategoryView] {
        let categories = ["Healthcare", "Economy", "Environment", "Education", "Foreign Policy"]
        return categories.map { category in
            CategoryView(
                category: category,
                viewCount: Int.random(in: 50...500)
            )
        }
    }
    
    func generatePopularContent() -> [PopularContent] {
        return [
            PopularContent(
                contentId: "content_1",
                title: "Healthcare Policy Debate",
                viewCount: Int.random(in: 100...1000)
            ),
            PopularContent(
                contentId: "content_2",
                title: "Economic Recovery Plan",
                viewCount: Int.random(in: 100...1000)
            )
        ]
    }
    
    func getSearchServiceHealth() -> HealthStatus {
        let recentSearchLatency = performanceData
            .filter { $0.type == .searchLatency }
            .suffix(5)
            .map { $0.value }
        
        if let averageLatency = recentSearchLatency.average() {
            return averageLatency > Config.performanceThresholds.searchLatency ? .degraded : .healthy
        }
        
        return .healthy
    }
    
    func getCollaborationServiceHealth() -> HealthStatus {
        let hasActiveCollaborations = !collaborationService.activeCollaborators.isEmpty
        let connectionStatus = collaborationService.connectionStatus
        
        if case .connected = connectionStatus, hasActiveCollaborations {
            return .healthy
        } else if case .connected = connectionStatus {
            return .degraded
        } else {
            return .unhealthy
        }
    }
    
    func getAnalyticsServiceHealth() -> HealthStatus {
        // Check if analytics service is responsive
        let hasRecentEvents = analyticsService.totalEvents > 0
        return hasRecentEvents ? .healthy : .degraded
    }
    
    func getPerformanceHealth() -> HealthStatus {
        let recentMemory = performanceData
            .filter { $0.type == .memoryUsage }
            .suffix(3)
            .map { $0.value }
        
        let recentCPU = performanceData
            .filter { $0.type == .cpuUsage }
            .suffix(3)
            .map { $0.value }
        
        if let avgMemory = recentMemory.average(),
           let avgCPU = recentCPU.average() {
            
            if avgMemory > Config.performanceThresholds.memoryUsage ||
               avgCPU > Config.performanceThresholds.cpuUsage {
                return .degraded
            }
        }
        
        return .healthy
    }
}

// MARK: - Supporting Models

struct DashboardMetrics: Codable {
    let totalUsers: Int
    let activeUsers: Int
    let totalSessions: Int
    let totalSearches: Int
    let totalAnnotations: Int
    let totalCollaborations: Int
    let averageSessionDuration: Double
    let searchSuccessRate: Double
    let userSatisfactionScore: Double
    let systemUptime: Double
    
    init() {
        self.totalUsers = 0
        self.activeUsers = 0
        self.totalSessions = 0
        self.totalSearches = 0
        self.totalAnnotations = 0
        self.totalCollaborations = 0
        self.averageSessionDuration = 0
        self.searchSuccessRate = 0
        self.userSatisfactionScore = 0
        self.systemUptime = 0
    }
    
    init(totalUsers: Int, activeUsers: Int, totalSessions: Int, totalSearches: Int, totalAnnotations: Int, totalCollaborations: Int, averageSessionDuration: Double, searchSuccessRate: Double, userSatisfactionScore: Double, systemUptime: Double) {
        self.totalUsers = totalUsers
        self.activeUsers = activeUsers
        self.totalSessions = totalSessions
        self.totalSearches = totalSearches
        self.totalAnnotations = totalAnnotations
        self.totalCollaborations = totalCollaborations
        self.averageSessionDuration = averageSessionDuration
        self.searchSuccessRate = searchSuccessRate
        self.userSatisfactionScore = userSatisfactionScore
        self.systemUptime = systemUptime
    }
}

struct PerformanceMetric: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let type: MetricType
    let value: Double
    let unit: String
    
    enum MetricType: String, CaseIterable, Codable {
        case searchLatency = "search_latency"
        case memoryUsage = "memory_usage"
        case cpuUsage = "cpu_usage"
        case loadTime = "load_time"
    }
}

struct EngagementMetric: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let activeUsers: Int
    let newUsers: Int
    let sessionCount: Int
    let sessionDuration: Double
    let pageViews: Int
    let featureUsage: [FeatureUsage]
    let retentionRate: Double
}

struct SearchAnalytic: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let totalSearches: Int
    let uniqueSearches: Int
    let successRate: Double
    let averageLatency: Double
    let topQueries: [QueryFrequency]
    let zeroResultQueries: Int
    let aiEnhancedSearches: Int
}

struct CollaborationMetric: Identifiable, Codable {
    let id = UUID()
    let date: Date
    var activeSessions: Int
    var totalCollaborators: Int
    let averageSessionDuration: Double
    let documentsShared: Int
    let conflictsResolved: Int
    let invitationsSent: Int
    let collaborationScore: Double
}

struct ContentMetric: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let totalViews: Int
    let uniqueViews: Int
    let averageViewDuration: Double
    let bookmarkCount: Int
    let annotationCount: Int
    let shareCount: Int
    let topCategories: [CategoryView]
    let popularContent: [PopularContent]
}

struct FeatureUsage: Identifiable, Codable {
    let id = UUID()
    let featureName: String
    let usageCount: Int
    let growthRate: Double
}

struct QueryFrequency: Identifiable, Codable {
    let id = UUID()
    let query: String
    let frequency: Int
}

struct CategoryView: Identifiable, Codable {
    let id = UUID()
    let category: String
    let viewCount: Int
}

struct PopularContent: Identifiable, Codable {
    let id = UUID()
    let contentId: String
    let title: String
    let viewCount: Int
}

struct PerformanceInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let severity: Severity
    let title: String
    let description: String
    let recommendation: String
    let actionable: Bool
    
    enum InsightType {
        case performance
        case memory
        case engagement
        case search
        case collaboration
    }
    
    enum Severity {
        case info
        case warning
        case error
    }
}

struct TrendingInsights {
    let popularQueries: [QueryFrequency]
    let trendingTopics: [CategoryView]
    let growingFeatures: [FeatureUsage]
    let generatedAt: Date
}

struct SystemHealth {
    let overallStatus: HealthStatus
    let searchService: HealthStatus
    let collaborationService: HealthStatus
    let analyticsService: HealthStatus
    let performance: HealthStatus
    let lastChecked: Date
}

enum HealthStatus: Comparable {
    case healthy
    case degraded
    case unhealthy
    
    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .degraded: return "Degraded"
        case .unhealthy: return "Unhealthy"
        }
    }
    
    var color: String {
        switch self {
        case .healthy: return "green"
        case .degraded: return "yellow"
        case .unhealthy: return "red"
        }
    }
}

struct PerformanceThresholds {
    let searchLatency: Double
    let loadTime: Double
    let memoryUsage: Double
    let cpuUsage: Double
}

struct DateRange {
    let startDate: Date
    let endDate: Date
    
    func contains(_ date: Date) -> Bool {
        return date >= startDate && date <= endDate
    }
    
    var description: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

enum ExportFormat: String, CaseIterable {
    case csv = "csv"
    case json = "json"
    case pdf = "pdf"
    case excel = "xlsx"
}

struct AnalyticsExportData {
    let timeRange: DateRange
    let dashboardMetrics: DashboardMetrics
    let performanceData: [PerformanceMetric]
    let userEngagementData: [EngagementMetric]
    let searchAnalytics: [SearchAnalytic]
    let collaborationMetrics: [CollaborationMetric]
    let contentMetrics: [ContentMetric]
    let insights: [PerformanceInsight]
    let trending: TrendingInsights
    let exportedAt: Date
    
    var totalDataPoints: Int {
        return performanceData.count +
               userEngagementData.count +
               searchAnalytics.count +
               collaborationMetrics.count +
               contentMetrics.count
    }
}

// MARK: - Analytics Exporter

class AnalyticsExporter {
    func export(data: AnalyticsExportData, format: ExportFormat) async throws -> URL {
        switch format {
        case .csv:
            return try await exportToCSV(data: data)
        case .json:
            return try await exportToJSON(data: data)
        case .pdf:
            return try await exportToPDF(data: data)
        case .excel:
            return try await exportToExcel(data: data)
        }
    }
    
    private func exportToCSV(data: AnalyticsExportData) async throws -> URL {
        // Implement CSV export
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("analytics_export.csv")
        
        var csvContent = "Date,Type,Value\n"
        
        for metric in data.performanceData {
            csvContent += "\(metric.timestamp),\(metric.type.rawValue),\(metric.value)\n"
        }
        
        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func exportToJSON(data: AnalyticsExportData) async throws -> URL {
        // Implement JSON export
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("analytics_export.json")
        
        let jsonData = try JSONEncoder().encode(data.dashboardMetrics)
        try jsonData.write(to: fileURL)
        return fileURL
    }
    
    private func exportToPDF(data: AnalyticsExportData) async throws -> URL {
        // Implement PDF export (simplified)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("analytics_export.pdf")
        
        // Create a simple text file for demonstration
        let pdfContent = "Analytics Export\n\nTotal Users: \(data.dashboardMetrics.totalUsers)\nActive Users: \(data.dashboardMetrics.activeUsers)\n"
        try pdfContent.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func exportToExcel(data: AnalyticsExportData) async throws -> URL {
        // Implement Excel export (simplified)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("analytics_export.xlsx")
        
        // Create a CSV file for demonstration (would use proper Excel library in real implementation)
        return try await exportToCSV(data: data)
    }
}

// MARK: - Extensions

extension Array where Element == Double {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
