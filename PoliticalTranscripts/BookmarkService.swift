//
//  BookmarkService.swift
//  PoliticalTranscripts
//
//  Advanced bookmark and collection management system with intelligent categorization,
//  collaborative features, and comprehensive export capabilities.
//

import Foundation
import Combine
import CloudKit

/// Advanced bookmark and collection management service with intelligent organization
@MainActor
class BookmarkService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var bookmarks: [BookmarkModel] = []
    @Published var collections: [CollectionModel] = []
    @Published var sharedCollections: [SharedCollectionModel] = []
    @Published var recentBookmarks: [BookmarkModel] = []
    @Published var isLoading: Bool = false
    @Published var syncStatus: SyncStatus = .idle
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let cloudKitService: CloudKitService
    private let analyticsService: AnalyticsService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private struct Configuration {
        static let maxBookmarksPerCollection = 500
        static let maxRecentBookmarks = 50
        static let autoSyncInterval: TimeInterval = 300 // 5 minutes
        static let exportBatchSize = 100
        static let sharedCollectionCacheExpiration: TimeInterval = 3600 // 1 hour
    }
    
    // MARK: - Initialization
    init(cloudKitService: CloudKitService, analyticsService: AnalyticsService) {
        self.cloudKitService = cloudKitService
        self.analyticsService = analyticsService
        
        setupBookmarkService()
        loadLocalData()
        setupAutoSync()
    }
    
    // MARK: - Bookmark Management
    
    /// Adds a new bookmark with intelligent categorization
    /// - Parameters:
    ///   - transcript: The transcript to bookmark
    ///   - collection: Optional collection to add to
    ///   - tags: Optional custom tags
    ///   - note: Optional user note
    /// - Returns: The created bookmark
    @discardableResult
    func addBookmark(
        _ transcript: VideoModel,
        to collection: CollectionModel? = nil,
        tags: [String] = [],
        note: String? = nil
    ) async -> BookmarkModel {
        
        // Create bookmark with intelligent metadata
        let bookmark = BookmarkModel(
            transcript: transcript,
            collectionId: collection?.id,
            tags: tags.isEmpty ? await generateSmartTags(for: transcript) : tags,
            note: note,
            createdAt: Date(),
            lastAccessed: Date(),
            accessCount: 0,
            smartCategory: await determineSmartCategory(for: transcript),
            relevanceScore: await calculateRelevanceScore(for: transcript)
        )
        
        // Add to local storage
        bookmarks.append(bookmark)
        updateRecentBookmarks(bookmark)
        
        // Add to specified collection
        if let collection = collection {
            await addBookmarkToCollection(bookmark, collection: collection)
        } else {
            // Auto-assign to smart collection if none specified
            if let smartCollection = await findOrCreateSmartCollection(for: bookmark) {
                await addBookmarkToCollection(bookmark, collection: smartCollection)
            }
        }
        
        // Save and sync
        saveBookmarksLocally()
        await syncBookmarkToCloud(bookmark)
        
        // Track analytics
        await analyticsService.trackUserAction(
            .bookmark,
            context: .content
        )
        
        return bookmark
    }
    
    /// Removes a bookmark from all collections and storage
    /// - Parameter bookmark: The bookmark to remove
    func removeBookmark(_ bookmark: BookmarkModel) async {
        // Remove from collections
        for collection in collections where collection.bookmarkIds.contains(bookmark.id) {
            await removeBookmarkFromCollection(bookmark, collection: collection)
        }
        
        // Remove from main array
        bookmarks.removeAll { $0.id == bookmark.id }
        recentBookmarks.removeAll { $0.id == bookmark.id }
        
        // Save and sync
        saveBookmarksLocally()
        await removeBookmarkFromCloud(bookmark)
        
        await analyticsService.trackUserAction(
            .removeBookmark,
            context: .content
        )
    }
    
    /// Updates bookmark metadata and resync
    /// - Parameter bookmark: The bookmark to update
    func updateBookmark(_ bookmark: BookmarkModel) async {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index] = bookmark
            saveBookmarksLocally()
            await syncBookmarkToCloud(bookmark)
        }
    }
    
    /// Marks bookmark as accessed for analytics and smart ordering
    /// - Parameter bookmark: The accessed bookmark
    func markBookmarkAccessed(_ bookmark: BookmarkModel) async {
        var updatedBookmark = bookmark
        updatedBookmark.lastAccessed = Date()
        updatedBookmark.accessCount += 1
        
        await updateBookmark(updatedBookmark)
        updateRecentBookmarks(updatedBookmark)
        
        await analyticsService.trackContentEngagement(
            bookmark.transcript,
            duration: 0 // Actual duration would be tracked separately
        )
    }
    
    // MARK: - Collection Management
    
    /// Creates a new collection with smart organization features
    /// - Parameters:
    ///   - name: Collection name
    ///   - description: Collection description
    ///   - category: Collection category
    ///   - isPrivate: Privacy setting
    ///   - autoOrganize: Enable automatic bookmark organization
    /// - Returns: The created collection
    @discardableResult
    func createCollection(
        name: String,
        description: String,
        category: CollectionCategory = .general,
        isPrivate: Bool = true,
        autoOrganize: Bool = false
    ) async -> CollectionModel {
        
        let collection = CollectionModel(
            name: name,
            description: description,
            category: category,
            isPrivate: isPrivate,
            autoOrganize: autoOrganize,
            createdAt: Date(),
            lastModified: Date(),
            bookmarkIds: [],
            tags: [],
            shareSettings: ShareSettings(),
            analyticsData: CollectionAnalytics()
        )
        
        collections.append(collection)
        saveCollectionsLocally()
        await syncCollectionToCloud(collection)
        
        await analyticsService.trackUserAction(
            .createCollection(name: name, category: category.rawValue),
            context: .content
        )
        
        return collection
    }
    
    /// Deletes a collection and handles bookmark reassignment
    /// - Parameters:
    ///   - collection: The collection to delete
    ///   - reassignBookmarks: Whether to reassign bookmarks to other collections
    func deleteCollection(_ collection: CollectionModel, reassignBookmarks: Bool = true) async {
        
        if reassignBookmarks {
            await reassignBookmarksFromDeletedCollection(collection)
        }
        
        collections.removeAll { $0.id == collection.id }
        saveCollectionsLocally()
        await removeCollectionFromCloud(collection)
        
        await analyticsService.trackUserAction(
            .deleteCollection(name: collection.name),
            context: .content
        )
    }
    
    /// Adds a bookmark to a specific collection
    /// - Parameters:
    ///   - bookmark: The bookmark to add
    ///   - collection: The target collection
    func addBookmarkToCollection(_ bookmark: BookmarkModel, collection: CollectionModel) async {
        guard !collection.bookmarkIds.contains(bookmark.id) else { return }
        
        var updatedCollection = collection
        updatedCollection.bookmarkIds.append(bookmark.id)
        updatedCollection.lastModified = Date()
        updatedCollection.analyticsData.bookmarkCount = updatedCollection.bookmarkIds.count
        
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index] = updatedCollection
            saveCollectionsLocally()
            await syncCollectionToCloud(updatedCollection)
        }
    }
    
    /// Removes a bookmark from a specific collection
    /// - Parameters:
    ///   - bookmark: The bookmark to remove
    ///   - collection: The source collection
    func removeBookmarkFromCollection(_ bookmark: BookmarkModel, collection: CollectionModel) async {
        var updatedCollection = collection
        updatedCollection.bookmarkIds.removeAll { $0 == bookmark.id }
        updatedCollection.lastModified = Date()
        updatedCollection.analyticsData.bookmarkCount = updatedCollection.bookmarkIds.count
        
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index] = updatedCollection
            saveCollectionsLocally()
            await syncCollectionToCloud(updatedCollection)
        }
    }
    
    // MARK: - Sharing and Collaboration
    
    /// Shares a collection with specified permissions
    /// - Parameters:
    ///   - collection: The collection to share
    ///   - shareType: Type of sharing (link, email, etc.)
    ///   - permissions: Access permissions for shared users
    /// - Returns: Shareable link or identifier
    func shareCollection(
        _ collection: CollectionModel,
        shareType: ShareType = .publicLink,
        permissions: SharePermissions = .readOnly
    ) async -> ShareableLink {
        
        var updatedCollection = collection
        updatedCollection.shareSettings.isShared = true
        updatedCollection.shareSettings.shareType = shareType
        updatedCollection.shareSettings.permissions = permissions
        updatedCollection.shareSettings.sharedAt = Date()
        updatedCollection.shareSettings.shareId = UUID().uuidString
        
        // Update local collection
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index] = updatedCollection
            saveCollectionsLocally()
        }
        
        // Create shareable link
        let shareableLink = ShareableLink(
            id: updatedCollection.shareSettings.shareId!,
            collectionId: collection.id,
            shareType: shareType,
            permissions: permissions,
            expiresAt: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            createdAt: Date(),
            accessCount: 0
        )
        
        // Sync to cloud for sharing
        await syncSharedCollectionToCloud(updatedCollection, shareableLink: shareableLink)
        
        await analyticsService.trackUserAction(
            .shareCollection(name: collection.name, type: shareType.rawValue),
            context: .social
        )
        
        return shareableLink
    }
    
    /// Loads a shared collection from a shareable link
    /// - Parameter shareableLink: The link to the shared collection
    /// - Returns: The shared collection if accessible
    func loadSharedCollection(from shareableLink: ShareableLink) async -> SharedCollectionModel? {
        do {
            let sharedCollection = try await cloudKitService.loadSharedCollection(shareableLink.id)
            
            // Add to shared collections
            if !sharedCollections.contains(where: { $0.id == sharedCollection.id }) {
                sharedCollections.append(sharedCollection)
            }
            
            await analyticsService.trackUserAction(
                .accessSharedCollection(id: shareableLink.id),
                context: .social
            )
            
            return sharedCollection
            
        } catch {
            await analyticsService.trackError(error, context: .social)
            return nil
        }
    }
    
    // MARK: - Export and Import
    
    /// Exports collection to specified format
    /// - Parameters:
    ///   - collection: The collection to export
    ///   - format: Export format (PDF, JSON, CSV, etc.)
    ///   - includeNotes: Whether to include user notes
    ///   - includeMetadata: Whether to include metadata
    /// - Returns: URL to the exported file
    func exportCollection(
        _ collection: CollectionModel,
        format: ExportFormat,
        includeNotes: Bool = true,
        includeMetadata: Bool = true
    ) async -> URL? {
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get bookmarks for collection
            let collectionBookmarks = getBookmarksForCollection(collection)
            
            // Generate export data
            let exportData = await generateExportData(
                bookmarks: collectionBookmarks,
                collection: collection,
                format: format,
                includeNotes: includeNotes,
                includeMetadata: includeMetadata
            )
            
            // Create export file
            let exportURL = try await createExportFile(
                data: exportData,
                collection: collection,
                format: format
            )
            
            await analyticsService.trackUserAction(
                .exportCollection(name: collection.name, format: format.rawValue),
                context: .content
            )
            
            return exportURL
            
        } catch {
            await analyticsService.trackError(error, context: .content)
            return nil
        }
    }
    
    /// Imports bookmarks from a file
    /// - Parameters:
    ///   - fileURL: URL to the import file
    ///   - targetCollection: Optional target collection
    /// - Returns: Number of successfully imported bookmarks
    func importBookmarks(from fileURL: URL, to targetCollection: CollectionModel? = nil) async -> Int {
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let importData = try Data(contentsOf: fileURL)
            let bookmarksData = try JSONDecoder().decode([BookmarkImportData].self, from: importData)
            
            var importedCount = 0
            
            for bookmarkData in bookmarksData {
                if let transcript = await resolveTranscript(from: bookmarkData) {
                    await addBookmark(
                        transcript,
                        to: targetCollection,
                        tags: bookmarkData.tags,
                        note: bookmarkData.note
                    )
                    importedCount += 1
                }
            }
            
            await analyticsService.trackUserAction(
                .importBookmarks(count: importedCount),
                context: .content
            )
            
            return importedCount
            
        } catch {
            await analyticsService.trackError(error, context: .content)
            return 0
        }
    }
    
    // MARK: - Search and Organization
    
    /// Searches bookmarks with advanced filtering
    /// - Parameter query: Search query with filters
    /// - Returns: Filtered bookmarks
    func searchBookmarks(_ query: BookmarkSearchQuery) async -> [BookmarkModel] {
        var results = bookmarks
        
        // Text search
        if !query.searchText.isEmpty {
            results = results.filter { bookmark in
                bookmark.transcript.title.localizedCaseInsensitiveContains(query.searchText) ||
                bookmark.transcript.speaker.localizedCaseInsensitiveContains(query.searchText) ||
                bookmark.tags.contains { $0.localizedCaseInsensitiveContains(query.searchText) } ||
                (bookmark.note?.localizedCaseInsensitiveContains(query.searchText) ?? false)
            }
        }
        
        // Collection filter
        if let collectionId = query.collectionId {
            results = results.filter { $0.collectionId == collectionId }
        }
        
        // Category filter
        if let category = query.category {
            results = results.filter { $0.smartCategory == category }
        }
        
        // Date range filter
        if let startDate = query.startDate {
            results = results.filter { $0.transcript.date >= startDate }
        }
        
        if let endDate = query.endDate {
            results = results.filter { $0.transcript.date <= endDate }
        }
        
        // Tag filter
        if !query.tags.isEmpty {
            results = results.filter { bookmark in
                query.tags.allSatisfy { queryTag in
                    bookmark.tags.contains { $0.localizedCaseInsensitiveContains(queryTag) }
                }
            }
        }
        
        // Sort results
        switch query.sortBy {
        case .dateCreated:
            results.sort { $0.createdAt > $1.createdAt }
        case .dateAccessed:
            results.sort { $0.lastAccessed > $1.lastAccessed }
        case .relevance:
            results.sort { $0.relevanceScore > $1.relevanceScore }
        case .title:
            results.sort { $0.transcript.title < $1.transcript.title }
        case .accessCount:
            results.sort { $0.accessCount > $1.accessCount }
        }
        
        return results
    }
    
    /// Organizes bookmarks automatically based on smart categorization
    /// - Parameter collection: Optional collection to organize
    func organizeBookmarksAutomatically(_ collection: CollectionModel? = nil) async {
        let targetBookmarks = collection != nil ? getBookmarksForCollection(collection!) : bookmarks
        
        for bookmark in targetBookmarks {
            let smartCategory = await determineSmartCategory(for: bookmark.transcript)
            
            if bookmark.smartCategory != smartCategory {
                var updatedBookmark = bookmark
                updatedBookmark.smartCategory = smartCategory
                await updateBookmark(updatedBookmark)
            }
        }
        
        await analyticsService.trackUserAction(
            .organizeBookmarks,
            context: .content
        )
    }
}

