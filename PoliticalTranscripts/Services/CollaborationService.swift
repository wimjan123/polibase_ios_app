import Foundation
import Combine
import CloudKit
import Network

@MainActor
class CollaborationService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var activeCollaborators: [Collaborator] = []
    @Published var collaborationSessions: [CollaborationSession] = []
    @Published var realtimeUpdates: [RealtimeUpdate] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isCollaborationEnabled: Bool = false
    
    // MARK: - Dependencies
    private let cloudKitService: CKContainer
    private let analyticsService: AnalyticsService
    private let networkMonitor = NWPathMonitor()
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var subscriptions: [CKSubscription] = []
    private var updateQueue = DispatchQueue(label: "collaboration.updates", qos: .userInitiated)
    private var heartbeatTimer: Timer?
    private var reconnectionTimer: Timer?
    private var pendingUpdates: [RealtimeUpdate] = []
    
    // MARK: - Configuration
    private struct Config {
        static let heartbeatInterval: TimeInterval = 30.0
        static let maxReconnectionAttempts = 5
        static let updateBatchSize = 50
        static let collaboratorTimeout: TimeInterval = 300.0 // 5 minutes
        static let maxActiveCollaborators = 10
        static let syncThrottleInterval: TimeInterval = 1.0
    }
    
    // MARK: - Initialization
    init(analyticsService: AnalyticsService) {
        self.cloudKitService = CKContainer.default()
        self.analyticsService = analyticsService
        
        setupNetworkMonitoring()
        setupCloudKitSubscriptions()
    }
    
    // MARK: - Public Methods
    
    /// Start a new collaboration session
    func startCollaborationSession(
        documentId: String,
        documentType: CollaborationDocumentType,
        permissions: CollaborationPermissions = .readWrite
    ) async throws -> CollaborationSession {
        
        guard connectionStatus == .connected else {
            throw CollaborationError.notConnected
        }
        
        let session = CollaborationSession(
            id: UUID().uuidString,
            documentId: documentId,
            documentType: documentType,
            createdBy: getCurrentUserId(),
            permissions: permissions,
            createdAt: Date(),
            isActive: true
        )
        
        // Save session to CloudKit
        try await saveCollaborationSession(session)
        
        // Join the session
        try await joinCollaborationSession(session.id)
        
        await MainActor.run {
            self.collaborationSessions.append(session)
        }
        
        await analyticsService.trackEvent("collaboration_session_started", parameters: [
            "session_id": session.id,
            "document_type": documentType.rawValue,
            "permissions": permissions.rawValue
        ])
        
        return session
    }
    
    /// Join an existing collaboration session
    func joinCollaborationSession(_ sessionId: String) async throws {
        guard let session = collaborationSessions.first(where: { $0.id == sessionId }) else {
            // Try to fetch from CloudKit
            let fetchedSession = try await fetchCollaborationSession(sessionId)
            await MainActor.run {
                self.collaborationSessions.append(fetchedSession)
            }
        }
        
        let collaborator = Collaborator(
            userId: getCurrentUserId(),
            sessionId: sessionId,
            userName: getCurrentUserName(),
            userAvatar: getCurrentUserAvatar(),
            joinedAt: Date(),
            lastSeen: Date(),
            isActive: true,
            currentLocation: nil
        )
        
        // Add collaborator to CloudKit
        try await addCollaboratorToSession(collaborator)
        
        await MainActor.run {
            self.activeCollaborators.append(collaborator)
            self.isCollaborationEnabled = true
        }
        
        // Start heartbeat
        startHeartbeat()
        
        await analyticsService.trackEvent("collaboration_session_joined", parameters: [
            "session_id": sessionId,
            "collaborator_count": activeCollaborators.count
        ])
    }
    
    /// Leave a collaboration session
    func leaveCollaborationSession(_ sessionId: String) async throws {
        let userId = getCurrentUserId()
        
        // Remove collaborator from CloudKit
        try await removeCollaboratorFromSession(userId: userId, sessionId: sessionId)
        
        await MainActor.run {
            self.activeCollaborators.removeAll { $0.userId == userId && $0.sessionId == sessionId }
            
            if self.activeCollaborators.isEmpty {
                self.isCollaborationEnabled = false
                self.stopHeartbeat()
            }
        }
        
        await analyticsService.trackEvent("collaboration_session_left", parameters: [
            "session_id": sessionId,
            "remaining_collaborators": activeCollaborators.count
        ])
    }
    
    /// Send a real-time update to collaborators
    func sendRealtimeUpdate(_ update: RealtimeUpdate) async throws {
        guard isCollaborationEnabled else {
            throw CollaborationError.collaborationDisabled
        }
        
        // Add timestamp and user info
        var enrichedUpdate = update
        enrichedUpdate.timestamp = Date()
        enrichedUpdate.userId = getCurrentUserId()
        enrichedUpdate.userName = getCurrentUserName()
        
        // Save to CloudKit for persistence
        try await saveRealtimeUpdate(enrichedUpdate)
        
        // Broadcast to active collaborators
        await broadcastUpdate(enrichedUpdate)
        
        await analyticsService.trackEvent("realtime_update_sent", parameters: [
            "update_type": update.type.rawValue,
            "session_id": update.sessionId,
            "data_size": update.data.count
        ])
    }
    
    /// Process incoming real-time updates
    func processIncomingUpdate(_ update: RealtimeUpdate) async {
        // Avoid processing our own updates
        guard update.userId != getCurrentUserId() else { return }
        
        await MainActor.run {
            self.realtimeUpdates.append(update)
            
            // Keep only recent updates
            let fiveMinutesAgo = Date().addingTimeInterval(-300)
            self.realtimeUpdates = self.realtimeUpdates.filter { $0.timestamp ?? Date() > fiveMinutesAgo }
        }
        
        // Handle specific update types
        switch update.type {
        case .cursorPosition:
            await handleCursorUpdate(update)
        case .textEdit:
            await handleTextEdit(update)
        case .annotation:
            await handleAnnotationUpdate(update)
        case .presence:
            await handlePresenceUpdate(update)
        case .selection:
            await handleSelectionUpdate(update)
        }
        
        await analyticsService.trackEvent("realtime_update_processed", parameters: [
            "update_type": update.type.rawValue,
            "session_id": update.sessionId
        ])
    }
    
    /// Get active collaborators for a session
    func getActiveCollaborators(for sessionId: String) -> [Collaborator] {
        return activeCollaborators.filter { 
            $0.sessionId == sessionId && 
            $0.isActive &&
            isCollaboratorRecentlyActive($0)
        }
    }
    
    /// Update collaborator presence
    func updatePresence(location: CollaborationLocation?) async throws {
        guard isCollaborationEnabled else { return }
        
        let presenceUpdate = RealtimeUpdate(
            id: UUID().uuidString,
            sessionId: activeCollaborators.first?.sessionId ?? "",
            type: .presence,
            data: [
                "location": location?.toDictionary() ?? [:],
                "timestamp": Date().timeIntervalSince1970
            ],
            timestamp: Date(),
            userId: getCurrentUserId(),
            userName: getCurrentUserName()
        )
        
        try await sendRealtimeUpdate(presenceUpdate)
        
        // Update local collaborator info
        await MainActor.run {
            if let index = self.activeCollaborators.firstIndex(where: { $0.userId == self.getCurrentUserId() }) {
                self.activeCollaborators[index].currentLocation = location
                self.activeCollaborators[index].lastSeen = Date()
            }
        }
    }
    
    /// Send cursor position update
    func updateCursorPosition(_ position: CursorPosition, in sessionId: String) async throws {
        let cursorUpdate = RealtimeUpdate(
            id: UUID().uuidString,
            sessionId: sessionId,
            type: .cursorPosition,
            data: [
                "position": position.toDictionary(),
                "timestamp": Date().timeIntervalSince1970
            ],
            timestamp: Date(),
            userId: getCurrentUserId(),
            userName: getCurrentUserName()
        )
        
        try await sendRealtimeUpdate(cursorUpdate)
    }
    
    /// Handle conflict resolution for simultaneous edits
    func resolveConflicts(_ conflicts: [EditConflict]) async -> [ResolvedConflict] {
        var resolvedConflicts: [ResolvedConflict] = []
        
        for conflict in conflicts {
            let resolution = await resolveEditConflict(conflict)
            resolvedConflicts.append(resolution)
            
            await analyticsService.trackEvent("conflict_resolved", parameters: [
                "conflict_type": conflict.type.rawValue,
                "resolution_strategy": resolution.strategy.rawValue,
                "session_id": conflict.sessionId
            ])
        }
        
        return resolvedConflicts
    }
    
    /// Get collaboration statistics
    func getCollaborationStatistics() -> CollaborationStatistics {
        let activeSessions = collaborationSessions.filter { $0.isActive }
        let totalCollaborators = activeCollaborators.count
        let updatesLast24Hours = realtimeUpdates.filter { 
            ($0.timestamp ?? Date.distantPast).timeIntervalSinceNow > -86400 
        }.count
        
        return CollaborationStatistics(
            activeSessions: activeSessions.count,
            totalCollaborators: totalCollaborators,
            updatesLast24Hours: updatesLast24Hours,
            averageSessionDuration: calculateAverageSessionDuration(),
            conflictsResolved: getResolvedConflictsCount(),
            connectionStatus: connectionStatus
        )
    }
}

