import Foundation
import Combine
import NaturalLanguage

@MainActor
class QueryOptimizationEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published var optimizedQueries: [OptimizedQuery] = []
    @Published var queryPerformanceMetrics: [QueryMetrics] = []
    @Published var isOptimizing: Bool = false
    
    // MARK: - Dependencies
    private let analyticsService: AnalyticsService
    
    // MARK: - Private Properties
    private var queryHistory: [QueryPerformance] = []
    private let nlTagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .language])
    private var optimizationCache: [String: OptimizedQuery] = [:]
    
    // MARK: - Configuration
    private struct Config {
        static let cacheExpirationHours = 24
        static let maxCachedQueries = 500
        static let minConfidenceThreshold = 0.6
        static let maxQueryLength = 200
    }
    
    // MARK: - Initialization
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
        loadQueryHistory()
    }
    
    // MARK: - Public Methods
    
    /// Optimize a search query using AI and historical data
    func optimizeQuery(_ originalQuery: String) async -> OptimizedQuery {
        // Check cache first
        if let cachedOptimization = optimizationCache[originalQuery.lowercased()],
           !isCacheExpired(cachedOptimization.timestamp) {
            return cachedOptimization
        }
        
        isOptimizing = true
        
        do {
            let optimized = await performQueryOptimization(originalQuery)
            
            await MainActor.run {
                self.isOptimizing = false
                
                // Update cache
                self.optimizationCache[originalQuery.lowercased()] = optimized
                self.optimizedQueries.append(optimized)
                
                // Clean up old cache entries
                self.cleanupCache()
            }
            
            // Track optimization
            await analyticsService.trackEvent("query_optimized", parameters: [
                "original_length": originalQuery.count,
                "optimized_length": optimized.optimizedText.count,
                "improvement_score": optimized.improvementScore,
                "techniques_used": optimized.techniques.map { $0.rawValue }.joined(separator: ",")
            ])
            
            return optimized
            
        } catch {
            await MainActor.run {
                self.isOptimizing = false
            }
            
            // Return original query if optimization fails
            return OptimizedQuery(
                originalText: originalQuery,
                optimizedText: originalQuery,
                improvementScore: 0.0,
                confidence: 0.0,
                techniques: [],
                explanation: "Optimization failed: \(error.localizedDescription)",
                timestamp: Date()
            )
        }
    }
    
    /// Analyze query performance and suggest improvements
    func analyzeQueryPerformance(_ query: String, results: [SearchResultModel], responseTime: TimeInterval) async {
        let metrics = QueryMetrics(
            query: query,
            resultsCount: results.count,
            responseTime: responseTime,
            relevanceScore: calculateRelevanceScore(for: query, results: results),
            timestamp: Date()
        )
        
        await MainActor.run {
            self.queryPerformanceMetrics.append(metrics)
            
            // Keep only recent metrics
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
            self.queryPerformanceMetrics = self.queryPerformanceMetrics.filter { $0.timestamp > thirtyDaysAgo }
        }
        
        // Record performance for future optimizations
        recordQueryPerformance(query: query, metrics: metrics)
        
        await analyticsService.trackEvent("query_performance_analyzed", parameters: [
            "query": query.prefix(100).description,
            "results_count": results.count,
            "response_time": responseTime,
            "relevance_score": metrics.relevanceScore
        ])
    }
    
    /// Get performance insights for queries
    func getQueryInsights() -> [QueryInsight] {
        var insights: [QueryInsight] = []
        
        // Analyze average performance
        if !queryPerformanceMetrics.isEmpty {
            let avgResponseTime = queryPerformanceMetrics.map { $0.responseTime }.reduce(0, +) / Double(queryPerformanceMetrics.count)
            let avgRelevance = queryPerformanceMetrics.map { $0.relevanceScore }.reduce(0, +) / Double(queryPerformanceMetrics.count)
            
            insights.append(QueryInsight(
                type: .performance,
                title: "Average Performance",
                description: "Average response time: \(String(format: "%.2f", avgResponseTime))s, Relevance: \(String(format: "%.1f", avgRelevance * 100))%",
                actionable: false
            ))
        }
        
        // Identify slow queries
        let slowQueries = queryPerformanceMetrics.filter { $0.responseTime > 2.0 }
        if !slowQueries.isEmpty {
            insights.append(QueryInsight(
                type: .optimization,
                title: "Slow Queries Detected",
                description: "\(slowQueries.count) queries took longer than 2 seconds to process",
                actionable: true
            ))
        }
        
        // Identify low-relevance queries
        let lowRelevanceQueries = queryPerformanceMetrics.filter { $0.relevanceScore < 0.5 }
        if !lowRelevanceQueries.isEmpty {
            insights.append(QueryInsight(
                type: .relevance,
                title: "Low Relevance Results",
                description: "\(lowRelevanceQueries.count) queries returned low-relevance results",
                actionable: true
            ))
        }
        
        // Popular query patterns
        let popularPatterns = identifyPopularPatterns()
        if !popularPatterns.isEmpty {
            insights.append(QueryInsight(
                type: .patterns,
                title: "Popular Query Patterns",
                description: "Most common: \(popularPatterns.prefix(3).joined(separator: ", "))",
                actionable: false
            ))
        }
        
        return insights
    }
    
    /// Get suggestions for query improvements
    func getQuerySuggestions(for query: String) -> [QuerySuggestion] {
        var suggestions: [QuerySuggestion] = []
        
        // Analyze query structure
        nlTagger.string = query
        
        // Check for missing context
        let hasTimeContext = containsTimeContext(query)
        let hasSpeakerContext = containsSpeakerContext(query)
        let hasTopicContext = containsTopicContext(query)
        
        if !hasTimeContext {
            suggestions.append(QuerySuggestion(
                type: .addContext,
                original: query,
                suggested: query + " in 2024",
                improvement: "Add time context for more precise results",
                confidence: 0.8
            ))
        }
        
        if !hasSpeakerContext && query.count < 50 {
            suggestions.append(QuerySuggestion(
                type: .addContext,
                original: query,
                suggested: "speaker: " + query,
                improvement: "Specify speaker for targeted search",
                confidence: 0.7
            ))
        }
        
        // Check for overly broad queries
        if query.split(separator: " ").count < 2 {
            suggestions.append(QuerySuggestion(
                type: .specificity,
                original: query,
                suggested: query + " policy details",
                improvement: "Add more specific terms",
                confidence: 0.6
            ))
        }
        
        // Check for complex queries that could be simplified
        if query.split(separator: " ").count > 10 {
            let simplified = simplifyQuery(query)
            suggestions.append(QuerySuggestion(
                type: .simplification,
                original: query,
                suggested: simplified,
                improvement: "Simplify for better results",
                confidence: 0.7
            ))
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
}

// MARK: - Private Methods
private extension QueryOptimizationEngine {
    
    func performQueryOptimization(_ query: String) async -> OptimizedQuery {
        var optimizedText = query
        var techniques: [OptimizationTechnique] = []
        var explanation = "Applied optimizations: "
        
        // 1. Clean and normalize
        optimizedText = cleanQuery(optimizedText)
        techniques.append(.normalization)
        
        // 2. Expand abbreviations
        let expandedQuery = expandAbbreviations(optimizedText)
        if expandedQuery != optimizedText {
            optimizedText = expandedQuery
            techniques.append(.abbreviationExpansion)
        }
        
        // 3. Add contextual terms
        let contextualQuery = addContextualTerms(optimizedText)
        if contextualQuery != optimizedText {
            optimizedText = contextualQuery
            techniques.append(.contextualEnhancement)
        }
        
        // 4. Apply semantic enhancement
        let semanticQuery = enhanceSemantics(optimizedText)
        if semanticQuery != optimizedText {
            optimizedText = semanticQuery
            techniques.append(.semanticEnhancement)
        }
        
        // 5. Optimize for political content
        let politicalQuery = optimizeForPoliticalContent(optimizedText)
        if politicalQuery != optimizedText {
            optimizedText = politicalQuery
            techniques.append(.domainSpecific)
        }
        
        // Calculate improvement score
        let improvementScore = calculateImprovementScore(original: query, optimized: optimizedText)
        let confidence = calculateOptimizationConfidence(techniques: techniques, improvementScore: improvementScore)
        
        // Generate explanation
        explanation += techniques.map { $0.description }.joined(separator: ", ")
        
        return OptimizedQuery(
            originalText: query,
            optimizedText: optimizedText,
            improvementScore: improvementScore,
            confidence: confidence,
            techniques: techniques,
            explanation: explanation,
            timestamp: Date()
        )
    }
    
    func cleanQuery(_ query: String) -> String {
        // Remove excessive whitespace and special characters
        let cleaned = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s\\-_]", with: "", options: .regularExpression)
        
        return cleaned.isEmpty ? query : cleaned
    }
    
    func expandAbbreviations(_ query: String) -> String {
        let abbreviations: [String: String] = [
            "POTUS": "President of the United States",
            "VP": "Vice President",
            "GOP": "Republican Party",
            "DNC": "Democratic National Committee",
            "RNC": "Republican National Committee",
            "SCOTUS": "Supreme Court of the United States",
            "FDA": "Food and Drug Administration",
            "EPA": "Environmental Protection Agency",
            "DoD": "Department of Defense",
            "DoJ": "Department of Justice",
            "HHS": "Health and Human Services",
            "DHS": "Department of Homeland Security"
        ]
        
        var expandedQuery = query
        for (abbrev, full) in abbreviations {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: abbrev))\\b"
            expandedQuery = expandedQuery.replacingOccurrences(
                of: pattern,
                with: full,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return expandedQuery
    }
    
    func addContextualTerms(_ query: String) -> String {
        let lowercaseQuery = query.lowercased()
        var contextualQuery = query
        
        // Add policy context for economic terms
        if lowercaseQuery.contains("economy") || lowercaseQuery.contains("economic") {
            if !lowercaseQuery.contains("policy") {
                contextualQuery += " policy"
            }
        }
        
        // Add legislation context for legal terms
        if lowercaseQuery.contains("law") || lowercaseQuery.contains("legal") {
            if !lowercaseQuery.contains("legislation") {
                contextualQuery += " legislation"
            }
        }
        
        // Add debate context for controversial topics
        let controversialTerms = ["abortion", "gun", "immigration", "climate"]
        if controversialTerms.contains(where: { lowercaseQuery.contains($0) }) {
            if !lowercaseQuery.contains("debate") && !lowercaseQuery.contains("discussion") {
                contextualQuery += " debate"
            }
        }
        
        return contextualQuery
    }
    
    func enhanceSemantics(_ query: String) -> String {
        nlTagger.string = query
        var enhancedTerms: [String] = []
        
        // Identify named entities and add related terms
        nlTagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            let token = String(query[tokenRange])
            
            if let tag = tag {
                switch tag {
                case .personalName:
                    // Add political context for names
                    if !query.lowercased().contains("senator") && !query.lowercased().contains("representative") {
                        enhancedTerms.append("politician")
                    }
                case .organizationName:
                    // Add institutional context
                    if !query.lowercased().contains("government") && !query.lowercased().contains("administration") {
                        enhancedTerms.append("institution")
                    }
                default:
                    break
                }
            }
            
            return true
        }
        
        if !enhancedTerms.isEmpty {
            return query + " " + enhancedTerms.joined(separator: " ")
        }
        
        return query
    }
    
    func optimizeForPoliticalContent(_ query: String) -> String {
        let politicalKeywords = [
            "policy", "legislation", "congress", "senate", "house",
            "committee", "hearing", "testimony", "statement", "address"
        ]
        
        let lowercaseQuery = query.lowercased()
        let hasPoliticalContext = politicalKeywords.contains { lowercaseQuery.contains($0) }
        
        if !hasPoliticalContext {
            // Add appropriate political context based on query content
            if lowercaseQuery.contains("healthcare") {
                return query + " healthcare policy"
            } else if lowercaseQuery.contains("climate") {
                return query + " climate legislation"
            } else if lowercaseQuery.contains("tax") {
                return query + " tax policy"
            } else {
                return query + " political statement"
            }
        }
        
        return query
    }
    
    func calculateImprovementScore(original: String, optimized: String) -> Double {
        let originalLength = Double(original.count)
        let optimizedLength = Double(optimized.count)
        
        // Base score on length increase (more context is generally better)
        let lengthScore = min((optimizedLength - originalLength) / originalLength, 0.5)
        
        // Add score for political terms
        let politicalTermsAdded = countPoliticalTerms(in: optimized) - countPoliticalTerms(in: original)
        let politicalScore = Double(politicalTermsAdded) * 0.1
        
        // Add score for expanded abbreviations
        let abbreviationScore = optimized.contains("President of the United States") ? 0.2 : 0.0
        
        return max(0.0, min(1.0, lengthScore + politicalScore + abbreviationScore))
    }
    
    func calculateOptimizationConfidence(techniques: [OptimizationTechnique], improvementScore: Double) -> Double {
        let techniquesScore = Double(techniques.count) * 0.15
        let improvementWeight = improvementScore * 0.6
        
        return max(0.0, min(1.0, techniquesScore + improvementWeight + 0.25))
    }
    
    func countPoliticalTerms(in text: String) -> Int {
        let politicalTerms = [
            "policy", "legislation", "congress", "senate", "house",
            "committee", "hearing", "testimony", "statement", "address",
            "government", "administration", "political", "politician"
        ]
        
        let lowercaseText = text.lowercased()
        return politicalTerms.reduce(0) { count, term in
            count + (lowercaseText.contains(term) ? 1 : 0)
        }
    }
    
    func calculateRelevanceScore(for query: String, results: [SearchResultModel]) -> Double {
        guard !results.isEmpty else { return 0.0 }
        
        let queryTerms = Set(query.lowercased().split(separator: " ").map(String.init))
        var totalRelevance = 0.0
        
        for result in results {
            let contentText = [result.title, result.content, result.speaker, result.category]
                .compactMap { $0 }
                .joined(separator: " ")
                .lowercased()
            
            let contentTerms = Set(contentText.split(separator: " ").map(String.init))
            let intersection = queryTerms.intersection(contentTerms)
            let relevance = Double(intersection.count) / Double(queryTerms.count)
            
            totalRelevance += relevance
        }
        
        return totalRelevance / Double(results.count)
    }
    
    func containsTimeContext(_ query: String) -> Bool {
        let timePatterns = ["2024", "2023", "2022", "2021", "last year", "this year", "recent", "latest"]
        let lowercaseQuery = query.lowercased()
        return timePatterns.contains { lowercaseQuery.contains($0) }
    }
    
    func containsSpeakerContext(_ query: String) -> Bool {
        let speakerPatterns = ["speaker:", "senator", "representative", "president", "governor", "mayor"]
        let lowercaseQuery = query.lowercased()
        return speakerPatterns.contains { lowercaseQuery.contains($0) }
    }
    
    func containsTopicContext(_ query: String) -> Bool {
        let topicPatterns = ["healthcare", "economy", "climate", "education", "foreign policy", "immigration"]
        let lowercaseQuery = query.lowercased()
        return topicPatterns.contains { lowercaseQuery.contains($0) }
    }
    
    func simplifyQuery(_ query: String) -> String {
        // Keep the most important terms (first and last few words)
        let words = query.split(separator: " ")
        if words.count > 10 {
            let important = Array(words.prefix(3)) + Array(words.suffix(3))
            return important.joined(separator: " ")
        }
        return query
    }
    
    func identifyPopularPatterns() -> [String] {
        let queryWords = queryHistory
            .flatMap { $0.query.split(separator: " ") }
            .map { String($0).lowercased() }
        
        let wordCounts = Dictionary(grouping: queryWords, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return Array(wordCounts.prefix(5).map { $0.key })
    }
    
    func recordQueryPerformance(query: String, metrics: QueryMetrics) {
        let performance = QueryPerformance(
            query: query,
            timestamp: Date(),
            responseTime: metrics.responseTime,
            resultsCount: metrics.resultsCount,
            relevanceScore: metrics.relevanceScore
        )
        
        queryHistory.append(performance)
        
        // Keep only recent history
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
        queryHistory = queryHistory.filter { $0.timestamp > thirtyDaysAgo }
        
        saveQueryHistory()
    }
    
    func loadQueryHistory() {
        // In a real implementation, load from Core Data or UserDefaults
        queryHistory = []
    }
    
    func saveQueryHistory() {
        // In a real implementation, save to Core Data or UserDefaults
    }
    
    func isCacheExpired(_ timestamp: Date) -> Bool {
        let expirationTime = TimeInterval(Config.cacheExpirationHours * 3600)
        return Date().timeIntervalSince(timestamp) > expirationTime
    }
    
    func cleanupCache() {
        let now = Date()
        let expirationTime = TimeInterval(Config.cacheExpirationHours * 3600)
        
        optimizationCache = optimizationCache.filter { _, optimization in
            now.timeIntervalSince(optimization.timestamp) < expirationTime
        }
        
        // Keep only the most recent entries if still over limit
        if optimizationCache.count > Config.maxCachedQueries {
            let sortedEntries = optimizationCache.sorted { $0.value.timestamp > $1.value.timestamp }
            optimizationCache = Dictionary(uniqueKeysWithValues: Array(sortedEntries.prefix(Config.maxCachedQueries)))
        }
    }
}

