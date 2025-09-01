import Foundation

// MARK: - API Client
actor APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let configuration: APIConfiguration
    
    private init() {
        self.configuration = APIConfiguration.shared
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeoutConfiguration.requestTimeout
        config.timeoutIntervalForResource = configuration.timeoutConfiguration.resourceTimeout
        config.waitsForConnectivity = true
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Generic Request Method
    func request<T: Codable>(
        endpoint: APIEndpoint,
        body: Data? = nil,
        responseType: T.Type,
        priority: RequestPriority = .normal
    ) async throws -> T {
        // Apply rate limiting
        try await RateLimitingActor.shared.waitForAvailability(for: endpoint)
        
        let request = try buildRequest(for: endpoint, body: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            try validateResponse(response)
            
            return try JSONDecoder.apiDecoder.decode(T.self, from: data)
        } catch let urlError as URLError {
            throw APIError.networkError(urlError)
        } catch let decodingError as DecodingError {
            throw APIError.decodingError(decodingError)
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.unknown(error)
        }
    }
    
    // MARK: - Search Videos
    func searchVideos(
        query: String,
        filters: SearchFilterModel? = nil,
        page: Int = 1,
        limit: Int = 20
    ) async throws -> APIResponse<[VideoModel]> {
        let endpoint = APIEndpoint.searchVideos(query: query, filters: filters, page: page, limit: limit)
        return try await request(endpoint: endpoint, responseType: APIResponse<[VideoModel]>.self)
    }
    
    // MARK: - Get Video
    func getVideo(id: String) async throws -> APIResponse<VideoModel> {
        let endpoint = APIEndpoint.getVideo(id: id)
        return try await request(endpoint: endpoint, responseType: APIResponse<VideoModel>.self)
    }
    
    // MARK: - Get Video Transcript
    func getVideoTranscript(id: String) async throws -> APIResponse<[TranscriptSegmentModel]> {
        let endpoint = APIEndpoint.getVideoTranscript(id: id)
        return try await request(endpoint: endpoint, responseType: APIResponse<[TranscriptSegmentModel]>.self)
    }
    
    // MARK: - Playlist Operations
    func getPlaylists() async throws -> APIResponse<[PlaylistModel]> {
        let endpoint = APIEndpoint.getPlaylists
        return try await request(endpoint: endpoint, responseType: APIResponse<[PlaylistModel]>.self)
    }
    
    func createPlaylist(_ playlist: PlaylistModel) async throws -> APIResponse<PlaylistModel> {
        let endpoint = APIEndpoint.createPlaylist(playlist)
        let body = try JSONEncoder.apiEncoder.encode(playlist)
        return try await request(endpoint: endpoint, body: body, responseType: APIResponse<PlaylistModel>.self)
    }
    
    func updatePlaylist(id: String, playlist: PlaylistModel) async throws -> APIResponse<PlaylistModel> {
        let endpoint = APIEndpoint.updatePlaylist(id: id, playlist)
        let body = try JSONEncoder.apiEncoder.encode(playlist)
        return try await request(endpoint: endpoint, body: body, responseType: APIResponse<PlaylistModel>.self)
    }
    
    func deletePlaylist(id: String) async throws -> APIResponse<EmptyResponse> {
        let endpoint = APIEndpoint.deletePlaylist(id: id)
        return try await request(endpoint: endpoint, responseType: APIResponse<EmptyResponse>.self)
    }
    
    func addVideoToPlaylist(playlistId: String, videoId: String) async throws -> APIResponse<EmptyResponse> {
        let endpoint = APIEndpoint.addVideoToPlaylist(playlistId: playlistId, videoId: videoId)
        let body = try JSONEncoder.apiEncoder.encode(["videoId": videoId])
        return try await request(endpoint: endpoint, body: body, responseType: APIResponse<EmptyResponse>.self)
    }
    
    func removeVideoFromPlaylist(playlistId: String, videoId: String) async throws -> APIResponse<EmptyResponse> {
        let endpoint = APIEndpoint.removeVideoFromPlaylist(playlistId: playlistId, videoId: videoId)
        return try await request(endpoint: endpoint, responseType: APIResponse<EmptyResponse>.self)
    }
    
    // MARK: - Search Suggestions and History
    func getSuggestions(query: String) async throws -> APIResponse<[String]> {
        let endpoint = APIEndpoint.getSuggestions(query: query)
        return try await request(endpoint: endpoint, responseType: APIResponse<[String]>.self)
    }
    
    func getSearchHistory() async throws -> APIResponse<[SearchHistoryItem]> {
        let endpoint = APIEndpoint.getSearchHistory
        return try await request(endpoint: endpoint, responseType: APIResponse<[SearchHistoryItem]>.self)
    }
    
    func saveSearch(query: String, filters: SearchFilterModel? = nil) async throws -> APIResponse<EmptyResponse> {
        let endpoint = APIEndpoint.saveSearch(query: query, filters: filters)
        let searchItem = SaveSearchRequest(query: query, filters: filters)
        let body = try JSONEncoder.apiEncoder.encode(searchItem)
        return try await request(endpoint: endpoint, body: body, responseType: APIResponse<EmptyResponse>.self)
    }
    
    // MARK: - Private Helper Methods
    private func buildRequest(for endpoint: APIEndpoint, body: Data?) throws -> URLRequest {
        let url = configuration.url(for: endpoint)
        var request = URLRequest(url: url)
        
        request.httpMethod = endpoint.httpMethod.rawValue
        request.allHTTPHeaderFields = configuration.defaultHeaders
        request.httpBody = body
        
        // Add query parameters for GET requests
        if endpoint.httpMethod == .GET, let queryItems = buildQueryItems(for: endpoint) {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            
            guard let finalURL = components?.url else {
                throw APIError.invalidURL
            }
            
            request.url = finalURL
        }
        
        return request
    }
    
    private func buildQueryItems(for endpoint: APIEndpoint) -> [URLQueryItem]? {
        switch endpoint {
        case .searchVideos(let query, let filters, let page, let limit):
            var items = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            
            if let filters = filters {
                if let dateRange = filters.dateRange {
                    items.append(URLQueryItem(name: "start_date", value: ISO8601DateFormatter().string(from: dateRange.startDate)))
                    items.append(URLQueryItem(name: "end_date", value: ISO8601DateFormatter().string(from: dateRange.endDate)))
                }
                
                if !filters.speakers.isEmpty {
                    items.append(URLQueryItem(name: "speakers", value: filters.speakers.joined(separator: ",")))
                }
                
                if !filters.sources.isEmpty {
                    items.append(URLQueryItem(name: "sources", value: filters.sources.joined(separator: ",")))
                }
                
                if !filters.categories.isEmpty {
                    items.append(URLQueryItem(name: "categories", value: filters.categories.joined(separator: ",")))
                }
                
                if let durationRange = filters.durationRange {
                    items.append(URLQueryItem(name: "min_duration", value: String(durationRange.minDuration)))
                    items.append(URLQueryItem(name: "max_duration", value: String(durationRange.maxDuration)))
                }
            }
            
            return items
            
        case .getSuggestions(let query):
            return [URLQueryItem(name: "q", value: query)]
            
        default:
            return nil
        }
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(NSError(domain: "Invalid response type", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimitExceeded(retryAfter: nil)
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode, nil)
        default:
            throw APIError.serverError(httpResponse.statusCode, nil)
        }
    }
}

// MARK: - JSON Encoder/Decoder Extensions
extension JSONDecoder {
    static let apiDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

extension JSONEncoder {
    static let apiEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}

// MARK: - Request/Response Models
struct SaveSearchRequest: Codable {
    let query: String
    let filters: SearchFilterModel?
}

struct EmptyResponse: Codable {}

struct APIResponse<T: Codable>: Codable {
    let data: T
    let message: String?
    let pagination: PaginationInfo?
    
    struct PaginationInfo: Codable {
        let page: Int
        let limit: Int
        let total: Int
        let totalPages: Int
        let hasNext: Bool
        let hasPrevious: Bool
    }
}
