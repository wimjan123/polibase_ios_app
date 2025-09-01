import SwiftUI
import Combine

struct AdvancedSearchView: View {
    @StateObject private var advancedSearchIntelligence: AdvancedSearchIntelligence
    @StateObject private var searchViewModel: SearchViewModel
    @State private var searchText = ""
    @State private var showingSuggestions = false
    @State private var showingInsights = false
    @State private var selectedSuggestion: SearchSuggestion?
    @FocusState private var isSearchFieldFocused: Bool
    
    // MARK: - Initialization
    init(
        smartSearchService: SmartSearchService,
        analyticsService: AnalyticsService,
        personalizationEngine: PersonalizationEngine,
        searchViewModel: SearchViewModel
    ) {
        self._advancedSearchIntelligence = StateObject(wrappedValue: AdvancedSearchIntelligence(
            smartSearchService: smartSearchService,
            analyticsService: analyticsService,
            personalizationEngine: personalizationEngine
        ))
        self._searchViewModel = StateObject(wrappedValue: searchViewModel)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced Search Header
                searchHeader
                
                // Search Suggestions
                if showingSuggestions && !advancedSearchIntelligence.searchSuggestions.isEmpty {
                    suggestionsView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Main Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Search Insights
                        if showingInsights && !advancedSearchIntelligence.contextualInsights.isEmpty {
                            insightsSection
                        }
                        
                        // Search Trends
                        if !advancedSearchIntelligence.searchTrends.isEmpty {
                            trendsSection
                        }
                        
                        // Search Results
                        searchResultsSection
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Smart Search")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .onAppear {
                Task {
                    await advancedSearchIntelligence.updateSearchTrends()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var searchHeader: some View {
        VStack(spacing: 12) {
            // Enhanced Search Bar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search transcripts with AI assistance...", text: $searchText)
                        .focused($isSearchFieldFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { oldValue, newValue in
                            handleSearchTextChange(newValue)
                        }
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: clearSearch) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSearchFieldFocused ? Color.accentColor : Color(.systemGray4), lineWidth: 1)
                )
                
                // AI Enhancement Button
                Button(action: enhanceQuery) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.accentColor)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .disabled(searchText.isEmpty)
            }
            
            // Search Status
            if advancedSearchIntelligence.isAnalyzing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing with AI...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(advancedSearchIntelligence.searchSuggestions) { suggestion in
                suggestionRow(suggestion)
                    .onTapGesture {
                        selectSuggestion(suggestion)
                    }
                
                if suggestion.id != advancedSearchIntelligence.searchSuggestions.last?.id {
                    Divider()
                        .padding(.leading, 50)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private func suggestionRow(_ suggestion: SearchSuggestion) -> some View {
        HStack {
            // Type Icon
            Image(systemName: suggestion.type.icon)
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.text)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(suggestion.context)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Confidence Indicator
            ConfidenceIndicator(confidence: suggestion.confidence)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                Text("Search Insights")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                Button("Hide") {
                    withAnimation {
                        showingInsights = false
                    }
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(advancedSearchIntelligence.contextualInsights) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, x: 0, y: 1)
    }
    
    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                Text("Search Trends")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(advancedSearchIntelligence.searchTrends) { trend in
                        TrendCard(trend: trend)
                            .onTapGesture {
                                searchText = trend.query
                                performSearch()
                            }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, x: 0, y: 1)
    }
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !searchViewModel.searchResults.isEmpty {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.blue)
                    Text("Search Results")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(searchViewModel.searchResults.count) results")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                LazyVStack(spacing: 8) {
                    ForEach(searchViewModel.searchResults) { result in
                        SearchResultCard(result: result)
                    }
                }
            } else if searchViewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Searching with AI enhancement...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, x: 0, y: 1)
    }
}

// MARK: - Helper Methods
private extension AdvancedSearchView {
    
    func handleSearchTextChange(_ newValue: String) {
        if newValue.isEmpty {
            withAnimation {
                showingSuggestions = false
            }
        } else if newValue.count >= 2 {
            withAnimation {
                showingSuggestions = true
            }
            
            Task {
                await advancedSearchIntelligence.generateSearchSuggestions(for: newValue)
            }
        }
    }
    
    func selectSuggestion(_ suggestion: SearchSuggestion) {
        searchText = suggestion.text
        selectedSuggestion = suggestion
        
        withAnimation {
            showingSuggestions = false
        }
        
        isSearchFieldFocused = false
        performSearch()
    }
    
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        withAnimation {
            showingSuggestions = false
            showingInsights = true
        }
        
        Task {
            // Optimize the query with AI
            let optimizedQuery = await advancedSearchIntelligence.optimizeSearchQuery(searchText)
            
            // Perform the search
            await searchViewModel.searchTranscripts(query: optimizedQuery)
            
            // Analyze the context
            await advancedSearchIntelligence.analyzeSearchContext(
                for: searchText,
                results: searchViewModel.searchResults
            )
        }
    }
    
    func enhanceQuery() {
        Task {
            let enhanced = await advancedSearchIntelligence.optimizeSearchQuery(searchText)
            await MainActor.run {
                searchText = enhanced
            }
        }
    }
    
    func clearSearch() {
        searchText = ""
        withAnimation {
            showingSuggestions = false
            showingInsights = false
        }
        searchViewModel.clearResults()
    }
}

// MARK: - Supporting Views

struct ConfidenceIndicator: View {
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(index < Int(confidence * 5) ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

struct InsightCard: View {
    let insight: ContextualInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: insight.type.icon)
                    .foregroundColor(colorForType(insight.type.color))
                    .frame(width: 16, height: 16)
                
                Text(insight.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if insight.actionable {
                    Image(systemName: "hand.tap")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }
            }
            
            Text(insight.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func colorForType(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        default: return .gray
        }
    }
}

struct TrendCard: View {
    let trend: SearchTrend
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: trend.direction.icon)
                    .foregroundColor(colorForDirection(trend.direction.color))
                    .font(.caption)
                
                Text("\(trend.frequency)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(trend.query)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Text(trend.timeframe)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(width: 120, height: 80)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func colorForDirection(_ colorString: String) -> Color {
        switch colorString {
        case "green": return .green
        case "red": return .red
        case "gray": return .gray
        default: return .gray
        }
    }
}

struct SearchResultCard: View {
    let result: SearchResultModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.title ?? "Untitled")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Spacer()
                
                if let date = result.date {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let speaker = result.speaker {
                HStack {
                    Image(systemName: "person.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text(speaker)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let content = result.content {
                Text(content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            
            HStack {
                if let category = result.category {
                    Label(category, systemImage: "tag")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                if let source = result.source {
                    Text(source)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview
#Preview {
    AdvancedSearchView(
        smartSearchService: SmartSearchService(apiClient: APIClient()),
        analyticsService: AnalyticsService(),
        personalizationEngine: PersonalizationEngine(analyticsService: AnalyticsService()),
        searchViewModel: SearchViewModel(apiClient: APIClient())
    )
}
