import SwiftUI
import Charts
import Combine

struct AnalyticsDashboardView: View {
    @StateObject private var analyticsService: AnalyticsDashboardService
    @State private var selectedTimeRange: TimeRange = .last7Days
    @State private var selectedMetricCategory: MetricCategory = .overview
    @State private var showingExportSheet = false
    @State private var showingInsightsDetail = false
    @State private var refreshTrigger = 0
    
    init(analyticsService: AnalyticsDashboardService) {
        self._analyticsService = StateObject(wrappedValue: analyticsService)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header with controls
                    headerSection
                    
                    // Key Metrics Cards
                    if selectedMetricCategory == .overview || selectedMetricCategory == .all {
                        keyMetricsSection
                    }
                    
                    // Performance Charts
                    if selectedMetricCategory == .performance || selectedMetricCategory == .all {
                        performanceChartsSection
                    }
                    
                    // User Engagement
                    if selectedMetricCategory == .engagement || selectedMetricCategory == .all {
                        engagementSection
                    }
                    
                    // Search Analytics
                    if selectedMetricCategory == .search || selectedMetricCategory == .all {
                        searchAnalyticsSection
                    }
                    
                    // Collaboration Metrics
                    if selectedMetricCategory == .collaboration || selectedMetricCategory == .all {
                        collaborationSection
                    }
                    
                    // System Health
                    if selectedMetricCategory == .system || selectedMetricCategory == .all {
                        systemHealthSection
                    }
                    
                    // Insights and Recommendations
                    insightsSection
                    
                    // Trending Content
                    trendingSection
                }
                .padding()
            }
            .navigationTitle("Analytics Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingExportSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .refreshable {
                await analyticsService.refreshDashboard()
                refreshTrigger += 1
            }
            .task {
                await analyticsService.refreshDashboard()
                analyticsService.startRealTimeMonitoring()
            }
            .onDisappear {
                analyticsService.stopRealTimeMonitoring()
            }
            .sheet(isPresented: $showingExportSheet) {
                AnalyticsExportView(analyticsService: analyticsService)
            }
            .sheet(isPresented: $showingInsightsDetail) {
                InsightsDetailView(insights: analyticsService.getPerformanceInsights())
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Dashboard Overview")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let lastUpdated = analyticsService.lastUpdated {
                    Text("Updated \(lastUpdated, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Time Range Selector
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MetricCategory.allCases, id: \.self) { category in
                        CategoryFilterChip(
                            category: category,
                            isSelected: selectedMetricCategory == category
                        ) {
                            selectedMetricCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Key Metrics Section
    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Metrics")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                MetricCard(
                    title: "Total Users",
                    value: formatNumber(analyticsService.dashboardMetrics.totalUsers),
                    subtitle: "Active: \(analyticsService.dashboardMetrics.activeUsers)",
                    trend: .up,
                    trendValue: "12%",
                    color: .blue
                )
                
                MetricCard(
                    title: "Sessions",
                    value: formatNumber(analyticsService.dashboardMetrics.totalSessions),
                    subtitle: "Avg: \(formatDuration(analyticsService.dashboardMetrics.averageSessionDuration))",
                    trend: .up,
                    trendValue: "8%",
                    color: .green
                )
                
                MetricCard(
                    title: "Searches",
                    value: formatNumber(analyticsService.dashboardMetrics.totalSearches),
                    subtitle: "Success: \(formatPercentage(analyticsService.dashboardMetrics.searchSuccessRate))",
                    trend: .up,
                    trendValue: "5%",
                    color: .orange
                )
                
                MetricCard(
                    title: "Collaborations",
                    value: formatNumber(analyticsService.dashboardMetrics.totalCollaborations),
                    subtitle: "Annotations: \(analyticsService.dashboardMetrics.totalAnnotations)",
                    trend: .up,
                    trendValue: "15%",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Performance Charts Section
    private var performanceChartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 20) {
                // Search Latency Chart
                ChartContainer(title: "Search Latency", subtitle: "Response times") {
                    Chart(filteredPerformanceData(.searchLatency)) { metric in
                        LineMark(
                            x: .value("Time", metric.timestamp),
                            y: .value("Latency", metric.value)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("\(doubleValue, specifier: "%.1f")s")
                                }
                            }
                        }
                    }
                }
                
                // Memory and CPU Usage
                HStack(spacing: 16) {
                    ChartContainer(title: "Memory Usage", subtitle: "Current consumption") {
                        Chart(filteredPerformanceData(.memoryUsage)) { metric in
                            AreaMark(
                                x: .value("Time", metric.timestamp),
                                y: .value("Memory", metric.value)
                            )
                            .foregroundStyle(.green.gradient)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text("\(Int(doubleValue))MB")
                                    }
                                }
                            }
                        }
                    }
                    
                    ChartContainer(title: "CPU Usage", subtitle: "Processing load") {
                        Chart(filteredPerformanceData(.cpuUsage)) { metric in
                            AreaMark(
                                x: .value("Time", metric.timestamp),
                                y: .value("CPU", metric.value)
                            )
                            .foregroundStyle(.orange.gradient)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text("\(Int(doubleValue))%")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Engagement Section
    private var engagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("User Engagement")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 20) {
                // Active Users Chart
                ChartContainer(title: "Active Users", subtitle: "Daily active user count") {
                    Chart(filteredEngagementData()) { metric in
                        BarMark(
                            x: .value("Date", metric.date, unit: .day),
                            y: .value("Users", metric.activeUsers)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                
                // Feature Usage
                ChartContainer(title: "Feature Usage", subtitle: "Popular features") {
                    if let latestEngagement = analyticsService.userEngagementData.last {
                        Chart(latestEngagement.featureUsage) { feature in
                            BarMark(
                                x: .value("Feature", feature.featureName),
                                y: .value("Usage", feature.usageCount)
                            )
                            .foregroundStyle(.purple)
                        }
                        .chartAngleSelection(value: .constant(nil))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Search Analytics Section
    private var searchAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Search Analytics")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 20) {
                // Search Volume and Success Rate
                HStack(spacing: 16) {
                    ChartContainer(title: "Search Volume", subtitle: "Daily searches") {
                        Chart(filteredSearchAnalytics()) { analytic in
                            BarMark(
                                x: .value("Date", analytic.date, unit: .day),
                                y: .value("Searches", analytic.totalSearches)
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                    
                    ChartContainer(title: "Success Rate", subtitle: "Search effectiveness") {
                        Chart(filteredSearchAnalytics()) { analytic in
                            LineMark(
                                x: .value("Date", analytic.date),
                                y: .value("Rate", analytic.successRate * 100)
                            )
                            .foregroundStyle(.green)
                            .interpolationMethod(.catmullRom)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text("\(Int(doubleValue))%")
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Top Queries
                if let latestSearch = analyticsService.searchAnalytics.last {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Search Queries")
                            .font(.headline)
                        
                        ForEach(latestSearch.topQueries.prefix(5)) { query in
                            HStack {
                                Text(query.query)
                                    .font(.body)
                                Spacer()
                                Text("\(query.frequency)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Collaboration Section
    private var collaborationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Collaboration Metrics")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 20) {
                // Active Sessions Chart
                ChartContainer(title: "Active Sessions", subtitle: "Collaborative activity") {
                    Chart(filteredCollaborationData()) { metric in
                        BarMark(
                            x: .value("Date", metric.date, unit: .day),
                            y: .value("Sessions", metric.activeSessions)
                        )
                        .foregroundStyle(.purple)
                    }
                }
                
                // Collaboration Metrics Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    if let latest = analyticsService.collaborationMetrics.last {
                        SmallMetricCard(
                            title: "Collaborators",
                            value: "\(latest.totalCollaborators)",
                            color: .blue
                        )
                        
                        SmallMetricCard(
                            title: "Documents Shared",
                            value: "\(latest.documentsShared)",
                            color: .green
                        )
                        
                        SmallMetricCard(
                            title: "Avg Session",
                            value: formatDuration(latest.averageSessionDuration),
                            color: .orange
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - System Health Section
    private var systemHealthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Health")
                .font(.title2)
                .fontWeight(.semibold)
            
            let systemHealth = analyticsService.getSystemHealth()
            
            VStack(spacing: 16) {
                // Overall Status
                HStack {
                    Image(systemName: systemHealth.overallStatus.iconName)
                        .foregroundColor(systemHealth.overallStatus.color)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("Overall System Status")
                            .font(.headline)
                        Text(systemHealth.overallStatus.displayName)
                            .font(.subheadline)
                            .foregroundColor(systemHealth.overallStatus.color)
                    }
                    
                    Spacer()
                    
                    Text("Last checked: \(systemHealth.lastChecked, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(systemHealth.overallStatus.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Service Status Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ServiceStatusCard(
                        title: "Search Service",
                        status: systemHealth.searchService
                    )
                    
                    ServiceStatusCard(
                        title: "Collaboration",
                        status: systemHealth.collaborationService
                    )
                    
                    ServiceStatusCard(
                        title: "Analytics",
                        status: systemHealth.analyticsService
                    )
                    
                    ServiceStatusCard(
                        title: "Performance",
                        status: systemHealth.performance
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Insights Section
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Insights & Recommendations")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingInsightsDetail = true
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            let insights = analyticsService.getPerformanceInsights()
            
            if insights.isEmpty {
                Text("No insights available at this time")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(insights.prefix(3)) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Trending Section
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trending Content")
                .font(.title2)
                .fontWeight(.semibold)
            
            let trending = analyticsService.getTrendingInsights()
            
            VStack(spacing: 16) {
                // Popular Queries
                if !trending.popularQueries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Popular Searches")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(trending.popularQueries.prefix(5)) { query in
                                    VStack {
                                        Text(query.query)
                                            .font(.caption)
                                            .lineLimit(2)
                                        Text("\(query.frequency)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Trending Topics
                if !trending.trendingTopics.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trending Topics")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(trending.trendingTopics.prefix(3)) { topic in
                                VStack {
                                    Text(topic.category)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("\(topic.viewCount) views")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color(.systemBlue).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Helper Methods
private extension AnalyticsDashboardView {
    func filteredPerformanceData(_ type: PerformanceMetric.MetricType) -> [PerformanceMetric] {
        let filtered = analyticsService.performanceData.filter { $0.type == type }
        return Array(filtered.suffix(selectedTimeRange.dataPointCount))
    }
    
    func filteredEngagementData() -> [EngagementMetric] {
        return Array(analyticsService.userEngagementData.suffix(selectedTimeRange.dataPointCount))
    }
    
    func filteredSearchAnalytics() -> [SearchAnalytic] {
        return Array(analyticsService.searchAnalytics.suffix(selectedTimeRange.dataPointCount))
    }
    
    func filteredCollaborationData() -> [CollaborationMetric] {
        return Array(analyticsService.collaborationMetrics.suffix(selectedTimeRange.dataPointCount))
    }
    
    func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .abbreviated
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value * 100)
    }
    
    func formatDuration(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.minute, .second]
        return formatter.string(from: seconds) ?? "\(Int(seconds))s"
    }
}

// MARK: - Supporting Views

struct CategoryFilterChip: View {
    let category: MetricCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let trend: TrendDirection
    let trendValue: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: trend.iconName)
                    .foregroundColor(trend.color)
                    .font(.caption)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            HStack {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(trendValue)
                    .font(.caption2)
                    .foregroundColor(trend.color)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SmallMetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ChartContainer<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content
    
    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            content
                .frame(height: 200)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ServiceStatusCard: View {
    let title: String
    let status: HealthStatus
    
    var body: some View {
        HStack {
            Image(systemName: status.iconName)
                .foregroundColor(status.color)
                .font(.title3)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(status.displayName)
                    .font(.caption2)
                    .foregroundColor(status.color)
            }
            
            Spacer()
        }
        .padding(8)
        .background(status.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct InsightCard: View {
    let insight: PerformanceInsight
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.severity.iconName)
                .foregroundColor(insight.severity.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if insight.actionable {
                    Text(insight.recommendation)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(insight.severity.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Supporting Enums and Extensions

enum TimeRange: String, CaseIterable {
    case last24Hours = "24h"
    case last7Days = "7d"
    case last30Days = "30d"
    case last90Days = "90d"
    
    var displayName: String {
        switch self {
        case .last24Hours: return "24 Hours"
        case .last7Days: return "7 Days"
        case .last30Days: return "30 Days"
        case .last90Days: return "90 Days"
        }
    }
    
    var dataPointCount: Int {
        switch self {
        case .last24Hours: return 24
        case .last7Days: return 7
        case .last30Days: return 30
        case .last90Days: return 90
        }
    }
}

enum MetricCategory: String, CaseIterable {
    case all = "all"
    case overview = "overview"
    case performance = "performance"
    case engagement = "engagement"
    case search = "search"
    case collaboration = "collaboration"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .overview: return "Overview"
        case .performance: return "Performance"
        case .engagement: return "Engagement"
        case .search: return "Search"
        case .collaboration: return "Collaboration"
        case .system: return "System"
        }
    }
}

enum TrendDirection {
    case up
    case down
    case stable
    
    var iconName: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .orange
        }
    }
}

extension HealthStatus {
    var iconName: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .unhealthy: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .healthy: return .green
        case .degraded: return .orange
        case .unhealthy: return .red
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .healthy: return .green.opacity(0.1)
        case .degraded: return .orange.opacity(0.1)
        case .unhealthy: return .red.opacity(0.1)
        }
    }
}

extension PerformanceInsight.Severity {
    var iconName: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .info: return .blue.opacity(0.1)
        case .warning: return .orange.opacity(0.1)
        case .error: return .red.opacity(0.1)
        }
    }
}

extension NumberFormatter {
    static let abbreviated: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.positiveSuffix = ""
        formatter.negativeSuffix = ""
        return formatter
    }()
}

// MARK: - Preview Support

struct AnalyticsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let mockAnalyticsService = AnalyticsService()
        let mockCollaborationService = CollaborationService(analyticsService: mockAnalyticsService)
        let mockSmartSearchService = SmartSearchService(analyticsService: mockAnalyticsService)
        let mockPersonalizationEngine = PersonalizationEngine(analyticsService: mockAnalyticsService)
        
        let dashboardService = AnalyticsDashboardService(
            analyticsService: mockAnalyticsService,
            collaborationService: mockCollaborationService,
            smartSearchService: mockSmartSearchService,
            personalizationEngine: mockPersonalizationEngine
        )
        
        AnalyticsDashboardView(analyticsService: dashboardService)
    }
}
