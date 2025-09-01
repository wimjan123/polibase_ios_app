//
//  SmartSearchView.swift
//  PoliticalTranscripts
//
//  Enhanced search interface integrating AI-powered features, personalization,
//  and intelligent recommendations for optimal user experience.
//

import SwiftUI

/// Enhanced search view with AI-powered smart features and personalization
struct SmartSearchView: View {
    
    // MARK: - Environment and State
    @StateObject private var searchViewModel = SearchViewModel()
    @StateObject private var smartSearchService = SmartSearchService(
        userPreferences: UserPreferences(),
        analyticsService: AnalyticsService()
    )
    @StateObject private var personalizationEngine = PersonalizationEngine(
        analyticsService: AnalyticsService()
    )
    
    @State private var searchText: String = ""
    @State private var isShowingFilters: Bool = false
    @State private var isShowingRecommendations: Bool = false
    @State private var selectedSuggestion: SearchSuggestion?
    @State private var showingSmartQuery: Bool = false
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Smart Search Header
                smartSearchHeader
                
                // Search Input with AI Enhancement
                intelligentSearchInput
                
                // Smart Suggestions
                if !smartSearchService.recentSuggestions.isEmpty {
                    smartSuggestionsSection
                }
                
                // Personalized Recommendations
                if !personalizationEngine.recommendations.isEmpty && searchText.isEmpty {
                    personalizedRecommendationsSection
                }
                