// MARK: - Supporting Types

/// Bookmark model with intelligent metadata
struct BookmarkModel: Codable, Identifiable, Hashable {
    let id: UUID = UUID()
    let transcript: VideoModel
    var collectionId: UUID?
    var tags: [String]
    var note: String?
    let createdAt: Date
    var lastAccessed: Date
    var accessCount: Int
    var smartCategory: SmartCategory
    var relevanceScore: Double
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BookmarkModel, rhs: BookmarkModel) -> Bool {
        lhs.id == rhs.id
    }
}

/// Collection model with advanced features
struct CollectionModel: Codable, Identifiable {
    let id: UUID = UUID()
    var name: String
    var description: String
    var category: CollectionCategory
    var isPrivate: Bool
    var autoOrganize: Bool
    let createdAt: Date
    var lastModified: Date
    var bookmarkIds: [UUID]
    var tags: [String]
    var shareSettings: ShareSettings
    var analyticsData: CollectionAnalytics
    
    var bookmarkCount: Int {
        bookmarkIds.count
    }
}

/// Shared collection model for collaborative features
struct SharedCollectionModel: Codable, Identifiable {
    let id: UUID
    let originalCollectionId: UUID
    let name: String
    let description: String
    let ownerName: String
    let bookmarks: [BookmarkModel]
    let shareSettings: ShareSettings
    let accessedAt: Date
    var localCopyExists: Bool
}

