import Foundation

// MARK: - Rate Limiting Actor
actor RateLimitingActor {
    static let shared = RateLimitingActor()
    
    private var requestLog: [RequestRecord] = []
    private let configuration: RateLimitConfiguration
    
    private init() {
        self.configuration = APIConfiguration.shared.rateLimitConfiguration
    }
    
    // MARK: - Request Record
    private struct RequestRecord {
        let timestamp: Date
        let endpoint: String
    }
    
    // MARK: - Rate Limiting
    func waitForAvailability(for endpoint: APIEndpoint) async throws {
        let endpointString = endpoint.path
        let now = Date()
        
        // Clean up old requests
        await cleanupOldRequests(before: now)
        
        // Check rate limits
        try await enforceRateLimit(for: endpointString, at: now)
        
        // Record this request
        await recordRequest(for: endpointString, at: now)
    }
    
    // MARK: - Private Rate Limiting Logic
    private func cleanupOldRequests(before date: Date) async {
        let fiveMinutesAgo = Calendar.current.date(byAdding: .minute, value: -5, to: date) ?? date
        requestLog.removeAll { $0.timestamp < fiveMinutesAgo }
    }
    
    private func enforceRateLimit(for endpoint: String, at timestamp: Date) async throws {
        let oneMinuteAgo = Calendar.current.date(byAdding: .minute, value: -1, to: timestamp) ?? timestamp
        let fiveMinutesAgo = Calendar.current.date(byAdding: .minute, value: -5, to: timestamp) ?? timestamp
        let tenMinutesAgo = Calendar.current.date(byAdding: .minute, value: -10, to: timestamp) ?? timestamp
        
        // Count requests in different time windows
        let requestsInLastMinute = requestLog.filter { $0.timestamp >= oneMinuteAgo }.count
        let requestsInLastFiveMinutes = requestLog.filter { $0.timestamp >= fiveMinutesAgo }.count
        let requestsInLastTenMinutes = requestLog.filter { $0.timestamp >= tenMinutesAgo }.count
        
        // Check against limits
        if requestsInLastMinute >= configuration.maxRequestsPerMinute {
            let waitTime = calculateWaitTime(for: .perMinute, lastRequest: requestLog.last(where: { $0.timestamp >= oneMinuteAgo })?.timestamp ?? timestamp)
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        if requestsInLastFiveMinutes >= configuration.maxRequestsPerFiveMinutes {
            let waitTime = calculateWaitTime(for: .perFiveMinutes, lastRequest: requestLog.last(where: { $0.timestamp >= fiveMinutesAgo })?.timestamp ?? timestamp)
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        if requestsInLastTenMinutes >= configuration.maxRequestsPerTenMinutes {
            let waitTime = calculateWaitTime(for: .perTenMinutes, lastRequest: requestLog.last(where: { $0.timestamp >= tenMinutesAgo })?.timestamp ?? timestamp)
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
    }
    
    private func calculateWaitTime(for period: RateLimitPeriod, lastRequest: Date) -> TimeInterval {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequest)
        
        switch period {
        case .perMinute:
            return max(0, 60.0 - timeSinceLastRequest + 1.0) // Add 1 second buffer
        case .perFiveMinutes:
            return max(0, 300.0 - timeSinceLastRequest + 1.0) // Add 1 second buffer
        case .perTenMinutes:
            return max(0, 600.0 - timeSinceLastRequest + 1.0) // Add 1 second buffer
        }
    }
    
    private func recordRequest(for endpoint: String, at timestamp: Date) async {
        let record = RequestRecord(timestamp: timestamp, endpoint: endpoint)
        requestLog.append(record)
    }
    
    // MARK: - Rate Limit Status
    func getCurrentStatus() async -> RateLimitStatus {
        let now = Date()
        let oneMinuteAgo = Calendar.current.date(byAdding: .minute, value: -1, to: now) ?? now
        let fiveMinutesAgo = Calendar.current.date(byAdding: .minute, value: -5, to: now) ?? now
        let tenMinutesAgo = Calendar.current.date(byAdding: .minute, value: -10, to: now) ?? now
        
        let requestsInLastMinute = requestLog.filter { $0.timestamp >= oneMinuteAgo }.count
        let requestsInLastFiveMinutes = requestLog.filter { $0.timestamp >= fiveMinutesAgo }.count
        let requestsInLastTenMinutes = requestLog.filter { $0.timestamp >= tenMinutesAgo }.count
        
        return RateLimitStatus(
            requestsInLastMinute: requestsInLastMinute,
            requestsInLastFiveMinutes: requestsInLastFiveMinutes,
            requestsInLastTenMinutes: requestsInLastTenMinutes,
            maxRequestsPerMinute: configuration.maxRequestsPerMinute,
            maxRequestsPerFiveMinutes: configuration.maxRequestsPerFiveMinutes,
            maxRequestsPerTenMinutes: configuration.maxRequestsPerTenMinutes
        )
    }
    
    // MARK: - Request Queue Management
    private var requestQueue: [QueuedRequest] = []
    private var isProcessingQueue = false
    
    private struct QueuedRequest {
        let id = UUID()
        let endpoint: APIEndpoint
        let priority: RequestPriority
        let timestamp: Date
        let completion: () async throws -> Void
    }
    
    func queueRequest<T>(
        endpoint: APIEndpoint,
        priority: RequestPriority = .normal,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            let queuedRequest = QueuedRequest(
                endpoint: endpoint,
                priority: priority,
                timestamp: Date()
            ) {
                do {
                    let result = try await operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            Task {
                await addToQueue(queuedRequest)
                await processQueueIfNeeded()
            }
        }
    }
    
    private func addToQueue(_ request: QueuedRequest) async {
        // Insert based on priority and timestamp
        if let insertIndex = requestQueue.firstIndex(where: { existingRequest in
            request.priority.rawValue > existingRequest.priority.rawValue ||
            (request.priority == existingRequest.priority && request.timestamp < existingRequest.timestamp)
        }) {
            requestQueue.insert(request, at: insertIndex)
        } else {
            requestQueue.append(request)
        }
    }
    
    private func processQueueIfNeeded() async {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true
        
        while !requestQueue.isEmpty {
            let request = requestQueue.removeFirst()
            
            do {
                try await waitForAvailability(for: request.endpoint)
                try await request.completion()
            } catch {
                // Log error and continue processing
                print("⚠️ Rate limited request failed: \(error)")
            }
        }
        
        isProcessingQueue = false
    }
}

// MARK: - Supporting Types
enum RateLimitPeriod {
    case perMinute
    case perFiveMinutes
    case perTenMinutes
}

enum RequestPriority: Int, Comparable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
    
    static func < (lhs: RequestPriority, rhs: RequestPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct RateLimitStatus {
    let requestsInLastMinute: Int
    let requestsInLastFiveMinutes: Int
    let requestsInLastTenMinutes: Int
    let maxRequestsPerMinute: Int
    let maxRequestsPerFiveMinutes: Int
    let maxRequestsPerTenMinutes: Int
    
    var isAtLimit: Bool {
        requestsInLastMinute >= maxRequestsPerMinute ||
        requestsInLastFiveMinutes >= maxRequestsPerFiveMinutes ||
        requestsInLastTenMinutes >= maxRequestsPerTenMinutes
    }
    
    var percentageUsed: Double {
        let minuteUsage = Double(requestsInLastMinute) / Double(maxRequestsPerMinute)
        let fiveMinuteUsage = Double(requestsInLastFiveMinutes) / Double(maxRequestsPerFiveMinutes)
        let tenMinuteUsage = Double(requestsInLastTenMinutes) / Double(maxRequestsPerTenMinutes)
        
        return max(minuteUsage, fiveMinuteUsage, tenMinuteUsage)
    }
}
