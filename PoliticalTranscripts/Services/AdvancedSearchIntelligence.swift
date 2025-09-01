import Foundation
import Combine
import NaturalLanguage
import CoreML

@MainActor
class AdvancedSearchIntelligence: ObservableObject {
    
    // MARK: - Published Properties
    @Published var searchSuggestions: [SearchSuggestion] = []
    @Published var contextualInsights: [ContextualInsight] = []
    @Published var searchTrends: [SearchTrend] = []
    @Published var isAnalyzing: Bool = false
    @Published var lastAnalysisTimestamp: Date?
    
    // MARK: - Dependencies
    private let smartSearchService: SmartSearchService
    private let analyticsService: AnalyticsService
    private let personalizationEngine: PersonalizationEngine
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let nlProcessor = NLEmbedding.sentenceEmbedding(for: .english)
    private var searchHistory: [HistoricalSearch] = []
    private var contextCache: [String: [ContextualInsight]] = [:]
    
    // MARK: - Configuration
    private struct Config {
        static let maxSuggestions = 10
        static let maxInsights = 5
        static let cacheExpirationMinutes = 30
        static let minQueryLength = 3
        static let maxSearchHistory = 1000
    }
    
    // MARK: - Initialization
    init(
        smartSearchService: SmartSearchService,
        analyticsService: AnalyticsService,
        personalizationEngine: PersonalizationEngine
    ) {
        self.smartSearchService = smartSearchService
        self.analyticsService = analyticsService
        self.personalizationEngine = personalizationEngine
        
        setupSubscriptions()
        loadSearchHistory()
    }
    
    // MARK: - Public Methods
    
    /// Generate intelligent search suggestions based on partial query
    func generateSearchSuggestions(for partialQuery: String) async {
        guard partialQuery.count >= Config.minQueryLength else {
            await MainActor.run {
                searchSuggestions = []
            }
            return
        }
        
        isAnalyzing = true
        
        do {
            // Combine multiple suggestion sources
            let semanticSuggestions = await generateSemanticSuggestions(for: partialQuery)
            let historicalSuggestions = generateHistoricalSuggestions(for: partialQuery)
            let trendingSuggestions = await generateTrendingSuggestions(for: partialQuery)
            let personalizedSuggestions = await generatePersonalizedSuggestions(for: partialQuery)
            
            // Merge and rank suggestions
            let allSuggestions = semanticSuggestions + historicalSuggestions + trendingSuggestions + personalizedSuggestions
            let rankedSuggestions = rankSuggestions(allSuggestions, for: partialQuery)
            
            await MainActor.run {
                self.searchSuggestions = Array(rankedSuggestions.prefix(Config.maxSuggestions))
                self.isAnalyzing = false
            }
            
            // Track suggestion generation
            await analyticsService.trackEvent("search_suggestions_generated", parameters: [
                "query_length": partialQuery.count,
                "suggestions_count": rankedSuggestions.count,
                "partial_query": partialQuery.prefix(50).description
            ])
            
        } catch {
            await MainActor.run {
                self.isAnalyzing = false
            }
            print("Error generating search suggestions: \(error)")
        }
    }
    
    /// Analyze search context and provide insights
    func analyzeSearchContext(for query: String, results: [SearchResultModel]) async {
        // Check cache first
        if let cachedInsights = contextCache[query],
           let lastAnalysis = lastAnalysisTimestamp,
           Date().timeIntervalSince(lastAnalysis) < TimeInterval(Config.cacheExpirationMinutes * 60) {
            await MainActor.run {
                self.contextualInsights = cachedInsights
            }
            return
        }
        
        isAnalyzing = true
        
        do {
            let insights = await generateContextualInsights(query: query, results: results)
            
            await MainActor.run {
                self.contextualInsights = insights
                self.lastAnalysisTimestamp = Date()
                self.isAnalyzing = false
            }
            
            // Cache the insights
            contextCache[query] = insights
            
            // Update search history
            recordSearch(query: query, resultsCount: results.count, insights: insights)
            
            // Track context analysis
            await analyticsService.trackEvent("search_context_analyzed", parameters: [
                "query": query.prefix(100).description,
                "results_count": results.count,
                "insights_generated": insights.count
            ])
            
        } catch {
            await MainActor.run {
                self.isAnalyzing = false
            }
            print("Error analyzing search context: \(error)")
        }
    }
    