// MARK: - Private Methods
private extension CollaborationService {
    
    func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionStatus(path.status == .satisfied ? .connected : .disconnected)
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    func setupCloudKitSubscriptions() {
        Task {
            do {
                // Subscribe to collaboration session changes
                let sessionSubscription = CKQuerySubscription(
                    recordType: "CollaborationSession",
                    predicate: NSPredicate(value: true),
                    options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
                )
                
                sessionSubscription.notificationInfo = CKSubscription.NotificationInfo()
                sessionSubscription.notificationInfo?.shouldSendContentAvailable = true
                
                // Subscribe to real-time updates
                let updateSubscription = CKQuerySubscription(
                    recordType: "RealtimeUpdate",
                    predicate: NSPredicate(value: true),
                    options: [.firesOnRecordCreation]
                )
                
                updateSubscription.notificationInfo = CKSubscription.NotificationInfo()
                updateSubscription.notificationInfo?.shouldSendContentAvailable = true
                
                // Save subscriptions
                try await cloudKitService.privateCloudDatabase.save(sessionSubscription)
                try await cloudKitService.privateCloudDatabase.save(updateSubscription)
                
                subscriptions = [sessionSubscription, updateSubscription]
                
            } catch {
                print("Failed to setup CloudKit subscriptions: \(error)")
            }
        }
    }
    
