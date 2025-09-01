import Foundation
import CloudKit
import Combine

/// AnnotationService provides comprehensive annotation management with rich text support,
/// collaborative features, and intelligent organization capabilities
@MainActor
class AnnotationService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var annotations: [AnnotationModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var collaborators: [CollaboratorModel] = []
    @Published var sharingPermissions: [String: SharingPermission] = [:]
    
    // MARK: - Private Properties
    private let container: CKContainer
    private let database: CKDatabase
    private let analyticsService: AnalyticsService
    private var cancellables = Set<AnyCancellable>()
    private let annotationCache = NSCache<NSString, AnnotationModel>()
    
    // MARK: - Configuration
    private let maxAnnotationLength = 5000
    private let maxAnnotationsPerVideo = 100
    private let collaborationTimeout: TimeInterval = 30
    
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
        self.container = CKContainer(identifier: "iCloud.PoliticalTranscripts")
        self.database = container.privateCloudDatabase
        
        setupCacheConfiguration()
        setupCollaborationSubscriptions()
    }
    
    // MARK: - Annotation Management
    
    /// Creates a new annotation with rich text support
    func createAnnotation(
        videoId: String,
        timestamp: TimeInterval,
        content: String,
        type: AnnotationType = .note,
        tags: [String] = [],
        isPublic: Bool = false
    ) async throws -> AnnotationModel {
        isLoading = true
        defer { isLoading = false }
        
        guard content.count <= maxAnnotationLength else {
            throw AnnotationError.contentTooLong
        }
        
        let annotation = AnnotationModel(
            id: UUID().uuidString,
            videoId: videoId,
            timestamp: timestamp,
            content: content,
            richTextContent: convertToRichText(content),
            type: type,
            tags: tags,
            authorId: getCurrentUserId(),
            authorName: getCurrentUserName(),
            createdAt: Date(),
            isPublic: isPublic,
            collaborators: isPublic ? [] : [getCurrentUserId()],
            comments: [],
            reactions: [:]
        )
        
        // Validate annotation count
        let existingCount = annotations.filter { $0.videoId == videoId }.count
        guard existingCount < maxAnnotationsPerVideo else {
            throw AnnotationError.tooManyAnnotations
        }
        
        // Save to CloudKit
        try await saveAnnotationToCloud(annotation)
        
        // Update local state
        annotations.append(annotation)
        annotationCache.setObject(annotation, forKey: annotation.id as NSString)
        
        // Track analytics
        await analyticsService.trackAnnotationCreated(
            annotationId: annotation.id,
            videoId: videoId,
            type: type.rawValue,
            isPublic: isPublic,
            contentLength: content.count,
            tagCount: tags.count
        )
        
        return annotation
    }
    
    /// Updates an existing annotation
    func updateAnnotation(
        _ annotationId: String,
        content: String? = nil,
        tags: [String]? = nil,
        type: AnnotationType? = nil
    ) async throws {
        guard let index = annotations.firstIndex(where: { $0.id == annotationId }) else {
            throw AnnotationError.annotationNotFound
        }
        
        var annotation = annotations[index]
        
        // Check permissions
        guard annotation.authorId == getCurrentUserId() || 
              annotation.collaborators.contains(getCurrentUserId()) else {
            throw AnnotationError.insufficientPermissions
        }
        
        if let content = content {
            guard content.count <= maxAnnotationLength else {
                throw AnnotationError.contentTooLong
            }
            annotation.content = content
            annotation.richTextContent = convertToRichText(content)
        }
        
        if let tags = tags {
            annotation.tags = tags
        }
        
        if let type = type {
            annotation.type = type
        }
        
        annotation.updatedAt = Date()
        
        // Save to CloudKit
        try await saveAnnotationToCloud(annotation)
        
        // Update local state
        annotations[index] = annotation
        annotationCache.setObject(annotation, forKey: annotation.id as NSString)
        
        // Track analytics
        await analyticsService.trackAnnotationUpdated(
            annotationId: annotationId,
            changeType: [
                content != nil ? "content" : nil,
                tags != nil ? "tags" : nil,
                type != nil ? "type" : nil
            ].compactMap { $0 }.joined(separator: ",")
        )
    }
    
    /// Deletes an annotation
    func deleteAnnotation(_ annotationId: String) async throws {
        guard let index = annotations.firstIndex(where: { $0.id == annotationId }) else {
            throw AnnotationError.annotationNotFound
        }
        
        let annotation = annotations[index]
        
        // Check permissions
        guard annotation.authorId == getCurrentUserId() else {
            throw AnnotationError.insufficientPermissions
        }
        
        // Delete from CloudKit
        try await deleteAnnotationFromCloud(annotationId)
        
        // Update local state
        annotations.remove(at: index)
        annotationCache.removeObject(forKey: annotationId as NSString)
        
        // Track analytics
        await analyticsService.trackAnnotationDeleted(
            annotationId: annotationId,
            videoId: annotation.videoId
        )
    }
    
    // MARK: - Collaborative Features
    
    /// Shares an annotation with specific users
    func shareAnnotation(
        _ annotationId: String,
        with userIds: [String],
        permission: SharingPermission = .view
    ) async throws {
        guard let index = annotations.firstIndex(where: { $0.id == annotationId }) else {
            throw AnnotationError.annotationNotFound
        }
        
        var annotation = annotations[index]
        
        // Check ownership
        guard annotation.authorId == getCurrentUserId() else {
            throw AnnotationError.insufficientPermissions
        }
        
        // Add collaborators
        for userId in userIds {
            if !annotation.collaborators.contains(userId) {
                annotation.collaborators.append(userId)
            }
            sharingPermissions["\(annotationId):\(userId)"] = permission
        }
        
        annotation.updatedAt = Date()
        
        // Save to CloudKit
        try await saveAnnotationToCloud(annotation)
        
        // Update local state
        annotations[index] = annotation
        
        // Send collaboration invitations
        try await sendCollaborationInvitations(annotationId: annotationId, userIds: userIds)
        
        // Track analytics
        await analyticsService.trackAnnotationShared(
            annotationId: annotationId,
            collaboratorCount: userIds.count,
            permission: permission.rawValue
        )
    }
    
    /// Adds a comment to an annotation
    func addComment(
        to annotationId: String,
        content: String
    ) async throws -> CommentModel {
        guard let index = annotations.firstIndex(where: { $0.id == annotationId }) else {
            throw AnnotationError.annotationNotFound
        }
        
        var annotation = annotations[index]
        
        // Check permissions
        guard annotation.isPublic || 
              annotation.collaborators.contains(getCurrentUserId()) else {
            throw AnnotationError.insufficientPermissions
        }
        
        let comment = CommentModel(
            id: UUID().uuidString,
            content: content,
            authorId: getCurrentUserId(),
            authorName: getCurrentUserName(),
            createdAt: Date(),
            reactions: [:]
        )
        
        annotation.comments.append(comment)
        annotation.updatedAt = Date()
        
        // Save to CloudKit
        try await saveAnnotationToCloud(annotation)
        
        // Update local state
        annotations[index] = annotation
        
        // Track analytics
        await analyticsService.trackCommentAdded(
            annotationId: annotationId,
            commentLength: content.count
        )
        
        return comment
    }
    
    /// Adds a reaction to an annotation
    func addReaction(
        to annotationId: String,
        reaction: ReactionType
    ) async throws {
        guard let index = annotations.firstIndex(where: { $0.id == annotationId }) else {
            throw AnnotationError.annotationNotFound
        }
        
        var annotation = annotations[index]
        let userId = getCurrentUserId()
        
        // Toggle reaction
        if annotation.reactions[userId] == reaction {
            annotation.reactions.removeValue(forKey: userId)
        } else {
            annotation.reactions[userId] = reaction
        }
        
        annotation.updatedAt = Date()
        
        // Save to CloudKit
        try await saveAnnotationToCloud(annotation)
        
        // Update local state
        annotations[index] = annotation
        
        // Track analytics
        await analyticsService.trackReactionAdded(
            annotationId: annotationId,
            reaction: reaction.rawValue,
            totalReactions: annotation.reactions.count
        )
    }
    
    // MARK: - Data Retrieval
    
    /// Loads annotations for a specific video
    func loadAnnotations(for videoId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Check cache first
        let cachedAnnotations = annotations.filter { $0.videoId == videoId }
        if !cachedAnnotations.isEmpty {
            return
        }
        
        // Load from CloudKit
        let predicate = NSPredicate(format: "videoId == %@", videoId)
        let query = CKQuery(recordType: "Annotation", predicate: predicate)
        
        do {
            let (matchResults, _) = try await database.records(matching: query)
            let loadedAnnotations = try matchResults.compactMap { _, result in
                try result.get()
            }.compactMap(convertFromCloudKitRecord)
            
            // Update local state
            let existingIds = Set(annotations.map { $0.id })
            let newAnnotations = loadedAnnotations.filter { !existingIds.contains($0.id) }
            annotations.append(contentsOf: newAnnotations)
            
            // Cache annotations
            for annotation in newAnnotations {
                annotationCache.setObject(annotation, forKey: annotation.id as NSString)
            }
            
            // Track analytics
            await analyticsService.trackAnnotationsLoaded(
                videoId: videoId,
                count: newAnnotations.count
            )
            
        } catch {
            errorMessage = "Failed to load annotations: \(error.localizedDescription)"
            throw AnnotationError.loadFailed
        }
    }
    
    /// Searches annotations by content
    func searchAnnotations(
        query: String,
        videoId: String? = nil,
        type: AnnotationType? = nil,
        tags: [String] = []
    ) async throws -> [AnnotationModel] {
        let filteredAnnotations = annotations.filter { annotation in
            let matchesQuery = query.isEmpty || 
                              annotation.content.localizedCaseInsensitiveContains(query) ||
                              annotation.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            
            let matchesVideo = videoId == nil || annotation.videoId == videoId
            let matchesType = type == nil || annotation.type == type
            let matchesTags = tags.isEmpty || tags.allSatisfy { tag in
                annotation.tags.contains { $0.localizedCaseInsensitiveContains(tag) }
            }
            
            return matchesQuery && matchesVideo && matchesType && matchesTags
        }
        
        // Track analytics
        await analyticsService.trackAnnotationSearch(
            query: query,
            resultCount: filteredAnnotations.count,
            hasVideoFilter: videoId != nil,
            hasTypeFilter: type != nil,
            tagCount: tags.count
        )
        
        return filteredAnnotations.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Export Features
    
    /// Exports annotations to various formats
    func exportAnnotations(
        for videoId: String,
        format: ExportFormat = .json,
        includeCollaborative: Bool = true
    ) async throws -> Data {
        let videoAnnotations = annotations.filter { annotation in
            annotation.videoId == videoId &&
            (includeCollaborative || annotation.authorId == getCurrentUserId())
        }
        
        let exportData: Data
        
        switch format {
        case .json:
            exportData = try JSONEncoder().encode(videoAnnotations)
        case .csv:
            exportData = try convertAnnotationsToCSV(videoAnnotations)
        case .markdown:
            exportData = try convertAnnotationsToMarkdown(videoAnnotations)
        case .pdf:
            exportData = try await convertAnnotationsToPDF(videoAnnotations)
        }
        
        // Track analytics
        await analyticsService.trackAnnotationsExported(
            videoId: videoId,
            format: format.rawValue,
            count: videoAnnotations.count,
            includeCollaborative: includeCollaborative
        )
        
        return exportData
    }
    
    // MARK: - Private Methods
    
    private func setupCacheConfiguration() {
        annotationCache.countLimit = 1000
        annotationCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    private func setupCollaborationSubscriptions() {
        // Set up CloudKit subscriptions for real-time collaboration
        let subscription = CKQuerySubscription(
            recordType: "Annotation",
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        Task {
            do {
                try await database.save(subscription)
            } catch {
                print("Failed to set up collaboration subscription: \(error)")
            }
        }
    }
    
    private func convertToRichText(_ content: String) -> NSAttributedString {
        // Basic rich text conversion - can be enhanced with markdown parsing
        return NSAttributedString(string: content)
    }
    
    private func getCurrentUserId() -> String {
        // Implementation would get current user ID from authentication system
        return "current-user-id"
    }
    
    private func getCurrentUserName() -> String {
        // Implementation would get current user name from authentication system
        return "Current User"
    }
    
    private func saveAnnotationToCloud(_ annotation: AnnotationModel) async throws {
        let record = convertToCloudKitRecord(annotation)
        try await database.save(record)
    }
    
    private func deleteAnnotationFromCloud(_ annotationId: String) async throws {
        let recordID = CKRecord.ID(recordName: annotationId)
        try await database.deleteRecord(withID: recordID)
    }
    
    private func sendCollaborationInvitations(annotationId: String, userIds: [String]) async throws {
        // Implementation would send push notifications or emails to invited users
        for userId in userIds {
            print("Sending collaboration invitation for annotation \(annotationId) to user \(userId)")
        }
    }
    
    private func convertToCloudKitRecord(_ annotation: AnnotationModel) -> CKRecord {
        let record = CKRecord(recordType: "Annotation", recordID: CKRecord.ID(recordName: annotation.id))
        record["videoId"] = annotation.videoId
        record["timestamp"] = annotation.timestamp
        record["content"] = annotation.content
        record["type"] = annotation.type.rawValue
        record["tags"] = annotation.tags
        record["authorId"] = annotation.authorId
        record["authorName"] = annotation.authorName
        record["createdAt"] = annotation.createdAt
        record["updatedAt"] = annotation.updatedAt
        record["isPublic"] = annotation.isPublic
        record["collaborators"] = annotation.collaborators
        return record
    }
    
    private func convertFromCloudKitRecord(_ record: CKRecord) -> AnnotationModel? {
        guard let videoId = record["videoId"] as? String,
              let timestamp = record["timestamp"] as? TimeInterval,
              let content = record["content"] as? String,
              let typeString = record["type"] as? String,
              let type = AnnotationType(rawValue: typeString),
              let tags = record["tags"] as? [String],
              let authorId = record["authorId"] as? String,
              let authorName = record["authorName"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let isPublic = record["isPublic"] as? Bool,
              let collaborators = record["collaborators"] as? [String] else {
            return nil
        }
        
        return AnnotationModel(
            id: record.recordID.recordName,
            videoId: videoId,
            timestamp: timestamp,
            content: content,
            richTextContent: convertToRichText(content),
            type: type,
            tags: tags,
            authorId: authorId,
            authorName: authorName,
            createdAt: createdAt,
            updatedAt: record["updatedAt"] as? Date,
            isPublic: isPublic,
            collaborators: collaborators,
            comments: [], // Comments would be loaded separately
            reactions: [:]  // Reactions would be loaded separately
        )
    }
    
    private func convertAnnotationsToCSV(_ annotations: [AnnotationModel]) throws -> Data {
        var csv = "ID,Video ID,Timestamp,Content,Type,Tags,Author,Created At\n"
        
        for annotation in annotations {
            let row = [
                annotation.id,
                annotation.videoId,
                String(annotation.timestamp),
                "\"" + annotation.content.replacingOccurrences(of: "\"", with: "\"\"") + "\"",
                annotation.type.rawValue,
                "\"" + annotation.tags.joined(separator: ", ") + "\"",
                annotation.authorName,
                annotation.createdAt.ISO8601Format()
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv.data(using: .utf8) ?? Data()
    }
    
    private func convertAnnotationsToMarkdown(_ annotations: [AnnotationModel]) throws -> Data {
        var markdown = "# Annotations Export\n\n"
        
        let groupedAnnotations = Dictionary(grouping: annotations) { $0.videoId }
        
        for (videoId, videoAnnotations) in groupedAnnotations {
            markdown += "## Video: \(videoId)\n\n"
            
            for annotation in videoAnnotations.sorted(by: { $0.timestamp < $1.timestamp }) {
                markdown += "### \(annotation.type.displayName) at \(formatTimestamp(annotation.timestamp))\n"
                markdown += "**Author:** \(annotation.authorName)\n"
                markdown += "**Created:** \(annotation.createdAt.formatted())\n"
                
                if !annotation.tags.isEmpty {
                    markdown += "**Tags:** \(annotation.tags.joined(separator: ", "))\n"
                }
                
                markdown += "\n\(annotation.content)\n\n"
                
                if !annotation.comments.isEmpty {
                    markdown += "**Comments:**\n"
                    for comment in annotation.comments {
                        markdown += "- \(comment.authorName): \(comment.content)\n"
                    }
                    markdown += "\n"
                }
                
                markdown += "---\n\n"
            }
        }
        
        return markdown.data(using: .utf8) ?? Data()
    }
    
    private func convertAnnotationsToPDF(_ annotations: [AnnotationModel]) async throws -> Data {
        // This would integrate with a PDF generation library
        // For now, return a placeholder
        return "PDF export not implemented yet".data(using: .utf8) ?? Data()
    }
    
    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let hours = Int(timestamp) / 3600
        let minutes = Int(timestamp) % 3600 / 60
        let seconds = Int(timestamp) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Data Models

struct AnnotationModel: Identifiable, Codable, Hashable {
    let id: String
    let videoId: String
    let timestamp: TimeInterval
    var content: String
    var richTextContent: NSAttributedString
    var type: AnnotationType
    var tags: [String]
    let authorId: String
    let authorName: String
    let createdAt: Date
    var updatedAt: Date?
    var isPublic: Bool
    var collaborators: [String]
    var comments: [CommentModel]
    var reactions: [String: ReactionType]
    
    enum CodingKeys: String, CodingKey {
        case id, videoId, timestamp, content, type, tags, authorId, authorName
        case createdAt, updatedAt, isPublic, collaborators, comments, reactions
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(videoId, forKey: .videoId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(content, forKey: .content)
        try container.encode(type, forKey: .type)
        try container.encode(tags, forKey: .tags)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(authorName, forKey: .authorName)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encode(collaborators, forKey: .collaborators)
        try container.encode(comments, forKey: .comments)
        try container.encode(reactions, forKey: .reactions)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        videoId = try container.decode(String.self, forKey: .videoId)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        content = try container.decode(String.self, forKey: .content)
        richTextContent = NSAttributedString(string: content)
        type = try container.decode(AnnotationType.self, forKey: .type)
        tags = try container.decode([String].self, forKey: .tags)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorName = try container.decode(String.self, forKey: .authorName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        isPublic = try container.decode(Bool.self, forKey: .isPublic)
        collaborators = try container.decode([String].self, forKey: .collaborators)
        comments = try container.decode([CommentModel].self, forKey: .comments)
        reactions = try container.decode([String: ReactionType].self, forKey: .reactions)
    }
    
    init(
        id: String,
        videoId: String,
        timestamp: TimeInterval,
        content: String,
        richTextContent: NSAttributedString,
        type: AnnotationType,
        tags: [String],
        authorId: String,
        authorName: String,
        createdAt: Date,
        updatedAt: Date? = nil,
        isPublic: Bool,
        collaborators: [String],
        comments: [CommentModel],
        reactions: [String: ReactionType]
    ) {
        self.id = id
        self.videoId = videoId
        self.timestamp = timestamp
        self.content = content
        self.richTextContent = richTextContent
        self.type = type
        self.tags = tags
        self.authorId = authorId
        self.authorName = authorName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPublic = isPublic
        self.collaborators = collaborators
        self.comments = comments
        self.reactions = reactions
    }
}

struct CommentModel: Identifiable, Codable, Hashable {
    let id: String
    let content: String
    let authorId: String
    let authorName: String
    let createdAt: Date
    var reactions: [String: ReactionType]
}

struct CollaboratorModel: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let avatarURL: URL?
    let isOnline: Bool
    let lastActivity: Date
}

enum AnnotationType: String, Codable, CaseIterable {
    case note = "note"
    case highlight = "highlight"
    case question = "question"
    case bookmark = "bookmark"
    case critique = "critique"
    case summary = "summary"
    
    var displayName: String {
        switch self {
        case .note: return "Note"
        case .highlight: return "Highlight"
        case .question: return "Question"
        case .bookmark: return "Bookmark"
        case .critique: return "Critique"
        case .summary: return "Summary"
        }
    }
    
    var icon: String {
        switch self {
        case .note: return "note.text"
        case .highlight: return "highlighter"
        case .question: return "questionmark.circle"
        case .bookmark: return "bookmark"
        case .critique: return "exclamationmark.triangle"
        case .summary: return "list.bullet.rectangle"
        }
    }
}

enum ReactionType: String, Codable, CaseIterable {
    case like = "like"
    case love = "love"
    case laugh = "laugh"
    case wow = "wow"
    case sad = "sad"
    case angry = "angry"
    
    var emoji: String {
        switch self {
        case .like: return "👍"
        case .love: return "❤️"
        case .laugh: return "😂"
        case .wow: return "😮"
        case .sad: return "😢"
        case .angry: return "😠"
        }
    }
}

enum SharingPermission: String, Codable {
    case view = "view"
    case comment = "comment"
    case edit = "edit"
    case admin = "admin"
}

enum ExportFormat: String, Codable, CaseIterable {
    case json = "json"
    case csv = "csv"
    case markdown = "markdown"
    case pdf = "pdf"
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
}

// MARK: - Errors

enum AnnotationError: Error, LocalizedError {
    case annotationNotFound
    case contentTooLong
    case tooManyAnnotations
    case insufficientPermissions
    case loadFailed
    case saveFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .annotationNotFound:
            return "Annotation not found"
        case .contentTooLong:
            return "Annotation content is too long"
        case .tooManyAnnotations:
            return "Too many annotations for this video"
        case .insufficientPermissions:
            return "You don't have permission to perform this action"
        case .loadFailed:
            return "Failed to load annotations"
        case .saveFailed:
            return "Failed to save annotation"
        case .networkError:
            return "Network error occurred"
        }
    }
}