/// Smart categorization for bookmarks
enum SmartCategory: String, Codable, CaseIterable {
    case presidentialSpeeches = "presidential_speeches"
    case congressionalHearings = "congressional_hearings"
    case pressConferences = "press_conferences"
    case debates = "debates"
    case interviews = "interviews"
    case campaignEvents = "campaign_events"
    case policyAnnouncements = "policy_announcements"
    case internationalDiplomacy = "international_diplomacy"
    case emergency = "emergency"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .presidentialSpeeches: return "Presidential Speeches"
        case .congressionalHearings: return "Congressional Hearings"
        case .pressConferences: return "Press Conferences"
        case .debates: return "Debates"
        case .interviews: return "Interviews"
        case .campaignEvents: return "Campaign Events"
        case .policyAnnouncements: return "Policy Announcements"
        case .internationalDiplomacy: return "International Diplomacy"
        case .emergency: return "Emergency Briefings"
        case .general: return "General"
        }
    }
    
    var icon: String {
        switch self {
        case .presidentialSpeeches: return "building.columns.circle"
        case .congressionalHearings: return "person.3.sequence"
        case .pressConferences: return "megaphone.circle"
        case .debates: return "quote.bubble"
        case .interviews: return "mic.circle"
        case .campaignEvents: return "flag.circle"
        case .policyAnnouncements: return "doc.text.circle"
        case .internationalDiplomacy: return "globe.circle"
        case .emergency: return "exclamationmark.triangle.circle"
        case .general: return "folder.circle"
        }
    }
}