    func updateConnectionStatus(_ status: ConnectionStatus) {
        connectionStatus = status
        
        if status == .connected {
            reconnectIfNeeded()
        } else {
            handleDisconnection()
        }
    }
    
    func reconnectIfNeeded() {
        guard !isCollaborationEnabled && !collaborationSessions.isEmpty else { return }
        
        Task {
            do {
                // Attempt to rejoin active sessions
                for session in collaborationSessions.filter({ $0.isActive }) {
                    try await joinCollaborationSession(session.id)
                }
            } catch {
                print("Reconnection failed: \(error)")
                scheduleReconnection()
            }
        }
    }
    
    func handleDisconnection() {
        stopHeartbeat()
        
        // Mark all collaborators as potentially offline
        for index in activeCollaborators.indices {
            activeCollaborators[index].isActive = false
        }
    }
    
    func scheduleReconnection() {
        reconnectionTimer?.invalidate()
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            if self?.connectionStatus == .connected {
                self?.reconnectIfNeeded()
            }
        }
    }
    
    func startHeartbeat() {
        stopHeartbeat()
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: Config.heartbeatInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.sendHeartbeat()
            }
        }
    }
    
    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    func sendHeartbeat() async {
        guard isCollaborationEnabled else { return }
        
        do {
            try await updatePresence(location: nil)
        } catch {
            print("Heartbeat failed: \(error)")
        }
    }
    
    func saveCollaborationSession(_ session: CollaborationSession) async throws {
        let record = CKRecord(recordType: "CollaborationSession", recordID: CKRecord.ID(recordName: session.id))
        record["documentId"] = session.documentId
        record["documentType"] = session.documentType.rawValue
        record["createdBy"] = session.createdBy
        record["permissions"] = session.permissions.rawValue
        record["createdAt"] = session.createdAt
        record["isActive"] = session.isActive
        
        try await cloudKitService.privateCloudDatabase.save(record)
    }
    
    func fetchCollaborationSession(_ sessionId: String) async throws -> CollaborationSession {
        let recordID = CKRecord.ID(recordName: sessionId)
        let record = try await cloudKitService.privateCloudDatabase.record(for: recordID)
        
        return CollaborationSession(
            id: sessionId,
            documentId: record["documentId"] as? String ?? "",
            documentType: CollaborationDocumentType(rawValue: record["documentType"] as? String ?? "") ?? .transcript,
            createdBy: record["createdBy"] as? String ?? "",
            permissions: CollaborationPermissions(rawValue: record["permissions"] as? String ?? "") ?? .readOnly,
            createdAt: record["createdAt"] as? Date ?? Date(),
            isActive: record["isActive"] as? Bool ?? false
        )
    }
    
    func addCollaboratorToSession(_ collaborator: Collaborator) async throws {
        let record = CKRecord(recordType: "Collaborator", recordID: CKRecord.ID(recordName: "\(collaborator.sessionId)_\(collaborator.userId)"))
        record["userId"] = collaborator.userId
        record["sessionId"] = collaborator.sessionId
        record["userName"] = collaborator.userName
        record["userAvatar"] = collaborator.userAvatar
        record["joinedAt"] = collaborator.joinedAt
        record["lastSeen"] = collaborator.lastSeen
        record["isActive"] = collaborator.isActive
        
        try await cloudKitService.privateCloudDatabase.save(record)
    }
    
    func removeCollaboratorFromSession(userId: String, sessionId: String) async throws {
        let recordID = CKRecord.ID(recordName: "\(sessionId)_\(userId)")
        try await cloudKitService.privateCloudDatabase.deleteRecord(withID: recordID)
    }
    
    func saveRealtimeUpdate(_ update: RealtimeUpdate) async throws {
        let record = CKRecord(recordType: "RealtimeUpdate", recordID: CKRecord.ID(recordName: update.id))
        record["sessionId"] = update.sessionId
        record["type"] = update.type.rawValue
        record["data"] = try JSONSerialization.data(withJSONObject: update.data)
        record["timestamp"] = update.timestamp
        record["userId"] = update.userId
        record["userName"] = update.userName
        
        try await cloudKitService.privateCloudDatabase.save(record)
    }
    
    func broadcastUpdate(_ update: RealtimeUpdate) async {
        // In a real implementation, this would use CloudKit's push notifications
        // or a real-time service like WebSockets
        
        await MainActor.run {
            self.realtimeUpdates.append(update)
        }
    }
    
    func handleCursorUpdate(_ update: RealtimeUpdate) async {
        // Process cursor position updates
        guard let positionData = update.data["position"] as? [String: Any] else { return }
        
        let position = CursorPosition.fromDictionary(positionData)
        
        // Update collaborator cursor position
        await MainActor.run {
            if let index = self.activeCollaborators.firstIndex(where: { $0.userId == update.userId }) {
                self.activeCollaborators[index].lastSeen = Date()
            }
        }
    }
    
    func handleTextEdit(_ update: RealtimeUpdate) async {
        // Process text editing updates with conflict detection
        // This would integrate with the text editing system
    }
    
    func handleAnnotationUpdate(_ update: RealtimeUpdate) async {
        // Process annotation updates
        // This would integrate with the AnnotationService
    }
    
    func handlePresenceUpdate(_ update: RealtimeUpdate) async {
        guard let locationData = update.data["location"] as? [String: Any] else { return }
        
        let location = CollaborationLocation.fromDictionary(locationData)
        
        await MainActor.run {
            if let index = self.activeCollaborators.firstIndex(where: { $0.userId == update.userId }) {
                self.activeCollaborators[index].currentLocation = location
                self.activeCollaborators[index].lastSeen = Date()
                self.activeCollaborators[index].isActive = true
            }
        }
    }
    
    func handleSelectionUpdate(_ update: RealtimeUpdate) async {
        // Process text selection updates
        // This would show other users' selections
    }
    
    func isCollaboratorRecentlyActive(_ collaborator: Collaborator) -> Bool {
        let timeout = Date().addingTimeInterval(-Config.collaboratorTimeout)
        return collaborator.lastSeen > timeout
    }
    
    func resolveEditConflict(_ conflict: EditConflict) async -> ResolvedConflict {
        // Implement conflict resolution strategies
        switch conflict.type {
        case .simultaneousEdit:
            return resolveSimultaneousEdit(conflict)
        case .versionMismatch:
            return resolveVersionMismatch(conflict)
        case .deletionConflict:
            return resolveDeletionConflict(conflict)
        }
    }
    
    func resolveSimultaneousEdit(_ conflict: EditConflict) -> ResolvedConflict {
        // Use timestamp-based resolution or merge strategies
        return ResolvedConflict(
            conflictId: conflict.id,
            strategy: .timestampBased,
            resolvedContent: conflict.conflictingEdits.first?.content ?? "",
            appliedAt: Date()
        )
    }
    
    func resolveVersionMismatch(_ conflict: EditConflict) -> ResolvedConflict {
        // Use latest version strategy
        return ResolvedConflict(
            conflictId: conflict.id,
            strategy: .latestVersion,
            resolvedContent: conflict.conflictingEdits.last?.content ?? "",
            appliedAt: Date()
        )
    }
    
    func resolveDeletionConflict(_ conflict: EditConflict) -> ResolvedConflict {
        // Preserve content by default
        return ResolvedConflict(
            conflictId: conflict.id,
            strategy: .preserveContent,
            resolvedContent: conflict.conflictingEdits.first?.content ?? "",
            appliedAt: Date()
        )
    }
    
    func calculateAverageSessionDuration() -> TimeInterval {
        let completedSessions = collaborationSessions.filter { !$0.isActive }
        guard !completedSessions.isEmpty else { return 0 }
        
        let totalDuration = completedSessions.reduce(0) { total, session in
            return total + Date().timeIntervalSince(session.createdAt)
        }
        
        return totalDuration / Double(completedSessions.count)
    }
    
    func getResolvedConflictsCount() -> Int {
        // This would be tracked in analytics or a separate store
        return 0
    }
    
    func getCurrentUserId() -> String {
        // In a real app, this would come from authentication service
        return "current_user_id"
    }
    
    func getCurrentUserName() -> String {
        // In a real app, this would come from user profile
        return "Current User"
    }
    
    func getCurrentUserAvatar() -> String? {
        // In a real app, this would come from user profile
        return nil
    }
}

