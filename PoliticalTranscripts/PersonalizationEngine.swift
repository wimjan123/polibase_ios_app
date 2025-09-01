//
//  PersonalizationEngine.swift
//  PoliticalTranscripts
//
//  AI-powered personalization engine for adaptive content recommendations,
//  user preference learning, and customized experience delivery.
//

import Foundation
import Combine

/// AI-powered personalization engine providing adaptive content recommendations
@MainActor
class PersonalizationEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published var userProfile: UserProfile = UserProfile()
    @Published var recommendations: [SmartRecommendation] = []
    @Published var personalizedTopics: [PersonalizedTopic] = []
    @Published var adaptiveFilters: [AdaptiveFilter] = []
    @Published var isLearning: Bool = false
    
    // MARK: - Private Properties
    private let analyticsService: AnalyticsService
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private let recommendationCache = NSCache<NSString, CachedRecommendations>()
    
    // MARK: - Configuration
    private struct Configuration {
        static let maxRecommendations = 20
        static let learningDecayFactor = 0.95
        static let confidenceThreshold = 0.6
        static let cacheExpirationTime: TimeInterval = 1800 // 30 minutes
        static let minInteractionsForPersonalization = 5
    }
    
    // MARK: - Initialization
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
        setupPersonalization()
        loadUserProfile()
    }
    
    // MARK: - Core Personalization
    
    /// Generates personalized recommendations based on user behavior and preferences
    /// - Parameter context: Current context for recommendations
    /// - Returns: Array of smart recommendations with confidence scores
    func generatePersonalizedRecommendations(context: RecommendationContext = .general) async -> [SmartRecommendation] {
        isLearning = true
        defer { isLearning = false }
        
        // Check cache first
        if let cached = getCachedRecommendations(for: context) {
            return cached
        }
        
        do {
            var recommendations: [SmartRecommendation] = []
            
            // 1. Behavior-based recommendations
            let behaviorRecommendations = await generateBehaviorBasedRecommendations()
            recommendations.append(contentsOf: behaviorRecommendations)
            
            // 2. Content similarity recommendations
            let similarityRecommendations = await generateSimilarityBasedRecommendations()
            recommendations.append(contentsOf: similarityRecommendations)
            
            // 3. Trending content recommendations
            let trendingRecommendations = await generateTrendingRecommendations()
            recommendations.append(contentsOf: trendingRecommendations)
            
            // 4. Collaborative filtering recommendations
            let collaborativeRecommendations = await generateCollaborativeRecommendations()
            recommendations.append(contentsOf: collaborativeRecommendations)
            
            // 5. Temporal pattern recommendations
            let temporalRecommendations = await generateTemporalRecommendations()
            recommendations.append(contentsOf: temporalRecommendations)
            
            // Score and rank recommendations
            let scoredRecommendations = await scoreRecommendations(recommendations, context: context)
            let finalRecommendations = Array(scoredRecommendations
                .sorted { $0.confidence > $1.confidence }
                .prefix(Configuration.maxRecommendations))
            
            // Cache results
            cacheRecommendations(finalRecommendations, for: context)
            
            // Update user profile with generated recommendations
            await updateUserProfileWithRecommendations(finalRecommendations)
            
            self.recommendations = finalRecommendations
            return finalRecommendations
            
        } catch {
            await analyticsService.trackError(error, context: .searchOptimization)
            return generateFallbackRecommendations()
        }
    }
    
    /// Updates user preferences based on interaction patterns
    /// - Parameter interaction: User interaction to learn from
    func learnFromUserInteraction(_ interaction: UserInteraction) async {
        // Update interaction history
        userProfile.interactionHistory.append(interaction)
        
        // Keep history manageable
        if userProfile.interactionHistory.count > 1000 {
            userProfile.interactionHistory.removeFirst(100)
        }
        
        // Update preferences based on interaction type
        await updatePreferencesFromInteraction(interaction)
        
        // Recalculate preference weights
        await recalculatePreferenceWeights()
        
        // Update adaptive filters
        await updateAdaptiveFilters()
        
        // Save updated profile
        saveUserProfile()
        
        await analyticsService.trackUserAction(.learning(interaction: interaction.type), context: .searchOptimization)
    }
    
    /// Calculates content similarity for recommendation purposes
    /// - Parameters:
    ///   - content1: First content item
    ///   - content2: Second content item
    /// - Returns: Similarity score between 0 and 1
    func calculateContentSimilarity(_ content1: VideoModel, _ content2: VideoModel) async -> Double {
        var similarityScore: Double = 0.0
        
        // Speaker similarity (30% weight)
        if content1.speaker == content2.speaker {
            similarityScore += 0.3
        }
        
        // Category similarity (25% weight)
        if content1.category == content2.category {
            similarityScore += 0.25
        }
        
        // Source similarity (15% weight)
        if content1.source == content2.source {
            similarityScore += 0.15
        }
        
        // Temporal similarity (10% weight)
        let timeDiff = abs(content1.date.timeIntervalSince(content2.date))
        let maxTimeDiff: TimeInterval = 365 * 24 * 60 * 60 // 1 year
        let temporalSimilarity = max(0, 1 - (timeDiff / maxTimeDiff))
        similarityScore += temporalSimilarity * 0.1
        
        // Content similarity using basic text analysis (20% weight)
        let textSimilarity = await calculateTextSimilarity(content1, content2)
        similarityScore += textSimilarity * 0.2
        
        return min(1.0, similarityScore)
    }
    
    /// Generates adaptive filters based on user behavior patterns
    /// - Returns: Array of adaptive filters optimized for the user
    func generateAdaptiveFilters() async -> [AdaptiveFilter] {
        var filters: [AdaptiveFilter] = []
        
        // Speaker preference filters
        let speakerFilters = generateSpeakerFilters()
        filters.append(contentsOf: speakerFilters)
        
        // Topic preference filters
        let topicFilters = generateTopicFilters()
        filters.append(contentsOf: topicFilters)
        
        // Temporal preference filters
        let temporalFilters = generateTemporalFilters()
        filters.append(contentsOf: temporalFilters)
        
        // Source preference filters
        let sourceFilters = generateSourceFilters()
        filters.append(contentsOf: sourceFilters)
        
        // Sort by relevance
        let sortedFilters = filters.sorted { $0.relevanceScore > $1.relevanceScore }
        
        self.adaptiveFilters = sortedFilters
        return sortedFilters
    }
    
    /// Creates personalized dashboard content based on user preferences
    /// - Returns: Personalized dashboard configuration
    func generatePersonalizedDashboard() async -> PersonalizedDashboard {
        let dashboard = PersonalizedDashboard(
            userId: userProfile.id.uuidString,
            recommendedContent: await generatePersonalizedRecommendations(context: .dashboard),
            personalizedTopics: await generatePersonalizedTopics(),
            quickActions: generateQuickActions(),
            recentActivity: getRecentActivity(),
            trendingInInterests: await getTrendingInUserInterests(),
            suggestedSearches: await generateSuggestedSearches(),
            lastUpdated: Date()
        )
        
        return dashboard
    }
}