/// Collection categories for organization
enum CollectionCategory: String, Codable, CaseIterable {
    case general = "general"
    case research = "research"
    case favorites = "favorites"
    case work = "work"
    case academic = "academic"
    case personal = "personal"
    case shared = "shared"
    case archived = "archived"
    
    var displayName: String {
        rawValue.capitalized
    }
}

/// Export format options
enum ExportFormat: String, Codable, CaseIterable {
    case pdf = "pdf"
    case json = "json"
    case csv = "csv"
    case html = "html"
    case markdown = "markdown"
    
    var fileExtension: String {
        return rawValue
    }
    
    var mimeType: String {
        switch self {
        case .pdf: return "application/pdf"
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .html: return "text/html"
        case .markdown: return "text/markdown"
        }
    }
}

/// Share settings for collections
struct ShareSettings: Codable {
    var isShared: Bool = false
    var shareType: ShareType = .privateLink
    var permissions: SharePermissions = .readOnly
    var shareId: String?
    var sharedAt: Date?
    var expiresAt: Date?
    var allowComments: Bool = false
    var allowDownload: Bool = false
}

/// Sharing types
enum ShareType: String, Codable {
    case privateLink = "private_link"
    case publicLink = "public_link"
    case email = "email"
    case social = "social"
}

/// Share permissions
enum SharePermissions: String, Codable {
    case readOnly = "read_only"
    case comment = "comment"
    case edit = "edit"
    case admin = "admin"
}