// MARK: - Supporting Models

struct Collaborator: Identifiable, Codable, Equatable {
    let id = UUID()
    let userId: String
    let sessionId: String
    let userName: String
    let userAvatar: String?
    let joinedAt: Date
    var lastSeen: Date
    var isActive: Bool
    var currentLocation: CollaborationLocation?
}

struct CollaborationSession: Identifiable, Codable, Equatable {
    let id: String
    let documentId: String
    let documentType: CollaborationDocumentType
    let createdBy: String
    let permissions: CollaborationPermissions
    let createdAt: Date
    var isActive: Bool
}

enum CollaborationDocumentType: String, CaseIterable, Codable {
    case transcript = "transcript"
    case annotation = "annotation"
    case bookmark = "bookmark"
    case collection = "collection"
    
    var displayName: String {
        switch self {
        case .transcript: return "Transcript"
        case .annotation: return "Annotation"
        case .bookmark: return "Bookmark"
        case .collection: return "Collection"
        }
    }
}

enum CollaborationPermissions: String, CaseIterable, Codable {
    case readOnly = "read_only"
    case readWrite = "read_write"
    case admin = "admin"
    
    var displayName: String {
        switch self {
        case .readOnly: return "Read Only"
        case .readWrite: return "Read & Write"
        case .admin: return "Admin"
        }
    }
}