// MARK: - Supporting Types

/// Comprehensive user profile for personalization
struct UserProfile: Codable {
    let id: UUID = UUID()
    var createdAt: Date = Date()
    var lastUpdated: Date = Date()
    
    // Preferences
    var speakerPreferences: [String: Double] = [:]
    var topicPreferences: [String: Double] = [:]
    var sourcePreferences: [String: Double] = [:]
    var categoryPreferences: [String: Double] = [:]
    
    // Behavior patterns
    var searchPatterns: [String: Int] = [:]
    var viewingPatterns: ViewingPatterns = ViewingPatterns()
    var interactionHistory: [UserInteraction] = []
    
    // Computed preferences
    var preferredDuration: DurationPreference = .medium
    var preferredTimeOfDay: TimeOfDay = .any
    var contentFreshness: ContentFreshnessPreference = .mixed
    
    // Privacy settings
    var personalizationEnabled: Bool = true
    var dataCollectionConsent: Bool = true
}

/// User interaction for learning purposes
struct UserInteraction: Codable, Identifiable {
    let id: UUID = UUID()
    let type: InteractionType
    let contentId: String?
    let query: String?
    let duration: TimeInterval?
    let timestamp: Date = Date()
    let context: String?
    let metadata: [String: String]?
}

/// Types of user interactions for learning
enum InteractionType: String, Codable {
    case view = "view"
    case search = "search"
    case bookmark = "bookmark"
    case share = "share"
    case skip = "skip"
    case like = "like"
    case filter = "filter"
    case download = "download"
}

