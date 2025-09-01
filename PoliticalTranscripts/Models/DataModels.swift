import Foundation

// MARK: - Video Data Model
struct VideoModel: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String?
    let url: URL
    let thumbnailURL: URL?
    let duration: TimeInterval
    let publishedDate: Date
    let speaker: String?
    let source: String?
    let category: String?
    let tags: [String]?
    let viewCount: Int?
    let isLive: Bool?
    let language: String?
    var transcriptSegments: [TranscriptSegmentModel]?
    
    // Computed properties
    var formattedDuration: String {
        duration.formattedDuration
    }
    
    var formattedPublishedDate: String {
        publishedDate.formattedString()
    }
    
    var isRecent: Bool {
        publishedDate.isWithinLastWeek
    }
    
    var hasTranscript: Bool {
        transcriptSegments?.isEmpty == false
    }
    
    var transcriptWordCount: Int {
        transcriptSegments?.reduce(0) { $0 + $1.text.split(separator: " ").count } ?? 0
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, url, thumbnailURL, duration, publishedDate, speaker, source, category, tags, viewCount, isLive, language, transcriptSegments
    }
}

// MARK: - Transcript Segment Data Model
struct TranscriptSegmentModel: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let speaker: String?
    let confidence: Double?
    let isHighlighted: Bool?
    let wordTimestamps: [WordTimestamp]?
    
    // Computed properties
    var duration: TimeInterval {
        endTime - startTime
    }
    
    var formattedStartTime: String {
        startTime.formattedDuration
    }
    
    var formattedEndTime: String {
        endTime.formattedDuration
    }
    
    var formattedTimeRange: String {
        "\(formattedStartTime) - \(formattedEndTime)"
    }
    
    var wordCount: Int {
        text.split(separator: " ").count
    }
    
    var hasHighConfidence: Bool {
        (confidence ?? 0) > 0.8
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, startTime, endTime, speaker, confidence, isHighlighted, wordTimestamps
    }
}

// MARK: - Word Timestamp Model
struct WordTimestamp: Codable, Hashable {
    let word: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case word, startTime, endTime, confidence
    }
}

// MARK: - Playlist Data Model
struct PlaylistModel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String?
    let createdDate: Date
    let updatedDate: Date?
    let isPublic: Bool
    let thumbnailURL: URL?
    let createdBy: String?
    var videos: [VideoModel]
    
    // Computed properties
    var videoCount: Int {
        videos.count
    }
    
    var totalDuration: TimeInterval {
        videos.reduce(0) { $0 + $1.duration }
    }
    
    var formattedTotalDuration: String {
        totalDuration.formattedDuration
    }
    
    var formattedCreatedDate: String {
        createdDate.formattedString()
    }
    
    var isEmpty: Bool {
        videos.isEmpty
    }
    
    var recentVideos: [VideoModel] {
        videos.filter { $0.isRecent }.sorted { $0.publishedDate > $1.publishedDate }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, createdDate, updatedDate, isPublic, thumbnailURL, createdBy, videos
    }
}

// MARK: - Search Result Data Model
struct SearchResultModel: Identifiable, Codable, Hashable {
    let id: String
    let video: VideoModel
    let matchingSegments: [TranscriptSegmentModel]
    let relevanceScore: Double
    let matchType: MatchType
    let highlightedText: String?
    
    // Computed properties
    var hasHighRelevance: Bool {
        relevanceScore > 0.8
    }
    
    var matchCount: Int {
        matchingSegments.count
    }
    
    var formattedRelevanceScore: String {
        String(format: "%.1f%%", relevanceScore * 100)
    }
    
    var firstMatchTime: TimeInterval? {
        matchingSegments.first?.startTime
    }
    
    var lastMatchTime: TimeInterval? {
        matchingSegments.last?.endTime
    }
    
    enum MatchType: String, Codable, CaseIterable {
        case exact = "exact"
        case phrase = "phrase"
        case semantic = "semantic"
        case speaker = "speaker"
        case contextual = "contextual"
        
        var displayName: String {
            switch self {
            case .exact: return "Exact Match"
            case .phrase: return "Phrase Match"
            case .semantic: return "Semantic Match"
            case .speaker: return "Speaker Match"
            case .contextual: return "Contextual Match"
            }
        }
        
        var priority: Int {
            switch self {
            case .exact: return 5
            case .phrase: return 4
            case .speaker: return 3
            case .semantic: return 2
            case .contextual: return 1
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, video, matchingSegments, relevanceScore, matchType, highlightedText
    }
}

// MARK: - Search Request Data Model
struct SearchRequest: Codable {
    let query: String
    let filters: SearchFilterModel
    let page: Int
    let pageSize: Int
    let sortBy: SearchFilterModel.SortOption
    let sortOrder: SearchFilterModel.SortOrder
    
    enum CodingKeys: String, CodingKey {
        case query, filters, page, pageSize, sortBy, sortOrder
    }
}

// MARK: - Search Response Data Model
struct SearchResponse: Codable {
    let results: [SearchResultModel]
    let totalResults: Int
    let currentPage: Int
    let totalPages: Int
    let hasMoreResults: Bool
    let searchId: String?
    let executionTime: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case results, totalResults, currentPage, totalPages, hasMoreResults, searchId, executionTime
    }
}

// MARK: - Search Filter Data Model
struct SearchFilterModel: Codable, Hashable {
    var dateRange: DateRange?
    var speakers: [String]
    var sources: [String]
    var categories: [String]
    var tags: [String]?
    var durationRange: DurationRange?
    var language: String?
    var sortBy: SortOption
    var sortOrder: SortOrder
    var minRelevanceScore: Double?
    var includeTranscript: Bool
    