struct RealtimeUpdate: Identifiable, Codable, Equatable {
    let id: String
    let sessionId: String
    let type: UpdateType
    let data: [String: Any]
    var timestamp: Date?
    var userId: String?
    var userName: String?
    
    enum UpdateType: String, CaseIterable, Codable {
        case cursorPosition = "cursor_position"
        case textEdit = "text_edit"
        case annotation = "annotation"
        case presence = "presence"
        case selection = "selection"
    }
    
    // Custom coding for [String: Any]
    enum CodingKeys: String, CodingKey {
        case id, sessionId, type, timestamp, userId, userName, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        type = try container.decode(UpdateType.self, forKey: .type)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
        data = try container.decode([String: AnyCodable].self, forKey: .data).mapValues { $0.value }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(userName, forKey: .userName)
        try container.encode(data.mapValues(AnyCodable.init), forKey: .data)
    }
    
    init(id: String, sessionId: String, type: UpdateType, data: [String: Any], timestamp: Date? = nil, userId: String? = nil, userName: String? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.type = type
        self.data = data
        self.timestamp = timestamp
        self.userId = userId
        self.userName = userName
    }
    
    static func == (lhs: RealtimeUpdate, rhs: RealtimeUpdate) -> Bool {
        return lhs.id == rhs.id
    }
}