/// Smart recommendation with AI-generated reasoning
struct SmartRecommendation: Codable, Identifiable {
    let id: UUID = UUID()
    let transcript: VideoModel
    let reason: RecommendationReason
    let confidence: Double
    let personalizedScore: Double
    let metadata: RecommendationMetadata
    let generatedAt: Date = Date()
}

/// Reasoning behind recommendations
enum RecommendationReason: String, Codable {
    case behaviorPattern = "behavior_pattern"
    case contentSimilarity = "content_similarity"
    case trending = "trending"
    case collaborative = "collaborative"
    case temporal = "temporal"
    case speakerPreference = "speaker_preference"
    case topicInterest = "topic_interest"
    case sourcePreference = "source_preference"
    
    var displayText: String {
        switch self {
        case .behaviorPattern: return "Based on your viewing patterns"
        case .contentSimilarity: return "Similar to content you've enjoyed"
        case .trending: return "Trending in your areas of interest"
        case .collaborative: return "Popular with users like you"
        case .temporal: return "Timely and relevant"
        case .speakerPreference: return "From a speaker you follow"
        case .topicInterest: return "Matches your interests"
        case .sourcePreference: return "From a source you trust"
        }
    }
}

/// Additional metadata for recommendations
struct RecommendationMetadata: Codable {
    let algorithmVersion: String
    let features: [String]
    let alternativeReasons: [RecommendationReason]
    let debugInfo: [String: String]?
}

/// Personalized topic with user-specific relevance
struct PersonalizedTopic: Codable, Identifiable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let relevanceScore: Double
    let userInterestLevel: Double
    let trendingScore: Double
    let contentCount: Int
    let lastUpdated: Date = Date()
}

/// Adaptive filter that learns from user behavior
struct AdaptiveFilter: Codable, Identifiable {
    let id: UUID = UUID()
    let type: FilterType
    let value: String
    let relevanceScore: Double
    let usageCount: Int
    let lastUsed: Date?
    let autoSuggest: Bool
}

/// Filter types for adaptive filtering
enum FilterType: String, Codable {
    case speaker = "speaker"
    case topic = "topic"
    case source = "source"
    case category = "category"
    case dateRange = "date_range"
    case duration = "duration"
}

/// Viewing pattern analysis
struct ViewingPatterns: Codable {
    var averageViewDuration: TimeInterval = 0
    var preferredContentLength: DurationPreference = .medium
    var peakViewingHours: [Int] = []
    var skipPatterns: [String: Int] = [:]
    var completionRate: Double = 0
}

/// Duration preferences
enum DurationPreference: String, Codable, CaseIterable {
    case short = "short" // < 15 minutes
    case medium = "medium" // 15-45 minutes
    case long = "long" // > 45 minutes
    case any = "any"
}

/// Time of day preferences
enum TimeOfDay: String, Codable, CaseIterable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
    case any = "any"
}