                // Search Results with Enhanced Display
                enhancedSearchResults
            }
            .navigationTitle("Smart Search")
            .navigationBarItems(
                leading: recommendationsButton,
                trailing: HStack {
                    adaptiveFiltersButton
                    smartFiltersButton
                }
            )
            .sheet(isPresented: $isShowingRecommendations) {
                PersonalizedDashboardView(personalizationEngine: personalizationEngine)
            }
            .sheet(isPresented: $isShowingFilters) {
                SmartFiltersView(
                    searchViewModel: searchViewModel,
                    adaptiveFilters: personalizationEngine.adaptiveFilters
                )
            }
        }
        .onAppear {
            initializeSmartFeatures()
        }
    }
    
    // MARK: - Smart Search Header
    private var smartSearchHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("AI-Powered Search")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if smartSearchService.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            
            // Quick Stats
            HStack(spacing: 20) {
                StatChip(
                    icon: "chart.line.uptrend.xyaxis",
                    value: "\(personalizationEngine.recommendations.count)",
                    label: "Personalized"
                )
                
                StatChip(
                    icon: "sparkles",
                    value: "\(smartSearchService.recentSuggestions.count)",
                    label: "Smart Tips"
                )
                
                StatChip(
                    icon: "slider.horizontal.3",
                    value: "\(personalizationEngine.adaptiveFilters.count)",
                    label: "Auto Filters"
                )
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Intelligent Search Input
    private var intelligentSearchInput: some View {
        VStack(spacing: 8) {
            HStack {
                // Search Input with Smart Processing
                TextField("Ask anything about political transcripts...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: searchText) { newValue in
                        handleSearchTextChange(newValue)
                    }
                    .onSubmit {
                        executeSmartSearch()
                    }
                
                // Voice Search Button
                Button(action: activateVoiceSearch) {
                    Image(systemName: "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                // Smart Query Enhancement Button
                Button(action: enhanceQuery) {
                    Image(systemName: "wand.and.stars")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
                .disabled(searchText.isEmpty)
            }
            .padding(.horizontal)
            
            // Natural Language Query Indicator
            if showingSmartQuery {
                smartQueryIndicator
            }
        }
    }
    
    // MARK: - Smart Query Indicator
    private var smartQueryIndicator: some View {
        HStack {
            Image(systemName: "brain")
                .foregroundColor(.purple)
                .font(.caption)
            
            Text("AI is enhancing your search...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            ProgressView()
                .scaleEffect(0.6)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    // MARK: - Smart Suggestions Section
    private var smartSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Smart Suggestions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Clear") {
                    clearSuggestions()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(smartSearchService.recentSuggestions) { suggestion in
                        SuggestionChip(suggestion: suggestion) {
                            applySuggestion(suggestion)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Personalized Recommendations
    private var personalizedRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.badge.plus")
                    .foregroundColor(.green)
                
                Text("Recommended for You")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("See All") {
                    isShowingRecommendations = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(personalizationEngine.recommendations.prefix(5))) { recommendation in
                        RecommendationCard(recommendation: recommendation) {
                            selectRecommendation(recommendation)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Enhanced Search Results
    private var enhancedSearchResults: some View {
        SearchResultsView(
            searchViewModel: searchViewModel,
            personalizationEngine: personalizationEngine
        )
    }
    
    // MARK: - Navigation Buttons
    private var recommendationsButton: some View {
        Button(action: { isShowingRecommendations = true }) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.title3)
        }
    }
    
    private var adaptiveFiltersButton: some View {
        Button(action: showAdaptiveFilters) {
            ZStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                
                if !personalizationEngine.adaptiveFilters.isEmpty {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
    
    private var smartFiltersButton: some View {
        Button(action: { isShowingFilters = true }) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.title3)
        }
    }
}

// MARK: - Supporting Views

/// Statistics chip for quick insights
struct StatChip: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
    }
}

/// Smart suggestion chip with category indication
struct SuggestionChip: View {
    let suggestion: SearchSuggestion
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: suggestion.category.icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(suggestion.text)
                    .font(.caption)
                    .lineLimit(1)
                
                if let count = suggestion.previewCount {
                    Text("(\(count))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Personalized recommendation card
struct RecommendationCard: View {
    let recommendation: SmartRecommendation
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 160, height: 90)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.transcript.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(recommendation.transcript.speaker)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Recommendation reason
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Text(recommendation.reason.displayText)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    }
                    
                    // Confidence indicator
                    HStack {
                        ProgressView(value: recommendation.confidence)
                            .frame(height: 2)
                            .tint(.green)
                        
                        Text("\(Int(recommendation.confidence * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 160, alignment: .leading)
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Enhanced search results view with personalization
struct SearchResultsView: View {
    @ObservedObject var searchViewModel: SearchViewModel
    @ObservedObject var personalizationEngine: PersonalizationEngine
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(searchViewModel.searchResults) { result in
                    EnhancedSearchResultRow(
                        result: result,
                        personalizedScore: getPersonalizedScore(for: result),
                        onTap: { selectResult(result) },
                        onBookmark: { bookmarkResult(result) },
                        onShare: { shareResult(result) }
                    )
                }
                
                // Load More Section
                if searchViewModel.hasMoreResults && !searchViewModel.isLoadingMore {
                    Button("Load More Results") {
                        loadMoreResults()
                    }
                    .padding()
                }
                
                if searchViewModel.isLoadingMore {
                    ProgressView("Loading more results...")
                        .padding()
                }
            }
            .padding()
        }
    }
    
    private func getPersonalizedScore(for result: SearchResultModel) -> Double {
        // Calculate personalized relevance score
        return 0.8 // Placeholder
    }
    
    private func selectResult(_ result: SearchResultModel) {
        // Handle result selection with analytics
        Task {
            let interaction = UserInteraction(
                type: .view,
                contentId: result.id.uuidString,
                query: nil,
                duration: nil,
                context: "search_results",
                metadata: nil
            )
            await personalizationEngine.learnFromUserInteraction(interaction)
        }
    }
    
    private func bookmarkResult(_ result: SearchResultModel) {
        // Handle bookmark action
        Task {
            let interaction = UserInteraction(
                type: .bookmark,
                contentId: result.id.uuidString,
                query: nil,
                duration: nil,
                context: "search_results",
                metadata: nil
            )
            await personalizationEngine.learnFromUserInteraction(interaction)
        }
    }
    
    private func shareResult(_ result: SearchResultModel) {
        // Handle share action
        Task {
            let interaction = UserInteraction(
                type: .share,
                contentId: result.id.uuidString,
                query: nil,
                duration: nil,
                context: "search_results",
                metadata: nil
            )
            await personalizationEngine.learnFromUserInteraction(interaction)
        }
    }
    
    private func loadMoreResults() {
        searchViewModel.loadMoreResults()
    }
}

/// Enhanced search result row with personalization indicators
struct EnhancedSearchResultRow: View {
    let result: SearchResultModel
    let personalizedScore: Double
    let onTap: () -> Void
    let onBookmark: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: result.thumbnailURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "play.circle")
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 80, height: 60)
                .cornerRadius(8)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(result.speaker)
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    if let snippet = result.snippet {
                        Text(snippet)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text(result.date, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Personalization indicator
                        if personalizedScore > 0.7 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                
                                Text("For You")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 8) {
                    Button(action: onBookmark) {
                        Image(systemName: "bookmark")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - SmartSearchView Extensions

private extension SmartSearchView {
    
    func initializeSmartFeatures() {
        Task {
            // Initialize personalization engine
            _ = await personalizationEngine.generatePersonalizedRecommendations()
            
            // Initialize adaptive filters
            _ = await personalizationEngine.generateAdaptiveFilters()
        }
    }
    
    func handleSearchTextChange(_ newValue: String) {
        Task {
            if newValue.count >= 2 {
                let suggestions = await smartSearchService.generateAutoComplete(for: newValue)
                await MainActor.run {
                    // Update suggestions
                }
            }
        }
    }
    
    func executeSmartSearch() {
        guard !searchText.isEmpty else { return }
        
        showingSmartQuery = true
        
        Task {
            // Process natural language query
            let smartRequest = await smartSearchService.processNaturalLanguageQuery(searchText)
            
            // Execute search with enhanced request
            await searchViewModel.executeSmartSearch(smartRequest)
            
            // Learn from search behavior
            let interaction = UserInteraction(
                type: .search,
                contentId: nil,
                query: searchText,
                duration: nil,
                context: "smart_search",
                metadata: nil
            )
            await personalizationEngine.learnFromUserInteraction(interaction)
            
            await MainActor.run {
                showingSmartQuery = false
            }
        }
    }
    
    func activateVoiceSearch() {
        // Implement voice search functionality
    }
    
    func enhanceQuery() {
        Task {
            let context = SearchContext(
                currentFilters: [:],
                recentQueries: [],
                sessionDuration: 0,
                previousResults: nil,
                userLocation: nil,
                timeOfDay: "morning",
                deviceType: "iPhone"
            )
            
            let refinedQuery = await smartSearchService.refineSearchQuery(searchText, with: context)
            
            await MainActor.run {
                searchText = refinedQuery
            }
        }
    }
    
    func clearSuggestions() {
        // Clear suggestions
    }
    
    func applySuggestion(_ suggestion: SearchSuggestion) {
        searchText = suggestion.text
        executeSmartSearch()
    }
    
    func selectRecommendation(_ recommendation: SmartRecommendation) {
        // Navigate to recommended content
        Task {
            let interaction = UserInteraction(
                type: .view,
                contentId: recommendation.transcript.id.uuidString,
                query: nil,
                duration: nil,
                context: "recommendation",
                metadata: nil
            )
            await personalizationEngine.learnFromUserInteraction(interaction)
        }
    }
    
    func showAdaptiveFilters() {
        // Show adaptive filters interface
    }
}

// MARK: - SearchViewModel Extension

extension SearchViewModel {
    func executeSmartSearch(_ smartRequest: SmartSearchRequest) async {
        // Convert smart request to regular search request and execute
        let searchRequest = SearchRequest(
            query: smartRequest.processedQuery,
            speakers: smartRequest.detectedSpeakers,
            sources: nil,
            categories: nil,
            languages: nil,
            tags: smartRequest.detectedTopics,
            startDate: smartRequest.detectedDates.first?.start,
            endDate: smartRequest.detectedDates.first?.end,
            minDuration: nil,
            maxDuration: nil,
            page: 1,
            pageSize: 20,
            sortBy: "relevance",
            sortOrder: "desc"
        )
        
        await search(with: searchRequest)
    }
}
