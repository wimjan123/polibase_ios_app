//
//  SmartSearchService.swift
//  PoliticalTranscripts
//
//  Advanced AI-powered search capabilities for intelligent query processing,
//  semantic understanding, and personalized content discovery.
//

import Foundation
import NaturalLanguage

/// AI-powered search service providing semantic query processing and intelligent suggestions
@MainActor
actor SmartSearchService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var recentSuggestions: [SearchSuggestion] = []
    @Published var personalizedTopics: [RelatedTopic] = []
    @Published var queryHistory: [QueryHistoryItem] = []
    @Published var isProcessing: Bool = false
    
    // MARK: - Private Properties
    private let nlProcessor = NLEmbedding.sentenceEmbedding(for: .english)
    private let cache = NSCache<NSString, CachedSearchResult>()
    private let userPreferences: UserPreferences
    private let analyticsService: AnalyticsService
    
    // MARK: - Configuration
    private struct Configuration {
        static let maxSuggestions = 10
        static let maxRelatedTopics = 8
        static let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
        static let semanticSimilarityThreshold: Double = 0.7
        static let autoCompleteDebounceInterval: TimeInterval = 0.3
    }
    
    // MARK: - Initialization
    init(userPreferences: UserPreferences, analyticsService: AnalyticsService) {
        self.userPreferences = userPreferences
        self.analyticsService = analyticsService
        self.setupCacheConfiguration()
    }
    
    // MARK: - Natural Language Query Processing
    
    /// Processes natural language queries and converts them to structured search requests
    /// - Parameter query: Raw user input in natural language
    /// - Returns: Structured search request with extracted entities and intent
    func processNaturalLanguageQuery(_ query: String) async -> SmartSearchRequest {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Track analytics
            await analyticsService.trackUserAction(.naturalLanguageQuery(query), context: .search)
            
            // Extract entities and intent
            let linguisticAnalysis = await analyzeLinguisticContent(query)
            let entityExtraction = await extractNamedEntities(query)
            let intentClassification = await classifySearchIntent(query)
            
            // Build smart search request
            let smartRequest = SmartSearchRequest(
                originalQuery: query,
                processedQuery: linguisticAnalysis.cleanedQuery,
                detectedSpeakers: entityExtraction.speakers,
                detectedTopics: entityExtraction.topics,
                detectedDates: entityExtraction.dateRanges,
                searchIntent: intentClassification,
                confidence: calculateOverallConfidence(
                    linguistic: linguisticAnalysis.confidence,
                    entity: entityExtraction.confidence,
                    intent: intentClassification.confidence
                ),
                suggestedFilters: await generateSuggestedFilters(from: entityExtraction),
                enhancedTerms: linguisticAnalysis.synonyms
            )
            
            // Cache result for future similar queries
            await cacheSmartSearchResult(query, smartRequest)
            
            return smartRequest
            
        } catch {
            // Fallback to basic search request
            return SmartSearchRequest.fallback(from: query)
        }
    }
    
    /// Generates intelligent auto-complete suggestions based on partial user input
    /// - Parameter partial: Partial search query
    /// - Returns: Array of contextually relevant search suggestions
    func generateAutoComplete(for partial: String) async -> [SearchSuggestion] {
        guard partial.count >= 2 else { return [] }
        
        // Check cache first
        if let cachedSuggestions = getCachedSuggestions(for: partial) {
            return cachedSuggestions
        }
        
        var suggestions: [SearchSuggestion] = []
        
        // 1. Historical query completion
        let historicalSuggestions = await generateHistoricalCompletions(partial)
        suggestions.append(contentsOf: historicalSuggestions)
        
        // 2. Speaker name completion
        let speakerSuggestions = await generateSpeakerCompletions(partial)
        suggestions.append(contentsOf: speakerSuggestions)
        
        // 3. Topic-based completion
        let topicSuggestions = await generateTopicCompletions(partial)
        suggestions.append(contentsOf: topicSuggestions)
        
        // 4. Trending query completion
        let trendingSuggestions = await generateTrendingCompletions(partial)
        suggestions.append(contentsOf: trendingSuggestions)
        
        // 5. Semantic completion using ML
        let semanticSuggestions = await generateSemanticCompletions(partial)
        suggestions.append(contentsOf: semanticSuggestions)
        
        // Sort by relevance and confidence
        let sortedSuggestions = suggestions
            .sorted { $0.confidence > $1.confidence }
            .prefix(Configuration.maxSuggestions)
            .map { $0 }
        
        // Cache for performance
        await cacheSuggestions(sortedSuggestions, for: partial)
        
        return sortedSuggestions
    }
    
    /// Discovers related topics based on current transcript or search context
    /// - Parameter transcript: Current transcript for context
    /// - Returns: Array of related topics with relevance scores
    func findRelatedTopics(for transcript: VideoModel) async -> [RelatedTopic] {
        do {
            // Extract key topics from transcript
            let primaryTopics = await extractPrimaryTopics(from: transcript)
            
            // Find semantically similar content
            let similarTranscripts = await findSimilarTranscripts(to: transcript)
            
            // Generate topic clusters
            let topicClusters = await generateTopicClusters(
                primary: primaryTopics,
                similar: similarTranscripts
            )
            
            // Personalize based on user preferences
            let personalizedTopics = await personalizeTopics(
                topicClusters,
                preferences: userPreferences
            )
            
            return personalizedTopics
                .sorted { $0.relevanceScore > $1.relevanceScore }
                .prefix(Configuration.maxRelatedTopics)
                .map { $0 }
            
        } catch {
            // Return fallback topics based on transcript category
            return generateFallbackTopics(for: transcript)
        }
    }
    
    /// Refines search queries based on context and user behavior patterns
    /// - Parameters:
    ///   - original: Original search query
    ///   - context: Current search context and filters
    /// - Returns: Refined query string with improved search terms
    func refineSearchQuery(_ original: String, with context: SearchContext) async -> String {
        
        // Analyze query quality and potential improvements
        let qualityAnalysis = await analyzeQueryQuality(original)
        
        guard qualityAnalysis.needsRefinement else {
            return original
        }
        
        var refinements: [String] = []
        
        // 1. Add context-based terms
        if let contextTerms = await generateContextualTerms(context) {
            refinements.append(contentsOf: contextTerms)
        }
        
        // 2. Expand with synonyms
        let synonymExpansions = await expandWithSynonyms(original)
        refinements.append(contentsOf: synonymExpansions)
        
        // 3. Add user preference terms
        let preferenceTerms = generatePreferenceBasedTerms(userPreferences)
        refinements.append(contentsOf: preferenceTerms)
        
        // 4. Temporal context enhancement
        if let temporalTerms = await addTemporalContext(original, context: context) {
            refinements.append(contentsOf: temporalTerms)
        }
        
        // Combine original with refinements intelligently
        let refinedQuery = combineQueryTerms(
            original: original,
            refinements: refinements,
            strategy: qualityAnalysis.recommendedStrategy
        )
        
        // Track refinement effectiveness
        await analyticsService.trackUserAction(
            .queryRefinement(original: original, refined: refinedQuery),
            context: .searchOptimization
        )
        
        return refinedQuery
    }
}