/// Content freshness preferences
enum ContentFreshnessPreference: String, Codable, CaseIterable {
    case recent = "recent" // Last 30 days
    case mixed = "mixed" // Mix of recent and older
    case historical = "historical" // Older content preferred
    case any = "any"
}

/// Recommendation context for different scenarios
enum RecommendationContext: String, Codable {
    case general = "general"
    case dashboard = "dashboard"
    case search = "search"
    case related = "related"
    case trending = "trending"
    case followUp = "follow_up"
}

/// Personalized dashboard configuration
struct PersonalizedDashboard: Codable {
    let userId: String
    let recommendedContent: [SmartRecommendation]
    let personalizedTopics: [PersonalizedTopic]
    let quickActions: [QuickAction]
    let recentActivity: [ActivityItem]
    let trendingInInterests: [TrendingItem]
    let suggestedSearches: [String]
    let lastUpdated: Date
}

/// Quick action for personalized dashboard
struct QuickAction: Codable, Identifiable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let action: String
    let icon: String
    let priority: Int
}

/// Activity item for user history
struct ActivityItem: Codable, Identifiable {
    let id: UUID = UUID()
    let type: ActivityType
    let title: String
    let subtitle: String?
    let timestamp: Date
    let contentId: String?
}

/// Activity types for tracking
enum ActivityType: String, Codable {
    case viewed = "viewed"
    case searched = "searched"
    case bookmarked = "bookmarked"
    case shared = "shared"
}

/// Trending item in user's areas of interest
struct TrendingItem: Codable, Identifiable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let trendScore: Double
    let relevanceToUser: Double
    let contentCount: Int
}

/// Cached recommendations for performance
private class CachedRecommendations: NSObject {
    let recommendations: [SmartRecommendation]
    let timestamp: Date
    let context: RecommendationContext
    
    init(recommendations: [SmartRecommendation], context: RecommendationContext) {
        self.recommendations = recommendations
        self.timestamp = Date()
        self.context = context
    }
    
    var isValid: Bool {
        Date().timeIntervalSince(timestamp) < 1800 // 30 minutes
    }
}

// MARK: - Private Extensions

private extension PersonalizationEngine {
    
