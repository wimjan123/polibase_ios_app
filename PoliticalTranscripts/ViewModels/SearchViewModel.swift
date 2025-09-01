import Foundation
import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var searchQuery: String = ""
    @Published var searchResults: [SearchResultModel] = []
    @Published var suggestions: [SearchSuggestionModel] = []
    @Published var filters: SearchFilterModel = SearchFilterModel()
    @Published var recentSearches: [SearchHistoryItem] = []
    
    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var showSuggestions: Bool = false
    @Published var showFilters: Bool = false
    @Published var showError: Bool = false
    @Published var showSearchTips: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Pagination
    @Published var currentPage: Int = 1
    @Published var totalResults: Int = 0
    @Published var hasMoreResults: Bool = false
    @Published var isLoadingMore: Bool = false
    private let pageSize: Int = 20
    private var maxRetries: Int = 3
    
    // MARK: - Private Properties
    private let apiClient = APIClient.shared
    private let cacheService = SuggestionCacheService.shared
    private let persistenceService = SearchPersistenceService.shared
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    private var suggestionTask: Task<Void, Never>?
    
    // MARK: - Debouncing
    private let searchDebounceInterval: TimeInterval = 0.5
    private let suggestionDebounceInterval: TimeInterval = 0.3
    
    // MARK: - Cache
    private var resultCache: [String: [SearchResultModel]] = [:]
    private var suggestionCache: [String: [SearchSuggestionModel]] = [:]
    private let maxCacheSize: Int = 50
    
    // MARK: - Initialization
    init() {
        setupSearchDebouncing()
        setupSuggestionDebouncing()
        loadPersistedData()
    }
    
    // MARK: - Public Methods
    func onSearchQueryChanged() {
        // Cancel previous suggestion task
        suggestionTask?.cancel()
        
        // Show suggestions for non-empty queries
        showSuggestions = !searchQuery.isEmpty && !isLoading
        
        // Hide suggestions immediately for empty queries
        if searchQuery.isEmpty {
            showSuggestions = false
            suggestions = []
            return
        }
        
        // Load suggestions from cache first
        loadCachedSuggestions()
    }
    
    func performSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handleError(SearchError.emptyQuery)
            return
        }
        
        // Cancel previous search
        searchTask?.cancel()
        
        searchTask = Task {
            await executeSearch(isNewSearch: true)
        }
        
        await searchTask?.value
    }
    
    func loadMoreResults() async {
        guard hasMoreResults && !isLoading && !isLoadingMore else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            let request = buildSearchRequest(isNewSearch: false)
            // Execute search with improved error handling
            let response = try await apiClient.searchVideos(
                query: request.query,
                filters: request.filters,
                page: request.page,
                limit: request.pageSize
            )
            
            await MainActor.run {
                // Convert VideoModel responses to SearchResultModel
                let convertedResults = response.data.map { video in
                    SearchResultModel(
                        id: video.id,
                        video: video,
                        matchingSegments: video.transcriptSegments ?? [],
                        relevanceScore: 1.0,
                        matchType: .semantic,
                        highlightedText: nil
                    )
                }
                
                // Append new results
                self.searchResults.append(contentsOf: convertedResults)
                self.hasMoreResults = response.pagination?.hasNext ?? false
                self.totalResults = response.pagination?.total ?? convertedResults.count
                self.isLoadingMore = false
                
                // Cache the combined results
                let cacheKey = generateCacheKey()
                self.resultCache[cacheKey] = self.searchResults
                self.cleanupCache()
            }
        } catch {
            await MainActor.run {
                self.isLoadingMore = false
                self.currentPage -= 1 // Revert page increment
                self.handleError(error)
            }
        }
    }
    
    func refreshResults() async {
        currentPage = 1
        await executeSearch(isNewSearch: true)
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        suggestions = []
        showSuggestions = false
        currentPage = 1
        hasMoreResults = false
    }
    
    func selectSuggestion(_ suggestion: SearchSuggestionModel) {
        searchQuery = suggestion.text
        showSuggestions = false
        
        Task {
            await performSearch()
        }
    }
    
    func selectRecentSearch(_ search: SearchHistoryItem) {
        searchQuery = search.query
        filters = search.filters ?? SearchFilterModel()
        
        Task {
            await performSearch()
        }
    }
    
    func selectSearchResult(_ result: SearchResultModel) {
        // Save to search history
        Task {
            await saveSearchToHistory()
        }
        
        // Navigate to video detail
        // This would typically be handled by the navigation coordinator
        print("Selected video: \(result.video.title)")
    }
    
    // MARK: - Filter Management
    var hasActiveFilters: Bool {
        filters.hasActiveFilters
    }
    
    var activeFilterCount: Int {
        filters.activeFilterCount
    }
    
    var activeFilterTags: [String] {
        var tags: [String] = []
        
        if let dateRange = filters.dateRange {
            tags.append("Date: \(dateRange.formattedRange)")
        }
        
        if !filters.speakers.isEmpty {
            if filters.speakers.count == 1 {
                tags.append("Speaker: \(filters.speakers.first!)")
            } else {
                tags.append("Speakers: \(filters.speakers.count)")
            }
        }
        
        if !filters.sources.isEmpty {
            if filters.sources.count == 1 {
                tags.append("Source: \(filters.sources.first!)")
            } else {
                tags.append("Sources: \(filters.sources.count)")
            }
        }
        
        if !filters.categories.isEmpty {
            if filters.categories.count == 1 {
                tags.append("Category: \(filters.categories.first!)")
            } else {
                tags.append("Categories: \(filters.categories.count)")
            }
        }
        
        if let durationRange = filters.durationRange {
            tags.append("Duration: \(durationRange.formattedRange)")
        }
        
        if let language = filters.language {
            tags.append("Language: \(language)")
        }
        
        if let minScore = filters.minRelevanceScore {
            tags.append("Min Score: \(String(format: "%.0f%%", minScore * 100))")
        }
        
        return tags
    }
    
    func removeFilter(_ tag: String) {
        if tag.starts(with: "Date:") {
            filters.dateRange = nil
        } else if tag.starts(with: "Speaker:") {
            filters.speakers.removeAll()
        } else if tag.starts(with: "Speakers:") {
            filters.speakers.removeAll()
        } else if tag.starts(with: "Source:") {
            filters.sources.removeAll()
        } else if tag.starts(with: "Sources:") {
            filters.sources.removeAll()
        } else if tag.starts(with: "Category:") {
            filters.categories.removeAll()
        } else if tag.starts(with: "Categories:") {
            filters.categories.removeAll()
        } else if tag.starts(with: "Duration:") {
            filters.durationRange = nil
        } else if tag.starts(with: "Language:") {
            filters.language = nil
        } else if tag.starts(with: "Min Score:") {
            filters.minRelevanceScore = nil
        }
        
        // Refresh search with updated filters
        Task {
            await performSearch()
        }
    }
    
    func clearAllFilters() {
        filters.reset()
        
        // Refresh search if there's an active query
        if !searchQuery.isEmpty {
            Task {
                await performSearch()
            }
        }
    }
    
    // MARK: - Search History
    func loadSearchHistory() {
        Task {
            do {
                recentSearches = try await persistenceService.getSearchHistory()
            } catch {
                print("Failed to load search history: \(error)")
            }
        }
    }
    
    private func saveSearchToHistory() async {
        do {
            try await persistenceService.saveSearch(query: searchQuery, filters: filters)
            recentSearches = try await persistenceService.getSearchHistory()
        } catch {
            print("Failed to save search to history: \(error)")
        }
    }
    
    // MARK: - Private Methods
    // MARK: - Private Methods
    private func buildSearchRequest(isNewSearch: Bool) -> SearchRequest {
        return SearchRequest(
            query: searchQuery,
            filters: filters,
            page: currentPage,
            pageSize: pageSize,
            sortBy: filters.sortBy,
            sortOrder: filters.sortOrder
        )
    }
    
    private func generateCacheKey() -> String {
        let filtersHash = String(filters.hashValue)
        return "\(searchQuery.lowercased())_\(filtersHash)_\(currentPage)"
    }
    
    private func cleanupCache() {
        if resultCache.count > maxCacheSize {
            let keysToRemove = Array(resultCache.keys.prefix(resultCache.count - maxCacheSize))
            keysToRemove.forEach { resultCache.removeValue(forKey: $0) }
        }
    }
    
    // MARK: - Enhanced Filter Processing
    
    private func buildAdvancedSearchRequest() -> SearchRequest {
        return SearchRequest(
            query: searchQuery.trimmingCharacters(in: .whitespacesAndNewlines),
            filters: filters,
            page: currentPage,
            pageSize: pageSize,
            sortBy: filters.sortBy,
            sortOrder: filters.sortOrder
        )
    }
    
    private func processAdvancedSearchResponse(_ response: SearchResponse) {
        DispatchQueue.main.async {
            if self.currentPage == 1 {
                // New search - replace results
                self.searchResults = response.results
            } else {
                // Load more - append results
                self.searchResults.append(contentsOf: response.results)
            }
            
            self.totalResults = response.totalResults // Use actual result count
            self.isLoading = false
            self.isLoadingMore = false
            self.hasMoreResults = response.hasMoreResults // Use response property
            
            // Enhanced caching with metadata
            let cacheKey = self.generateCacheKey()
            self.resultCache[cacheKey] = self.searchResults
            self.cleanupCache()
        }
    }
    
    private func setupSearchDebouncing() {
        $searchQuery
            .removeDuplicates()
            .debounce(for: .seconds(searchDebounceInterval), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                guard let self = self, !query.isEmpty else { return }
                
                Task {
                    await self.performSearch()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSuggestionDebouncing() {
        $searchQuery
            .removeDuplicates()
            .debounce(for: .seconds(suggestionDebounceInterval), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                guard let self = self, !query.isEmpty else { return }
                
                self.suggestionTask?.cancel()
                self.suggestionTask = Task {
                    await self.loadSuggestions(for: query)
                }
            }
            .store(in: &cancellables)
    }
    
    private func executeSearch(isNewSearch: Bool) async {
        guard !Task.isCancelled else { return }
        
        if isNewSearch {
            isLoading = true
            if currentPage == 1 {
                searchResults = []
            }
        }
        
        do {
            // Check cache first for new searches
            let cacheKey = createCacheKey(query: searchQuery, filters: filters, page: currentPage)
            
            if isNewSearch, let cachedResults = resultCache[cacheKey] {
                searchResults = cachedResults
                isLoading = false
                return
            }
            
            let response = try await apiClient.searchVideos(
                query: searchQuery,
                filters: filters,
                page: currentPage,
                limit: pageSize
            )
            
            guard !Task.isCancelled else { return }
            
            // Convert VideoModel to SearchResultModel for consistency
            let newResults = response.data.map { video in
                SearchResultModel(
                    id: video.id,
                    video: video,
                    matchingSegments: video.transcriptSegments ?? [],
                    relevanceScore: 1.0,
                    matchType: .semantic,
                    highlightedText: nil
                )
            }
            
            if isNewSearch {
                searchResults = newResults
            } else {
                searchResults.append(contentsOf: newResults)
            }
            
            // Update pagination
            if let pagination = response.pagination {
                hasMoreResults = pagination.hasNext
            } else {
                hasMoreResults = newResults.count == pageSize
            }
            
            // Cache results (cache original VideoModel data)
            cacheResults(key: cacheKey, results: newResults)
            
            // Save successful search to history
            if isNewSearch {
                await saveSearchToHistory()
            }
            
            isLoading = false
            
        } catch {
            guard !Task.isCancelled else { return }
            
            isLoading = false
            handleError(error)
        }
    }
    
    private func loadSuggestions(for query: String) async {
        guard !Task.isCancelled && !query.isEmpty else { return }
        
        do {
            // Check cache first
            if let cachedSuggestions = suggestionCache[query.lowercased()] {
                suggestions = cachedSuggestions
                return
            }
            
            let response = try await apiClient.getSuggestions(query: query)
            
            guard !Task.isCancelled else { return }
            
            let suggestionModels = response.data.enumerated().map { index, suggestionText in
                SearchSuggestionModel(
                    id: "\(query)_\(index)",
                    text: suggestionText,
                    type: .query,
                    frequency: nil,
                    category: nil
                )
            }
            
            suggestions = suggestionModels
            
            // Cache suggestions
            cacheSuggestions(key: query.lowercased(), suggestions: suggestionModels)
            
        } catch {
            guard !Task.isCancelled else { return }
            
            print("Failed to load suggestions: \(error)")
            // Don't show error for suggestions, just use cached/empty results
        }
    }
    
    private func loadCachedSuggestions() {
        if let cachedSuggestions = suggestionCache[searchQuery.lowercased()] {
            suggestions = cachedSuggestions
        }
    }
    
    private func loadPersistedData() {
        // Load cached suggestions asynchronously
        Task {
            let cachedSuggestions = await cacheService.getCachedSuggestions()
            await MainActor.run {
                self.suggestionCache = cachedSuggestions
            }
        }
        
        // Load search history
        loadSearchHistory()
    }
    
    // MARK: - Caching
    private func createCacheKey(query: String, filters: SearchFilterModel, page: Int) -> String {
        let filtersHash = String(filters.hashValue)
        return "\(query)_\(filtersHash)_\(page)"
    }
    
    private func cacheResults(key: String, results: [SearchResultModel]) {
        resultCache[key] = results
        
        // Limit cache size
        if resultCache.count > maxCacheSize {
            let keysToRemove = Array(resultCache.keys.prefix(resultCache.count - maxCacheSize))
            keysToRemove.forEach { resultCache.removeValue(forKey: $0) }
        }
    }
    
    private func cacheSuggestions(key: String, suggestions: [SearchSuggestionModel]) {
        suggestionCache[key] = suggestions
        
        // Persist suggestions cache asynchronously
        Task {
            await cacheService.cacheSuggestions(suggestionCache)
        }
        
        // Limit cache size
        if suggestionCache.count > maxCacheSize {
            let keysToRemove = Array(suggestionCache.keys.prefix(suggestionCache.count - maxCacheSize))
            keysToRemove.forEach { suggestionCache.removeValue(forKey: $0) }
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        let userError = UserFacingError(from: error)
        errorMessage = userError.message
        showError = true
        
        print("Search error: \(error)")
    }
}

// MARK: - Supporting Services
actor SuggestionCacheService {
    static let shared = SuggestionCacheService()
    
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "suggestion_cache"
    private let maxCacheAge: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private init() {}
    
    func getCachedSuggestions() -> [String: [SearchSuggestionModel]] {
        guard let data = userDefaults.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(SuggestionCacheEntry.self, from: data),
              Date().timeIntervalSince(cache.timestamp) < maxCacheAge else {
            return [:]
        }
        
        return cache.suggestions
    }
    
    func cacheSuggestions(_ suggestions: [String: [SearchSuggestionModel]]) {
        let entry = SuggestionCacheEntry(
            suggestions: suggestions,
            timestamp: Date()
        )
        
        if let data = try? JSONEncoder().encode(entry) {
            userDefaults.set(data, forKey: cacheKey)
        }
    }
    
    private struct SuggestionCacheEntry: Codable {
        let suggestions: [String: [SearchSuggestionModel]]
        let timestamp: Date
    }
}

actor SearchPersistenceService {
    static let shared = SearchPersistenceService()
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "search_history"
    private let maxHistoryItems = 50
    
    private init() {}
    
    func getSearchHistory() async throws -> [SearchHistoryItem] {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder.apiDecoder.decode([SearchHistoryItem].self, from: data) else {
            return []
        }
        
        return history.sorted { $0.searchDate > $1.searchDate }
    }
    
    func saveSearch(query: String, filters: SearchFilterModel?) async throws {
        var history = try await getSearchHistory()
        
        // Remove existing entry for the same query to avoid duplicates
        history.removeAll { $0.query.lowercased() == query.lowercased() }
        
        // Add new entry
        let newEntry = SearchHistoryItem(
            id: UUID().uuidString,
            query: query,
            filters: filters,
            searchDate: Date(),
            resultCount: 0 // This would be updated with actual result count
        )
        
        history.insert(newEntry, at: 0)
        
        // Limit history size
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }
        
        // Save updated history
        if let data = try? JSONEncoder.apiEncoder.encode(history) {
            userDefaults.set(data, forKey: historyKey)
        }
    }
    
    func clearSearchHistory() async throws {
        userDefaults.removeObject(forKey: historyKey)
    }
}