// MARK: - Supporting Types

/// Comprehensive search request with AI-enhanced understanding
struct SmartSearchRequest: Codable {
    let originalQuery: String
    let processedQuery: String
    let detectedSpeakers: [String]
    let detectedTopics: [String]
    let detectedDates: [DateRange]
    let searchIntent: SearchIntent
    let confidence: Double
    let suggestedFilters: [SuggestedFilter]
    let enhancedTerms: [String]
    let timestamp: Date = Date()
    
    /// Creates a fallback request when AI processing fails
    static func fallback(from query: String) -> SmartSearchRequest {
        return SmartSearchRequest(
            originalQuery: query,
            processedQuery: query,
            detectedSpeakers: [],
            detectedTopics: [],
            detectedDates: [],
            searchIntent: .general,
            confidence: 0.5,
            suggestedFilters: [],
            enhancedTerms: []
        )
    }
}

/// Intelligent search suggestion with context and confidence
struct SearchSuggestion: Codable, Identifiable, Hashable {
    let id: UUID = UUID()
    let text: String
    let category: SuggestionCategory
    let confidence: Double
    let previewCount: Int?
    let source: SuggestionSource
    let metadata: SuggestionMetadata?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(category)
    }
    
    static func == (lhs: SearchSuggestion, rhs: SearchSuggestion) -> Bool {
        lhs.text == rhs.text && lhs.category == rhs.category
    }
}

/// Categories for organizing search suggestions
enum SuggestionCategory: String, Codable, CaseIterable {
    case speaker = "speaker"
    case topic = "topic"
    case historical = "historical"
    case trending = "trending"
    case semantic = "semantic"
    case date = "date"
    case source = "source"
    
    var displayName: String {
        switch self {
        case .speaker: return "Speaker"
        case .topic: return "Topic"
        case .historical: return "Recent"
        case .trending: return "Trending"
        case .semantic: return "Related"
        case .date: return "Date"
        case .source: return "Source"
        }
    }
    
