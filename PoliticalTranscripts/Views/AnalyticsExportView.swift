import SwiftUI

struct AnalyticsExportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var analyticsService: AnalyticsDashboardService
    
    @State private var selectedFormat: ExportFormat = .csv
    @State private var selectedTimeRange: ExportTimeRange = .last30Days
    @State private var includeMetrics = true
    @State private var includePerformance = true
    @State private var includeEngagement = true
    @State private var includeSearch = true
    @State private var includeCollaboration = true
    @State private var includeInsights = true
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Export Analytics Data")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Export your analytics data in various formats for further analysis or reporting.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Export Format Selection
                    formatSelectionSection
                    
                    // Time Range Selection
                    timeRangeSelectionSection
                    
                    // Data Categories
                    dataCategoriesSection
                    
                    // Export Preview
                    exportPreviewSection
                    
                    // Export Button
                    exportButtonSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Export Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let exportURL = exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
        }
    }
    
    // MARK: - Format Selection Section
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Format")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    FormatCard(
                        format: format,
                        isSelected: selectedFormat == format
                    ) {
                        selectedFormat = format
                    }
                }
            }
        }
    }
    
    // MARK: - Time Range Selection Section
    private var timeRangeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Time Range")
                .font(.headline)
            
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(ExportTimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            HStack {
                Text("From: \(selectedTimeRange.startDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("To: \(selectedTimeRange.endDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Data Categories Section
    private var dataCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Categories")
                .font(.headline)
            
            VStack(spacing: 12) {
                DataCategoryRow(
                    title: "Dashboard Metrics",
                    description: "Key performance indicators and summary statistics",
                    isSelected: $includeMetrics,
                    icon: "chart.bar.fill"
                )
                
                DataCategoryRow(
                    title: "Performance Data",
                    description: "System performance metrics and response times",
                    isSelected: $includePerformance,
                    icon: "speedometer"
                )
                
                DataCategoryRow(
                    title: "User Engagement",
                    description: "User activity, sessions, and feature usage",
                    isSelected: $includeEngagement,
                    icon: "person.2.fill"
                )
                
                DataCategoryRow(
                    title: "Search Analytics",
                    description: "Search queries, success rates, and trends",
                    isSelected: $includeSearch,
                    icon: "magnifyingglass"
                )
                
                DataCategoryRow(
                    title: "Collaboration Data",
                    description: "Team collaboration metrics and activity",
                    isSelected: $includeCollaboration,
                    icon: "person.3.fill"
                )
                
                DataCategoryRow(
                    title: "Insights & Recommendations",
                    description: "AI-generated insights and performance recommendations",
                    isSelected: $includeInsights,
                    icon: "lightbulb.fill"
                )
            }
        }
    }
    
    // MARK: - Export Preview Section
    private var exportPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Preview")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Format:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(selectedFormat.displayName)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Time Range:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(selectedTimeRange.displayName)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Categories:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(selectedCategoriesCount) selected")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Estimated Size:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(estimatedFileSize)
                        .foregroundColor(.secondary)
                }
                
                if selectedFormat == .pdf {
                    HStack {
                        Text("Pages:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("~\(estimatedPageCount) pages")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Export Button Section
    private var exportButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: performExport) {
                HStack {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    
                    Text(isExporting ? "Exporting..." : "Export Data")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedCategoriesCount > 0 ? Color.accentColor : Color(.systemGray4))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedCategoriesCount == 0 || isExporting)
            
            if exportURL != nil {
                Button("Share Export") {
                    showingShareSheet = true
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var selectedCategoriesCount: Int {
        var count = 0
        if includeMetrics { count += 1 }
        if includePerformance { count += 1 }
        if includeEngagement { count += 1 }
        if includeSearch { count += 1 }
        if includeCollaboration { count += 1 }
        if includeInsights { count += 1 }
        return count
    }
    
    private var estimatedFileSize: String {
        let baseSize = selectedCategoriesCount * 50 // KB per category
        let multiplier = selectedTimeRange.sizeMultiplier
        let totalSize = Double(baseSize) * multiplier
        
        if totalSize > 1024 {
            return String(format: "%.1f MB", totalSize / 1024)
        } else {
            return String(format: "%.0f KB", totalSize)
        }
    }
    
    private var estimatedPageCount: Int {
        return max(1, selectedCategoriesCount * 2)
    }
    
    // MARK: - Actions
    private func performExport() {
        guard selectedCategoriesCount > 0 else { return }
        
        isExporting = true
        errorMessage = nil
        
        Task {
            do {
                let dateRange = DateRange(
                    startDate: selectedTimeRange.startDate,
                    endDate: selectedTimeRange.endDate
                )
                
                let url = try await analyticsService.exportAnalytics(
                    timeRange: dateRange,
                    format: selectedFormat
                )
                
                await MainActor.run {
                    self.exportURL = url
                    self.isExporting = false
                    self.showingShareSheet = true
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to export data: \(error.localizedDescription)"
                    self.isExporting = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct FormatCard: View {
    let format: ExportFormat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: format.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                VStack(spacing: 2) {
                    Text(format.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(format.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DataCategoryRow: View {
    let title: String
    let description: String
    @Binding var isSelected: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isSelected)
                .labelsHidden()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Supporting Types

enum ExportTimeRange: String, CaseIterable {
    case last7Days = "7d"
    case last30Days = "30d"
    case last90Days = "90d"
    case lastYear = "1y"
    case allTime = "all"
    
    var displayName: String {
        switch self {
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        case .lastYear: return "Last Year"
        case .allTime: return "All Time"
        }
    }
    
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .last90Days:
            return calendar.date(byAdding: .day, value: -90, to: now) ?? now
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime:
            return calendar.date(byAdding: .year, value: -10, to: now) ?? now
        }
    }
    
    var endDate: Date {
        return Date()
    }
    
    var sizeMultiplier: Double {
        switch self {
        case .last7Days: return 0.5
        case .last30Days: return 1.0
        case .last90Days: return 2.0
        case .lastYear: return 5.0
        case .allTime: return 10.0
        }
    }
}

extension ExportFormat {
    var displayName: String {
        switch self {
        case .csv: return "CSV"
        case .json: return "JSON"
        case .pdf: return "PDF"
        case .excel: return "Excel"
        }
    }
    
    var description: String {
        switch self {
        case .csv: return "Comma-separated values"
        case .json: return "JavaScript Object Notation"
        case .pdf: return "Portable Document Format"
        case .excel: return "Microsoft Excel format"
        }
    }
    
    var iconName: String {
        switch self {
        case .csv: return "doc.text"
        case .json: return "curlybraces"
        case .pdf: return "doc.richtext"
        case .excel: return "tablecells"
        }
    }
}

// MARK: - Insights Detail View

struct InsightsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let insights: [PerformanceInsight]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(insights) { insight in
                        DetailedInsightCard(insight: insight)
                    }
                    
                    if insights.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "lightbulb")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Insights Available")
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Text("Your system is performing well with no actionable insights at this time.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Performance Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailedInsightCard: View {
    let insight: PerformanceInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: insight.severity.iconName)
                    .foregroundColor(insight.severity.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(insight.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(insight.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(insight.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(insight.severity.color.opacity(0.1))
                    .foregroundColor(insight.severity.color)
                    .clipShape(Capsule())
            }
            
            if insight.actionable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendation")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(insight.recommendation)
                        .font(.body)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

extension PerformanceInsight.InsightType {
    var displayName: String {
        switch self {
        case .performance: return "Performance"
        case .memory: return "Memory"
        case .engagement: return "Engagement"
        case .search: return "Search"
        case .collaboration: return "Collaboration"
        }
    }
}

// MARK: - Preview Support

struct AnalyticsExportView_Previews: PreviewProvider {
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
        
        AnalyticsExportView(analyticsService: dashboardService)
    }
}