// MARK: - Supporting Models

struct OptimizedQuery: Identifiable, Equatable {
    let id = UUID()
    let originalText: String
    let optimizedText: String
    let improvementScore: Double
    let confidence: Double
    let techniques: [OptimizationTechnique]
    let explanation: String
    let timestamp: Date
}

enum OptimizationTechnique: String, CaseIterable {
    case normalization = "normalization"
    case abbreviationExpansion = "abbreviation_expansion"
    case contextualEnhancement = "contextual_enhancement"
    case semanticEnhancement = "semantic_enhancement"
    case domainSpecific = "domain_specific"
    
    var description: String {
        switch self {
        case .normalization:
            return "text normalization"
        case .abbreviationExpansion:
            return "abbreviation expansion"
        case .contextualEnhancement:
            return "contextual enhancement"
        case .semanticEnhancement:
            return "semantic enhancement"
        case .domainSpecific:
            return "political domain optimization"
        }
    }
}

struct QueryMetrics: Identifiable, Equatable {
    let id = UUID()
    let query: String
    let resultsCount: Int
    let responseTime: TimeInterval
    let relevanceScore: Double
    let timestamp: Date
}

struct QueryInsight: Identifiable, Equatable {
    let id = UUID()
    let type: QueryInsightType
    let title: String
    let description: String
    let actionable: Bool
}

enum QueryInsightType: CaseIterable {
    case performance
    case optimization
    case relevance
    case patterns
    
    var icon: String {
        switch self {
        case .performance: return "speedometer"
        case .optimization: return "wand.and.rays"
        case .relevance: return "target"
        case .patterns: return "chart.bar"
        }
    }
}

struct QuerySuggestion: Identifiable, Equatable {
    let id = UUID()
    let type: QuerySuggestionType
    let original: String
    let suggested: String
    let improvement: String
    let confidence: Double
}

enum QuerySuggestionType: CaseIterable {
    case addContext
    case specificity
    case simplification
    case expansion
    
    var icon: String {
        switch self {
        case .addContext: return "plus.circle"
        case .specificity: return "scope"
        case .simplification: return "minus.circle"
        case .expansion: return "arrow.up.right.circle"
        }
    }
}

struct QueryPerformance {
    let query: String
    let timestamp: Date
    let responseTime: TimeInterval
    let resultsCount: Int
    let relevanceScore: Double
}