    struct DateRange: Codable, Hashable {
        let startDate: Date
        let endDate: Date
        
        var isValid: Bool {
            startDate <= endDate
        }
        
        var duration: TimeInterval {
            endDate.timeIntervalSince(startDate)
        }
        
        var formattedRange: String {
            "\(startDate.formattedString()) - \(endDate.formattedString())"
        }
    }
    
    struct DurationRange: Codable, Hashable {
        let minDuration: TimeInterval
        let maxDuration: TimeInterval
        
        var isValid: Bool {
            minDuration <= maxDuration
        }
        
        var formattedRange: String {
            "\(minDuration.durationDescription) - \(maxDuration.durationDescription)"
        }
    }
    
    enum SortOption: String, Codable, CaseIterable {
        case relevance = "relevance"
        case date = "date"
        case duration = "duration"
        case title = "title"
        case speaker = "speaker"
        case viewCount = "view_count"
        
        var displayName: String {
            switch self {
            case .relevance: return "Relevance"
            case .date: return "Date"
            case .duration: return "Duration"
            case .title: return "Title"
            case .speaker: return "Speaker"
            case .viewCount: return "View Count"
            }
        }
    }
    
    enum SortOrder: String, Codable, CaseIterable {
        case ascending = "asc"
        case descending = "desc"
        
        var displayName: String {
            switch self {
            case .ascending: return "Ascending"
            case .descending: return "Descending"
            }
        }
    }
    
    // Computed properties
    var hasActiveFilters: Bool {
        dateRange != nil ||
        !speakers.isEmpty ||
        !sources.isEmpty ||
        !categories.isEmpty ||
        !(tags?.isEmpty ?? true) ||
        durationRange != nil ||
        language != nil ||
        minRelevanceScore != nil
    }
    
    var activeFilterCount: Int {
        var count = 0
        if dateRange != nil { count += 1 }
        if !speakers.isEmpty { count += 1 }
        if !sources.isEmpty { count += 1 }
        if !categories.isEmpty { count += 1 }
        if !(tags?.isEmpty ?? true) { count += 1 }
        if durationRange != nil { count += 1 }
        if language != nil { count += 1 }
        if minRelevanceScore != nil { count += 1 }
        return count
    }
    
    init() {
        self.speakers = []
        self.sources = []
        self.categories = []
        self.tags = []
        self.sortBy = .relevance
        self.sortOrder = .descending
        self.includeTranscript = true
    }
    
    // Reset all filters
    mutating func reset() {
        dateRange = nil
        speakers.removeAll()
        sources.removeAll()
        categories.removeAll()
        tags?.removeAll()
        durationRange = nil
        language = nil
        minRelevanceScore = nil
        sortBy = .relevance
        sortOrder = .descending
        includeTranscript = true
    }
}

// MARK: - Search Suggestion Model
struct SearchSuggestionModel: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let type: SuggestionType
    let frequency: Int?
    let category: String?
    
    enum SuggestionType: String, Codable, CaseIterable {
        case query = "query"
        case speaker = "speaker"
        case topic = "topic"
        case location = "location"
        case organization = "organization"
        
        var displayName: String {
            switch self {
            case .query: return "Search Query"
            case .speaker: return "Speaker"
            case .topic: return "Topic"
            case .location: return "Location"
            case .organization: return "Organization"
            }
        }
        
        var icon: String {
            switch self {
            case .query: return "magnifyingglass"
            case .speaker: return "person"
            case .topic: return "tag"
            case .location: return "location"
            case .organization: return "building"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, type, frequency, category
    }
}

// MARK: - Video Analytics Model
struct VideoAnalyticsModel: Codable, Hashable {
    let videoId: String
    let viewCount: Int
    let averageWatchTime: TimeInterval
    let completionRate: Double
    let mostWatchedSegments: [TranscriptSegmentModel]
    let searchAppearances: Int
    let playlistAppearances: Int
    let lastViewed: Date?
    
    var formattedAverageWatchTime: String {
        averageWatchTime.formattedDuration
    }
    
    var formattedCompletionRate: String {
        String(format: "%.1f%%", completionRate * 100)
    }
    
    enum CodingKeys: String, CodingKey {
        case videoId, viewCount, averageWatchTime, completionRate, mostWatchedSegments, searchAppearances, playlistAppearances, lastViewed
    }
}

// MARK: - Search History Model
struct SearchHistoryItem: Codable, Identifiable, Hashable {
    let id: String
    let query: String
    let filters: SearchFilterModel?
    let searchDate: Date
    let resultCount: Int
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: searchDate)
    }
    
    var displayText: String {
        if let filters = filters, filters.hasActiveFilters {
            return "\(query) (filtered)"
        }
        return query
    }
}

// MARK: - Political Transcript Model
struct PoliticalTranscript: Identifiable, Codable {
    let id: UUID
    let title: String
    let speaker: String
    let date: Date
    let content: String
    let tags: [String]
    let duration: TimeInterval
    
    init(id: UUID = UUID(), title: String, speaker: String, date: Date, content: String, tags: [String], duration: TimeInterval) {
        self.id = id
        self.title = title
        self.speaker = speaker
        self.date = date
        self.content = content
        self.tags = tags
        self.duration = duration
    }
}
