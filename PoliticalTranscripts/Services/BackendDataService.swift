import Foundation
import SwiftUI

// MARK: - Backend Data Service
@MainActor
class BackendDataService: ObservableObject {
    static let shared = BackendDataService()
    
    @Published var transcripts: [VideoModel] = []
    @Published var searchResults: [VideoModel] = []
    @Published var bookmarks: [VideoModel] = []
    @Published var isLoading = false
    @Published var error: APIError?
    
    private let apiClient = APIClient.shared
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Transcript Operations
    func loadTranscripts() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await apiClient.searchVideos(query: "", limit: 50)
            transcripts = response.data
        } catch let apiError as APIError {
            error = apiError
            // Fallback to sample data for development
            loadSampleTranscripts()
        } catch {
            self.error = APIError.unknown(error)
            loadSampleTranscripts()
        }
        
        isLoading = false
    }
    
    // MARK: - Search Operations
    func searchTranscripts(query: String, filters: SearchFilterModel? = nil) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let response = try await apiClient.searchVideos(query: query, filters: filters, limit: 20)
            searchResults = response.data
        } catch let apiError as APIError {
            error = apiError
            // Fallback to filtered sample data
            searchResults = transcripts.filter { video in
                video.title.localizedCaseInsensitiveContains(query) ||
                (video.description?.localizedCaseInsensitiveContains(query) ?? false)
            }
        } catch {
            self.error = APIError.unknown(error)
            searchResults = []
        }
        
        isLoading = false
    }
    
    // MARK: - Bookmark Operations
    func loadBookmarks() async {
        isLoading = true
        error = nil
        
        // For now, load from UserDefaults (in real app would be from backend)
        if let bookmarkIds = userDefaults.array(forKey: "bookmarked_videos") as? [String] {
            bookmarks = transcripts.filter { bookmarkIds.contains($0.id) }
        }
        
        isLoading = false
    }
    
    func toggleBookmark(for video: VideoModel) {
        var bookmarkIds = userDefaults.array(forKey: "bookmarked_videos") as? [String] ?? []
        
        if bookmarkIds.contains(video.id) {
            bookmarkIds.removeAll { $0 == video.id }
            bookmarks.removeAll { $0.id == video.id }
        } else {
            bookmarkIds.append(video.id)
            if !bookmarks.contains(where: { $0.id == video.id }) {
                bookmarks.append(video)
            }
        }
        
        userDefaults.set(bookmarkIds, forKey: "bookmarked_videos")
    }
    
    func isBookmarked(_ video: VideoModel) -> Bool {
        let bookmarkIds = userDefaults.array(forKey: "bookmarked_videos") as? [String] ?? []
        return bookmarkIds.contains(video.id)
    }
    
    // MARK: - Video Detail Operations
    func getVideoDetail(id: String) async -> VideoModel? {
        do {
            let response = try await apiClient.getVideo(id: id)
            return response.data
        } catch {
            // Return from cache if available
            return transcripts.first { $0.id == id }
        }
    }
    
    func getVideoTranscript(id: String) async -> [TranscriptSegmentModel]? {
        do {
            let response = try await apiClient.getVideoTranscript(id: id)
            return response.data
        } catch {
            return nil
        }
    }
    
    // MARK: - Sample Data Fallback
    private func loadSampleTranscripts() {
        transcripts = [
            VideoModel(
                id: "sample_1",
                title: "Presidential Debate 2024",
                description: "Tonight's debate covers economic policy, healthcare reform, and climate change initiatives. The candidates present their vision for America's future while addressing key concerns from voters across the nation.",
                speaker: "Multiple Speakers",
                uploadDate: Date(),
                duration: 7200,
                url: "https://example.com/debate2024",
                thumbnailUrl: "https://example.com/thumb1.jpg",
                tags: ["debate", "economy", "healthcare"],
                category: "Debates",
                source: "Congressional Records",
                transcriptUrl: "https://example.com/transcript1",
                isLive: false,
                metadata: VideoMetadata(
                    quality: "HD",
                    audioQuality: "High",
                    language: "en",
                    subtitles: ["en"],
                    downloadable: true
                )
            ),
            VideoModel(
                id: "sample_2",
                title: "Senate Healthcare Committee",
                description: "The committee convenes to discuss the proposed healthcare legislation and its impact on rural communities. Key provisions include expanded coverage and reduced prescription costs.",
                speaker: "Senator Johnson",
                uploadDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                duration: 3600,
                url: "https://example.com/senate_healthcare",
                thumbnailUrl: "https://example.com/thumb2.jpg",
                tags: ["healthcare", "rural", "legislation"],
                category: "Committee Hearings",
                source: "Senate Archives",
                transcriptUrl: "https://example.com/transcript2",
                isLive: false,
                metadata: VideoMetadata(
                    quality: "HD",
                    audioQuality: "High",
                    language: "en",
                    subtitles: ["en"],
                    downloadable: true
                )
            ),
            VideoModel(
                id: "sample_3",
                title: "Climate Policy Address",
                description: "Today we announce new initiatives for clean energy transition and carbon reduction targets. These policies will create jobs while protecting our environment.",
                speaker: "Secretary of Energy",
                uploadDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                duration: 1800,
                url: "https://example.com/climate_policy",
                thumbnailUrl: "https://example.com/thumb3.jpg",
                tags: ["climate", "energy", "environment"],
                category: "Press Conferences",
                source: "Department of Energy",
                transcriptUrl: "https://example.com/transcript3",
                isLive: false,
                metadata: VideoMetadata(
                    quality: "HD",
                    audioQuality: "High",
                    language: "en",
                    subtitles: ["en"],
                    downloadable: true
                )
            )
        ]
    }
    
    // MARK: - Error Handling
    func clearError() {
        error = nil
    }
    
    func retry() async {
        await loadTranscripts()
    }
}

// MARK: - Extensions for Legacy Model Compatibility
extension VideoModel {
    var asPoliticalTranscript: PoliticalTranscript {
        return PoliticalTranscript(
            id: UUID(),
            title: title,
            speaker: speaker,
            date: uploadDate,
            content: description ?? "No description available",
            tags: tags,
            duration: duration
        )
    }
}

extension PoliticalTranscript {
    var asVideoModel: VideoModel {
        return VideoModel(
            id: UUID().uuidString,
            title: title,
            description: content,
            speaker: speaker,
            uploadDate: date,
            duration: duration,
            url: "https://example.com/video",
            thumbnailUrl: "https://example.com/thumb.jpg",
            tags: tags,
            category: "Political",
            source: "Archive",
            transcriptUrl: nil,
            isLive: false,
            metadata: VideoMetadata(
                quality: "HD",
                audioQuality: "High",
                language: "en",
                subtitles: ["en"],
                downloadable: true
            )
        )
    }
}