struct CollaborationLocation: Codable, Equatable {
    let documentSection: String?
    let paragraph: Int?
    let characterOffset: Int?
    let viewType: String?
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let documentSection = documentSection { dict["documentSection"] = documentSection }
        if let paragraph = paragraph { dict["paragraph"] = paragraph }
        if let characterOffset = characterOffset { dict["characterOffset"] = characterOffset }
        if let viewType = viewType { dict["viewType"] = viewType }
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> CollaborationLocation {
        return CollaborationLocation(
            documentSection: dict["documentSection"] as? String,
            paragraph: dict["paragraph"] as? Int,
            characterOffset: dict["characterOffset"] as? Int,
            viewType: dict["viewType"] as? String
        )
    }
}

struct CursorPosition: Codable, Equatable {
    let x: Double
    let y: Double
    let documentId: String
    let timestamp: Date
    
    func toDictionary() -> [String: Any] {
        return [
            "x": x,
            "y": y,
            "documentId": documentId,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> CursorPosition {
        return CursorPosition(
            x: dict["x"] as? Double ?? 0,
            y: dict["y"] as? Double ?? 0,
            documentId: dict["documentId"] as? String ?? "",
            timestamp: Date(timeIntervalSince1970: dict["timestamp"] as? TimeInterval ?? 0)
        )
    }
}

enum ConnectionStatus {
    case connected
    case connecting
    case disconnected
    case error(String)
    
    var displayName: String {
        switch self {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnected: return "Disconnected"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

struct EditConflict: Identifiable {
    let id = UUID()
    let sessionId: String
    let documentId: String
    let type: ConflictType
    let conflictingEdits: [EditOperation]
    let detectedAt: Date
    
    enum ConflictType {
        case simultaneousEdit
        case versionMismatch
        case deletionConflict
    }
}

struct EditOperation {
    let userId: String
    let timestamp: Date
    let operation: String
    let content: String
    let position: Range<Int>
}

struct ResolvedConflict: Identifiable {
    let id = UUID()
    let conflictId: UUID
    let strategy: ResolutionStrategy
    let resolvedContent: String
    let appliedAt: Date
    
    enum ResolutionStrategy {
        case timestampBased
        case latestVersion
        case preserveContent
        case userChoice
    }
}

struct CollaborationStatistics {
    let activeSessions: Int
    let totalCollaborators: Int
    let updatesLast24Hours: Int
    let averageSessionDuration: TimeInterval
    let conflictsResolved: Int
    let connectionStatus: ConnectionStatus
}

// MARK: - Error Types

enum CollaborationError: Error, LocalizedError {
    case notConnected
    case collaborationDisabled
    case sessionNotFound
    case permissionDenied
    case conflictResolutionFailed
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to collaboration service"
        case .collaborationDisabled:
            return "Collaboration is currently disabled"
        case .sessionNotFound:
            return "Collaboration session not found"
        case .permissionDenied:
            return "Permission denied for this collaboration action"
        case .conflictResolutionFailed:
            return "Failed to resolve edit conflicts"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Helper Types

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Any] {
            try container.encode(array.map(AnyCodable.init))
        } else if let dictionary = value as? [String: Any] {
            try container.encode(dictionary.mapValues(AnyCodable.init))
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Cannot encode value"))
        }
    }
}