/// Shareable link model
struct ShareableLink: Codable {
    let id: String
    let collectionId: UUID
    let shareType: ShareType
    let permissions: SharePermissions
    let expiresAt: Date?
    let createdAt: Date
    var accessCount: Int
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    var shareURL: URL? {
        URL(string: "https://app.politicaltranscripts.com/shared/\(id)")
    }
}

/// Collection analytics data
struct CollectionAnalytics: Codable {
    var bookmarkCount: Int = 0
    var totalViews: Int = 0
    var lastAccessed: Date = Date()
    var averageAccessFrequency: Double = 0
    var popularTags: [String: Int] = [:]
    var growthRate: Double = 0
}

/// Bookmark search query
struct BookmarkSearchQuery {
    var searchText: String = ""
    var collectionId: UUID?
    var category: SmartCategory?
    var startDate: Date?
    var endDate: Date?
    var tags: [String] = []
    var sortBy: BookmarkSortOption = .dateCreated
}

/// Bookmark sorting options
enum BookmarkSortOption: String, CaseIterable {
    case dateCreated = "date_created"
    case dateAccessed = "date_accessed"
    case relevance = "relevance"
    case title = "title"
    case accessCount = "access_count"
    
    var displayName: String {
        switch self {
        case .dateCreated: return "Date Created"
        case .dateAccessed: return "Recently Accessed"
        case .relevance: return "Relevance"
        case .title: return "Title"
        case .accessCount: return "Most Accessed"
        }
    }
}