    func setupPersonalization() {
        recommendationCache.countLimit = 50
        recommendationCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
    
    func loadUserProfile() {
        if let data = userDefaults.data(forKey: "user_profile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            userProfile = profile
        }
    }
    
    func saveUserProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            userDefaults.set(data, forKey: "user_profile")
        }
    }
    
    func getCachedRecommendations(for context: RecommendationContext) -> [SmartRecommendation]? {
        let key = "recommendations_\(context.rawValue)" as NSString
        guard let cached = recommendationCache.object(forKey: key),
              cached.isValid else { return nil }
        return cached.recommendations
    }
    
    func cacheRecommendations(_ recommendations: [SmartRecommendation], for context: RecommendationContext) {
        let key = "recommendations_\(context.rawValue)" as NSString
        let cached = CachedRecommendations(recommendations: recommendations, context: context)
        recommendationCache.setObject(cached, forKey: key)
    }
    
    func generateBehaviorBasedRecommendations() async -> [SmartRecommendation] {
        // Implementation for behavior-based recommendations
        return []
    }
    
    func generateSimilarityBasedRecommendations() async -> [SmartRecommendation] {
        // Implementation for content similarity recommendations
        return []
    }
    
    func generateTrendingRecommendations() async -> [SmartRecommendation] {
        // Implementation for trending content recommendations
        return []
    }
    
    func generateCollaborativeRecommendations() async -> [SmartRecommendation] {
        // Implementation for collaborative filtering recommendations
        return []
    }
    
    func generateTemporalRecommendations() async -> [SmartRecommendation] {
        // Implementation for temporal pattern recommendations
        return []
    }
    
    func scoreRecommendations(_ recommendations: [SmartRecommendation], context: RecommendationContext) async -> [SmartRecommendation] {
        // Implementation for scoring and ranking recommendations
        return recommendations
    }
    
    func generateFallbackRecommendations() -> [SmartRecommendation] {
        // Implementation for fallback recommendations
        return []
    }
    
    func updateUserProfileWithRecommendations(_ recommendations: [SmartRecommendation]) async {
        // Update user profile based on generated recommendations
        userProfile.lastUpdated = Date()
        saveUserProfile()
    }
    
    func updatePreferencesFromInteraction(_ interaction: UserInteraction) async {
        // Update user preferences based on interaction
        switch interaction.type {
        case .view, .like, .bookmark:
            // Positive interaction - increase preferences
            break
        case .skip:
            // Negative interaction - decrease preferences
            break
        default:
            break
        }
    }
    
    func recalculatePreferenceWeights() async {
        // Recalculate preference weights using decay factor
        let decayFactor = Configuration.learningDecayFactor
        
        for (key, value) in userProfile.speakerPreferences {
            userProfile.speakerPreferences[key] = value * decayFactor
        }
        
        for (key, value) in userProfile.topicPreferences {
            userProfile.topicPreferences[key] = value * decayFactor
        }
        
        for (key, value) in userProfile.sourcePreferences {
            userProfile.sourcePreferences[key] = value * decayFactor
        }
    }
    
    func updateAdaptiveFilters() async {
        adaptiveFilters = await generateAdaptiveFilters()
    }
    
    func calculateTextSimilarity(_ content1: VideoModel, _ content2: VideoModel) async -> Double {
        // Basic text similarity calculation
        // In a real implementation, this would use more sophisticated NLP techniques
        return 0.5
    }
    
    func generateSpeakerFilters() -> [AdaptiveFilter] {
        return userProfile.speakerPreferences
            .filter { $0.value > Configuration.confidenceThreshold }
            .map { speaker, score in
                AdaptiveFilter(
                    type: .speaker,
                    value: speaker,
                    relevanceScore: score,
                    usageCount: 0,
                    lastUsed: nil,
                    autoSuggest: true
                )
            }
    }
    
    func generateTopicFilters() -> [AdaptiveFilter] {
        return userProfile.topicPreferences
            .filter { $0.value > Configuration.confidenceThreshold }
            .map { topic, score in
                AdaptiveFilter(
                    type: .topic,
                    value: topic,
                    relevanceScore: score,
                    usageCount: 0,
                    lastUsed: nil,
                    autoSuggest: true
                )
            }
    }
    
    func generateTemporalFilters() -> [AdaptiveFilter] {
        // Generate temporal filters based on viewing patterns
        return []
    }
    
    func generateSourceFilters() -> [AdaptiveFilter] {
        return userProfile.sourcePreferences
            .filter { $0.value > Configuration.confidenceThreshold }
            .map { source, score in
                AdaptiveFilter(
                    type: .source,
                    value: source,
                    relevanceScore: score,
                    usageCount: 0,
                    lastUsed: nil,
                    autoSuggest: true
                )
            }
    }
    
    func generatePersonalizedTopics() async -> [PersonalizedTopic] {
        // Generate personalized topics based on user preferences
        return []
    }
    
    func generateQuickActions() -> [QuickAction] {
        // Generate quick actions based on user behavior
        return []
    }
    
    func getRecentActivity() -> [ActivityItem] {
        // Get recent user activity
        return []
    }
    
    func getTrendingInUserInterests() async -> [TrendingItem] {
        // Get trending content in user's areas of interest
        return []
    }
    
    func generateSuggestedSearches() async -> [String] {
        // Generate suggested searches based on user preferences
        return []
    }
}

// MARK: - UserAction Extension

extension UserAction {
    static func learning(interaction: InteractionType) -> UserAction {
        return UserAction(rawValue: "learning_\(interaction.rawValue)") ?? .appLaunch
    }
}