    /// Get search trends and popular queries
    func updateSearchTrends() async {
        do {
            let trends = await analyzeSearchTrends()
            
            await MainActor.run {
                self.searchTrends = trends
            }
            
            await analyticsService.trackEvent("search_trends_updated", parameters: [
                "trends_count": trends.count
            ])
            
        } catch {
            print("Error updating search trends: \(error)")
        }
    }
    
    /// Provide query completion suggestions
    func getQueryCompletions(for partialQuery: String) -> [String] {
        let normalizedQuery = partialQuery.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Historical completions
        let historicalCompletions = searchHistory
            .filter { $0.query.lowercased().hasPrefix(normalizedQuery) }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(5)
            .map { $0.query }
        
        // Common political terms completions
        let commonCompletions = generateCommonCompletions(for: normalizedQuery)
        
        // Combine and deduplicate
        let allCompletions = Array(Set(historicalCompletions + commonCompletions))
        return Array(allCompletions.prefix(8))
    }
    
    /// Optimize search query using AI enhancement
    func optimizeSearchQuery(_ originalQuery: String) async -> String {
        do {
            let optimizedQuery = await enhanceQueryWithAI(originalQuery)
            
            await analyticsService.trackEvent("search_query_optimized", parameters: [
                "original_query": originalQuery.prefix(100).description,
                "optimized_query": optimizedQuery.prefix(100).description,
                "improvement_detected": optimizedQuery != originalQuery
            ])
            
            return optimizedQuery
            
        } catch {
            print("Error optimizing search query: \(error)")
            return originalQuery
        }
    }
}

// MARK: - Private Methods
private extension AdvancedSearchIntelligence {
    