/// Import data structure
struct BookmarkImportData: Codable {
    let transcriptId: String
    let title: String
    let speaker: String
    let url: String?
    let tags: [String]
    let note: String?
    let createdAt: Date
}

/// Sync status for cloud synchronization
enum SyncStatus: String {
    case idle = "idle"
    case syncing = "syncing"
    case success = "success"
    case error = "error"
}

// MARK: - UserAction Extensions

extension UserAction {
    static let bookmark = UserAction(rawValue: "bookmark") ?? .appLaunch
    static let removeBookmark = UserAction(rawValue: "remove_bookmark") ?? .appLaunch
    static let organizeBookmarks = UserAction(rawValue: "organize_bookmarks") ?? .appLaunch
    static let importBookmarks = UserAction(rawValue: "import_bookmarks") ?? .appLaunch
    
    static func createCollection(name: String, category: String) -> UserAction {
        return UserAction(rawValue: "create_collection") ?? .appLaunch
    }
    
    static func deleteCollection(name: String) -> UserAction {
        return UserAction(rawValue: "delete_collection") ?? .appLaunch
    }
    
    static func shareCollection(name: String, type: String) -> UserAction {
        return UserAction(rawValue: "share_collection") ?? .appLaunch
    }
    
    static func accessSharedCollection(id: String) -> UserAction {
        return UserAction(rawValue: "access_shared_collection") ?? .appLaunch
    }
    
    static func exportCollection(name: String, format: String) -> UserAction {
        return UserAction(rawValue: "export_collection") ?? .appLaunch
    }
    
    static func importBookmarks(count: Int) -> UserAction {
        return UserAction(rawValue: "import_bookmarks") ?? .appLaunch
    }
}

// MARK: - CloudKit Service Protocol

protocol CloudKitService {
    func syncBookmark(_ bookmark: BookmarkModel) async throws
    func syncCollection(_ collection: CollectionModel) async throws
    func syncSharedCollection(_ collection: CollectionModel, shareableLink: ShareableLink) async throws
    func loadSharedCollection(_ shareId: String) async throws -> SharedCollectionModel
    func removeBookmark(_ bookmarkId: UUID) async throws
    func removeCollection(_ collectionId: UUID) async throws
}