    var icon: String {
        switch self {
        case .speaker: return "person.circle"
        case .topic: return "tag.circle"
        case .historical: return "clock.circle"
        case .trending: return "chart.line.uptrend.xyaxis.circle"
        case .semantic: return "brain.head.profile"
        case .date: return "calendar.circle"
        case .source: return "building.2.circle"
        }
    }
}

/// Source of search suggestions for analytics and prioritization
enum SuggestionSource: String, Codable {
    case userHistory = "user_history"
    case globalTrends = "global_trends"
    case semanticAnalysis = "semantic_analysis"
    case entityExtraction = "entity_extraction"
    case contextualInference = "contextual_inference"
}

/// Additional metadata for enhanced suggestion presentation
struct SuggestionMetadata: Codable {
    let estimatedResults: Int?
    let lastUsed: Date?
    let popularityScore: Double?
    let semanticSimilarity: Double?
}

/// Related topic with relevance scoring
struct RelatedTopic: Codable, Identifiable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let relevanceScore: Double
    let transcriptCount: Int
    let category: String
    let keywords: [String]
    let recentActivity: Date?
}

/// Search intent classification for query optimization
enum SearchIntent: String, Codable, CaseIterable {
    case general = "general"
    case speakerSpecific = "speaker_specific"
    case topicResearch = "topic_research"
    case dateRangeQuery = "date_range"
    case comparative = "comparative"
    case factFinding = "fact_finding"
    case sentiment = "sentiment"
    
    var processingStrategy: String {
        switch self {
        case .general: return "broad_search"
        case .speakerSpecific: return "speaker_focused"
        case .topicResearch: return "topic_deep_dive"
        case .dateRangeQuery: return "temporal_analysis"
        case .comparative: return "comparative_analysis"
        case .factFinding: return "fact_verification"
        case .sentiment: return "sentiment_analysis"
        }
    }
}

/// Search context for query refinement
struct SearchContext: Codable {
    let currentFilters: [String: Any]
    let recentQueries: [String]
    let sessionDuration: TimeInterval
    let previousResults: [SearchResultModel]?
    let userLocation: String?
    let timeOfDay: String
    let deviceType: String
}

/// User query history item for pattern analysis
struct QueryHistoryItem: Codable, Identifiable {
    let id: UUID = UUID()
    let query: String
    let timestamp: Date
    let resultCount: Int
    let clickedResults: [String]
    let sessionContext: String?
}

/// Cached search result for performance optimization
private class CachedSearchResult: NSObject {
    let request: SmartSearchRequest
    let timestamp: Date
    
    init(request: SmartSearchRequest) {
        self.request = request
        self.timestamp = Date()
    }
    
    var isValid: Bool {
        Date().timeIntervalSince(timestamp) < 3600 // 1 hour cache
    }
}

// MARK: - Private Extensions

private extension SmartSearchService {
    
    func setupCacheConfiguration() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func analyzeLinguisticContent(_ query: String) async -> (cleanedQuery: String, confidence: Double, synonyms: [String]) {
        // Implementation for linguistic analysis
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let synonyms = await generateSynonyms(for: cleaned)
        return (cleaned, 0.8, synonyms)
    }
    
    func extractNamedEntities(_ query: String) async -> (speakers: [String], topics: [String], dateRanges: [DateRange], confidence: Double) {
        // Implementation for named entity extraction
        return ([], [], [], 0.7)
    }
    
    func classifySearchIntent(_ query: String) async -> (intent: SearchIntent, confidence: Double) {
        // Implementation for intent classification
        return (.general, 0.6)
    }
    
    func calculateOverallConfidence(linguistic: Double, entity: Double, intent: Double) -> Double {
        return (linguistic + entity + intent) / 3.0
    }
    
    func generateSuggestedFilters(from extraction: (speakers: [String], topics: [String], dateRanges: [DateRange], confidence: Double)) async -> [SuggestedFilter] {
        // Implementation for filter suggestion
        return []
    }
    
    func cacheSmartSearchResult(_ query: String, _ request: SmartSearchRequest) async {
        let cached = CachedSearchResult(request: request)
        cache.setObject(cached, forKey: query as NSString)
    }
    
    func generateSynonyms(for term: String) async -> [String] {
        // Implementation for synonym generation
        return []
    }
}

/// Date range for temporal queries
struct DateRange: Codable {
    let start: Date?
    let end: Date?
    let description: String
}

/// Suggested filter based on AI analysis
struct SuggestedFilter: Codable {
    let category: String
    let values: [String]
    let confidence: Double
    let reasoning: String
}

/// User preferences for personalization
struct UserPreferences: Codable {
    var preferredSpeakers: [String]
    var preferredTopics: [String]
    var preferredSources: [String]
    var searchHistory: [String]
    var interactionPatterns: [String: Double]
}