    func setupSubscriptions() {
        // Clean expired cache periodically
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                self?.cleanExpiredCache()
            }
            .store(in: &cancellables)
    }
    
    func generateSemanticSuggestions(for query: String) async -> [SearchSuggestion] {
        guard let embedding = nlProcessor?.vector(for: query) else {
            return []
        }
        
        // Semantic similarity with common political queries
        let semanticMatches = findSemanticMatches(for: embedding)
        
        return semanticMatches.map { match in
            SearchSuggestion(
                text: match.query,
                type: .semantic,
                confidence: match.similarity,
                context: "Based on semantic similarity"
            )
        }
    }
    
    func generateHistoricalSuggestions(for query: String) -> [SearchSuggestion] {
        let normalizedQuery = query.lowercased()
        
        let historicalMatches = searchHistory
            .filter { $0.query.lowercased().contains(normalizedQuery) || normalizedQuery.contains($0.query.lowercased()) }
            .sorted { $0.frequency > $1.frequency }
            .prefix(3)
        
        return historicalMatches.map { search in
            SearchSuggestion(
                text: search.query,
                type: .historical,
                confidence: min(Double(search.frequency) / 10.0, 1.0),
                context: "From your search history"
            )
        }
    }
    
    func generateTrendingSuggestions(for query: String) async -> [SearchSuggestion] {
        // Simulate trending topics based on current events
        let trendingTopics = [
            "climate policy", "healthcare reform", "economic recovery",
            "foreign relations", "immigration policy", "education funding",
            "infrastructure investment", "social security", "tax policy"
        ]
        
        let matchingTrends = trendingTopics.filter { topic in
            topic.lowercased().contains(query.lowercased()) ||
            query.lowercased().contains(topic.lowercased())
        }
        
        return matchingTrends.map { trend in
            SearchSuggestion(
                text: trend,
                type: .trending,
                confidence: 0.8,
                context: "Currently trending"
            )
        }
    }
    
    func generatePersonalizedSuggestions(for query: String) async -> [SearchSuggestion] {
        do {
            let userPreferences = await personalizationEngine.getUserPreferences()
            let interests = userPreferences.preferredTopics
            
            let personalizedMatches = interests.filter { interest in
                interest.lowercased().contains(query.lowercased()) ||
                query.lowercased().contains(interest.lowercased())
            }
            
            return personalizedMatches.map { match in
                SearchSuggestion(
                    text: match,
                    type: .personalized,
                    confidence: 0.9,
                    context: "Based on your interests"
                )
            }
        } catch {
            return []
        }
    }
    
    func rankSuggestions(_ suggestions: [SearchSuggestion], for query: String) -> [SearchSuggestion] {
        return suggestions
            .sorted { first, second in
                // Prioritize by type
                let typeScore1 = typeScore(for: first.type)
                let typeScore2 = typeScore(for: second.type)
                
                if typeScore1 != typeScore2 {
                    return typeScore1 > typeScore2
                }
                
                // Then by confidence
                return first.confidence > second.confidence
            }
            .removingDuplicates { $0.text.lowercased() == $1.text.lowercased() }
    }
    
    func typeScore(for type: SearchSuggestionType) -> Double {
        switch type {
        case .personalized: return 4.0
        case .trending: return 3.0
        case .semantic: return 2.0
        case .historical: return 1.0
        }
    }
    
    func generateContextualInsights(query: String, results: [SearchResultModel]) async -> [ContextualInsight] {
        var insights: [ContextualInsight] = []
        
        // Analyze temporal patterns
        if let temporalInsight = analyzeTemporalPatterns(in: results) {
            insights.append(temporalInsight)
        }
        
        // Analyze speaker patterns
        if let speakerInsight = analyzeSpeakerPatterns(in: results) {
            insights.append(speakerInsight)
        }
        
        // Analyze topic patterns
        if let topicInsight = analyzeTopicPatterns(in: results, query: query) {
            insights.append(topicInsight)
        }
        
        // Analyze sentiment patterns
        if let sentimentInsight = analyzeSentimentPatterns(in: results) {
            insights.append(sentimentInsight)
        }
        
        // Analyze cross-references
        if let crossRefInsight = analyzeCrossReferences(in: results) {
            insights.append(crossRefInsight)
        }
        
        return Array(insights.prefix(Config.maxInsights))
    }
    
    func analyzeTemporalPatterns(in results: [SearchResultModel]) -> ContextualInsight? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let dates = results.compactMap { $0.date }
        guard !dates.isEmpty else { return nil }
        
        let sortedDates = dates.sorted()
        let earliestDate = sortedDates.first!
        let latestDate = sortedDates.last!
        
        let timeSpan = latestDate.timeIntervalSince(earliestDate)
        let timeDescription = timeSpan < 86400 ? "single day" :
                             timeSpan < 604800 ? "single week" :
                             timeSpan < 2592000 ? "single month" : "extended period"
        
        return ContextualInsight(
            type: .temporal,
            title: "Timeline Analysis",
            description: "Results span a \(timeDescription) from \(dateFormatter.string(from: earliestDate)) to \(dateFormatter.string(from: latestDate))",
            confidence: 0.9,
            actionable: false
        )
    }
    
    func analyzeSpeakerPatterns(in results: [SearchResultModel]) -> ContextualInsight? {
        let speakers = results.compactMap { $0.speaker }
        guard !speakers.isEmpty else { return nil }
        
        let speakerCounts = Dictionary(grouping: speakers, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        let topSpeaker = speakerCounts.first!
        let percentage = Double(topSpeaker.value) / Double(speakers.count) * 100
        
        return ContextualInsight(
            type: .speaker,
            title: "Speaker Analysis",
            description: "\(topSpeaker.key) appears in \(Int(percentage))% of results (\(topSpeaker.value) out of \(speakers.count))",
            confidence: 0.8,
            actionable: true
        )
    }
    
    func analyzeTopicPatterns(in results: [SearchResultModel], query: String) -> ContextualInsight? {
        let topics = results.compactMap { $0.category }
        guard !topics.isEmpty else { return nil }
        
        let topicCounts = Dictionary(grouping: topics, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        let dominantTopic = topicCounts.first!
        let relatedTopics = topicCounts.prefix(3).map { $0.key }
        
        return ContextualInsight(
            type: .topic,
            title: "Topic Distribution",
            description: "Primary focus on \(dominantTopic.key). Related topics: \(relatedTopics.joined(separator: ", "))",
            confidence: 0.85,
            actionable: true
        )
    }
    
    func analyzeSentimentPatterns(in results: [SearchResultModel]) -> ContextualInsight? {
        // Simplified sentiment analysis using NaturalLanguage framework
        let sentimentAnalyzer = NLSentimentPredictor()
        let contents = results.compactMap { $0.content }
        
        guard !contents.isEmpty else { return nil }
        
        var positiveCount = 0
        var negativeCount = 0
        var neutralCount = 0
        
        for content in contents.prefix(10) { // Analyze first 10 for performance
            let sentiment = sentimentAnalyzer.predict(content)
            
            switch sentiment {
            case .positive:
                positiveCount += 1
            case .negative:
                negativeCount += 1
            case .neutral:
                neutralCount += 1
            }
        }
        
        let total = positiveCount + negativeCount + neutralCount
        let dominantSentiment = max(positiveCount, negativeCount, neutralCount)
        let sentimentLabel = dominantSentiment == positiveCount ? "positive" :
                            dominantSentiment == negativeCount ? "negative" : "neutral"
        
        return ContextualInsight(
            type: .sentiment,
            title: "Sentiment Analysis",
            description: "Overall tone is \(sentimentLabel) (\(Int(Double(dominantSentiment)/Double(total)*100))% of analyzed content)",
            confidence: 0.7,
            actionable: false
        )
    }
    
    func analyzeCrossReferences(in results: [SearchResultModel]) -> ContextualInsight? {
        let sources = results.compactMap { $0.source }
        let uniqueSources = Set(sources)
        
        guard uniqueSources.count > 1 else { return nil }
        
        return ContextualInsight(
            type: .crossReference,
            title: "Source Diversity",
            description: "Information from \(uniqueSources.count) different sources, providing multiple perspectives",
            confidence: 0.8,
            actionable: true
        )
    }
    
    func analyzeSearchTrends() async -> [SearchTrend] {
        // Analyze recent search history for trends
        let recentSearches = searchHistory
            .filter { $0.timestamp.timeIntervalSinceNow > -7 * 24 * 3600 } // Last 7 days
            .sorted { $0.timestamp > $1.timestamp }
        
        let searchTerms = Dictionary(grouping: recentSearches, by: { $0.query.lowercased() })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(10)
        
        return searchTerms.map { term, frequency in
            let trend = frequency > 1 ? SearchTrendDirection.rising : .stable
            return SearchTrend(
                query: term,
                frequency: frequency,
                direction: trend,
                timeframe: "7 days"
            )
        }
    }
    
    func enhanceQueryWithAI(_ query: String) async -> String {
        // Simple query enhancement using natural language processing
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = query
        
        var enhancedTerms: [String] = []
        var currentTerms = query.components(separatedBy: .whitespaces)
        
        // Identify named entities and important terms
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if let tag = tag, tag != .other {
                let term = String(query[tokenRange])
                if !enhancedTerms.contains(term.lowercased()) {
                    enhancedTerms.append(term)
                }
            }
            return true
        }
        
        // Add political context if missing
        let politicalTerms = ["policy", "legislation", "congress", "senate", "house"]
        let hasContext = politicalTerms.contains { term in
            query.lowercased().contains(term)
        }
        
        if !hasContext && !query.lowercased().contains("politics") {
            // Add contextual terms for better search results
            if query.contains("healthcare") {
                currentTerms.append("policy")
            } else if query.contains("economy") {
                currentTerms.append("legislation")
            }
        }
        
        return currentTerms.joined(separator: " ")
    }
    
    func findSemanticMatches(for embedding: [Double]) -> [(query: String, similarity: Double)] {
        // Simulate semantic matching with common political queries
        let commonQueries = [
            "healthcare reform policies", "economic recovery plans", "climate change legislation",
            "foreign policy decisions", "immigration reform", "education funding",
            "infrastructure investment", "social security reform", "tax policy changes"
        ]
        
        return commonQueries.compactMap { query in
            guard let queryEmbedding = nlProcessor?.vector(for: query) else { return nil }
            let similarity = cosineSimilarity(embedding, queryEmbedding)
            return similarity > 0.7 ? (query: query, similarity: similarity) : nil
        }.sorted { $0.similarity > $1.similarity }
    }
    
    func cosineSimilarity(_ vectorA: [Double], _ vectorB: [Double]) -> Double {
        guard vectorA.count == vectorB.count else { return 0.0 }
        
        let dotProduct = zip(vectorA, vectorB).map(*).reduce(0, +)
        let magnitudeA = sqrt(vectorA.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(vectorB.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    func generateCommonCompletions(for query: String) -> [String] {
        let commonPoliticalTerms = [
            "healthcare policy", "economic policy", "foreign policy", "immigration policy",
            "climate change", "education reform", "infrastructure bill", "tax reform",
            "social security", "medicare", "defense spending", "trade policy"
        ]
        
        return commonPoliticalTerms.filter { term in
            term.lowercased().hasPrefix(query.lowercased())
        }
    }
    
    func recordSearch(query: String, resultsCount: Int, insights: [ContextualInsight]) {
        // Update existing or create new search record
        if let existingIndex = searchHistory.firstIndex(where: { $0.query.lowercased() == query.lowercased() }) {
            searchHistory[existingIndex].frequency += 1
            searchHistory[existingIndex].timestamp = Date()
            searchHistory[existingIndex].lastResultsCount = resultsCount
        } else {
            let newSearch = HistoricalSearch(
                query: query,
                timestamp: Date(),
                frequency: 1,
                lastResultsCount: resultsCount,
                insights: insights
            )
            searchHistory.append(newSearch)
        }
        
        // Maintain search history limit
        if searchHistory.count > Config.maxSearchHistory {
            searchHistory = Array(searchHistory.suffix(Config.maxSearchHistory))
        }
        
        saveSearchHistory()
    }
    
    func loadSearchHistory() {
        // Load from UserDefaults or Core Data in a real implementation
        // For now, using a simple in-memory approach
        searchHistory = []
    }
    
    func saveSearchHistory() {
        // Save to UserDefaults or Core Data in a real implementation
        // For now, keeping in memory only
    }
    
    func cleanExpiredCache() {
        let expirationTime = TimeInterval(Config.cacheExpirationMinutes * 60)
        let now = Date()
        
        if let lastAnalysis = lastAnalysisTimestamp,
           now.timeIntervalSince(lastAnalysis) > expirationTime {
            contextCache.removeAll()
            lastAnalysisTimestamp = nil
        }
    }
}

// MARK: - Supporting Models

struct SearchSuggestion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: SearchSuggestionType
    let confidence: Double
    let context: String
}

enum SearchSuggestionType: CaseIterable {
    case semantic
    case historical
    case trending
    case personalized
    
    var icon: String {
        switch self {
        case .semantic: return "brain.head.profile"
        case .historical: return "clock.arrow.circlepath"
        case .trending: return "chart.line.uptrend.xyaxis"
        case .personalized: return "person.crop.circle"
        }
    }
}

struct ContextualInsight: Identifiable, Equatable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let confidence: Double
    let actionable: Bool
}

enum InsightType: CaseIterable {
    case temporal
    case speaker
    case topic
    case sentiment
    case crossReference
    
    var icon: String {
        switch self {
        case .temporal: return "calendar"
        case .speaker: return "person.3"
        case .topic: return "tag"
        case .sentiment: return "heart"
        case .crossReference: return "link"
        }
    }
    
    var color: String {
        switch self {
        case .temporal: return "blue"
        case .speaker: return "green"
        case .topic: return "purple"
        case .sentiment: return "pink"
        case .crossReference: return "orange"
        }
    }
}

struct SearchTrend: Identifiable, Equatable {
    let id = UUID()
    let query: String
    let frequency: Int
    let direction: SearchTrendDirection
    let timeframe: String
}

enum SearchTrendDirection: CaseIterable {
    case rising
    case falling
    case stable
    
    var icon: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    var color: String {
        switch self {
        case .rising: return "green"
        case .falling: return "red"
        case .stable: return "gray"
        }
    }
}

struct HistoricalSearch {
    let query: String
    var timestamp: Date
    var frequency: Int
    var lastResultsCount: Int
    let insights: [ContextualInsight]
}

// MARK: - Extensions

extension Array {
    func removingDuplicates<T: Equatable>(by keyPath: (Element) -> T) -> [Element] {
        var result: [Element] = []
        var seen: [T] = []
        
        for element in self {
            let key = keyPath(element)
            if !seen.contains(key) {
                seen.append(key)
                result.append(element)
            }
        }
        
        return result
    }
}

enum NLSentiment {
    case positive
    case negative
    case neutral
}

class NLSentimentPredictor {
    func predict(_ text: String) -> NLSentiment {
        // Simplified sentiment analysis
        let sentimentAnalyzer = NLSentimentPredictor()
        
        // Use NaturalLanguage framework for basic sentiment
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        let sentiment = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        if let sentimentScore = sentiment?.rawValue,
           let score = Double(sentimentScore) {
            return score > 0.1 ? .positive : score < -0.1 ? .negative : .neutral
        }
        
        return .neutral
    }
}
