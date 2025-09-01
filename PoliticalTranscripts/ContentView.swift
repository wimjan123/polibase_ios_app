//
//  ContentView.swift
//  PoliticalTranscripts
//
//  Main application interface with functional features
//

import SwiftUI

// MARK: - Backend Data Service (Simple Implementation)
@MainActor
class SimpleBackendDataService: ObservableObject {
    static let shared = SimpleBackendDataService()
    
    @Published var transcripts: [VideoModel] = []
    @Published var searchResults: [VideoModel] = []
    @Published var bookmarks: [VideoModel] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    func loadTranscripts() async {
        isLoading = true
        error = nil
        
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // For now, use sample data (in real app would call APIClient)
        transcripts = createSampleData()
        isLoading = false
    }
    
    func searchTranscripts(query: String, filters: Any? = nil) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        error = nil
        
        // Simulate search delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        searchResults = transcripts.filter { video in
            video.title.localizedCaseInsensitiveContains(query) ||
            (video.description?.localizedCaseInsensitiveContains(query) ?? false) ||
            (video.tags?.contains { $0.localizedCaseInsensitiveContains(query) } ?? false)
        }
        
        isLoading = false
    }
    
    func loadBookmarks() async {
        if let bookmarkIds = userDefaults.array(forKey: "bookmarked_videos") as? [String] {
            bookmarks = transcripts.filter { bookmarkIds.contains($0.id) }
        }
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
    
    func getVideoTranscript(id: String) async -> [TranscriptSegmentModel]? {
        // In real app, would call APIClient.getVideoTranscript
        return nil
    }
    
    func clearError() {
        error = nil
    }
    
    func retry() async {
        await loadTranscripts()
    }
    
    private func createSampleData() -> [VideoModel] {
        return [
            VideoModel(
                id: "sample_1",
                title: "Presidential Debate 2024",
                description: "Tonight's debate covers economic policy, healthcare reform, and climate change initiatives. The candidates present their vision for America's future while addressing key concerns from voters across the nation.",
                url: URL(string: "https://example.com/debate2024")!,
                thumbnailURL: URL(string: "https://example.com/thumb1.jpg"),
                duration: 7200,
                publishedDate: Date(),
                speaker: "Multiple Speakers",
                source: "Congressional Records",
                category: "Debates",
                tags: ["debate", "economy", "healthcare"],
                viewCount: 15420,
                isLive: false,
                language: "en",
                transcriptSegments: nil
            ),
            VideoModel(
                id: "sample_2",
                title: "Senate Healthcare Committee",
                description: "The committee convenes to discuss the proposed healthcare legislation and its impact on rural communities. Key provisions include expanded coverage and reduced prescription costs.",
                url: URL(string: "https://example.com/senate_healthcare")!,
                thumbnailURL: URL(string: "https://example.com/thumb2.jpg"),
                duration: 3600,
                publishedDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                speaker: "Senator Johnson",
                source: "Senate Archives",
                category: "Committee Hearings",
                tags: ["healthcare", "rural", "legislation"],
                viewCount: 8750,
                isLive: false,
                language: "en",
                transcriptSegments: nil
            ),
            VideoModel(
                id: "sample_3",
                title: "Climate Policy Address",
                description: "Today we announce new initiatives for clean energy transition and carbon reduction targets. These policies will create jobs while protecting our environment.",
                url: URL(string: "https://example.com/climate_policy")!,
                thumbnailURL: URL(string: "https://example.com/thumb3.jpg"),
                duration: 1800,
                publishedDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                speaker: "Secretary of Energy",
                source: "Department of Energy",
                category: "Press Conferences",
                tags: ["climate", "energy", "environment"],
                viewCount: 12300,
                isLive: false,
                language: "en",
                transcriptSegments: nil
            )
        ]
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home/Transcripts Tab
            TranscriptsView()
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("Transcripts")
                }
                .tag(0)
            
            // Search Tab
            TranscriptSearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(1)
            
            // Bookmarks Tab
            BookmarksView()
                .tabItem {
                    Image(systemName: "bookmark")
                    Text("Bookmarks")
                }
                .tag(2)
            
            // Collaboration Tab
            SimpleCollaborationView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Collaborate")
                }
                .tag(3)
            
            // Analytics Tab
            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Analytics")
                }
                .tag(4)
        }
    }
}

struct TranscriptsView: View {
    @StateObject private var dataService = SimpleBackendDataService.shared
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            VStack {
                if dataService.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading transcripts...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if dataService.transcripts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Transcripts Available")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Connect to backend to load political transcripts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry Connection") {
                            Task {
                                await dataService.loadTranscripts()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                } else {
                    List(dataService.transcripts) { video in
                        BackendTranscriptRow(video: video)
                    }
                    .refreshable {
                        await dataService.loadTranscripts()
                    }
                }
            }
            .navigationTitle("Political Transcripts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await dataService.loadTranscripts()
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await dataService.loadTranscripts()
                }
            }
            .alert("Connection Error", isPresented: $showingError) {
                Button("Retry") {
                    Task {
                        await dataService.retry()
                    }
                }
                Button("OK") {
                    dataService.clearError()
                }
            } message: {
                Text(dataService.error?.localizedDescription ?? "Unknown error occurred")
            }
            .onReceive(dataService.$error) { error in
                showingError = error != nil
            }
        }
    }
}

// MARK: - Backend-Connected Views
struct BackendTranscriptRow: View {
    let video: VideoModel
    @StateObject private var dataService = SimpleBackendDataService.shared
    
    var body: some View {
        NavigationLink(destination: BackendTranscriptDetailView(video: video)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: {
                        dataService.toggleBookmark(for: video)
                    }) {
                        Image(systemName: dataService.isBookmarked(video) ? "bookmark.fill" : "bookmark")
                            .foregroundColor(dataService.isBookmarked(video) ? .blue : .gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                HStack {
                    Text(video.speaker ?? "Unknown Speaker")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(video.publishedDate.formattedString())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let description = video.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    ForEach(video.tags?.prefix(3) ?? [], id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text(TimeInterval(video.duration).formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct BackendTranscriptDetailView: View {
    let video: VideoModel
    @StateObject private var dataService = SimpleBackendDataService.shared
    @State private var transcriptSegments: [TranscriptSegmentModel]?
    @State private var isLoadingTranscript = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(video.speaker ?? "Unknown Speaker")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(video.publishedDate.formattedString())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Duration: \(TimeInterval(video.duration).durationDescription)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            dataService.toggleBookmark(for: video)
                        }) {
                            Label(
                                dataService.isBookmarked(video) ? "Remove Bookmark" : "Add Bookmark",
                                systemImage: dataService.isBookmarked(video) ? "bookmark.fill" : "bookmark"
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Description
                if let description = video.description {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        Text(description)
                            .font(.body)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Tags
                if let tags = video.tags, !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Transcript
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcript")
                        .font(.headline)
                    
                    if isLoadingTranscript {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading transcript...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if let segments = transcriptSegments {
                        ForEach(segments, id: \.id) { segment in
                            VStack(alignment: .leading, spacing: 4) {
                                if let speaker = segment.speaker {
                                    Text(speaker)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                
                                Text(segment.text)
                                    .font(.body)
                                
                                Text(TimeInterval(segment.startTime).formattedDuration)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.03))
                            .cornerRadius(6)
                        }
                    } else {
                        Text("Transcript not available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
            .padding()
        }
        .navigationTitle("Transcript Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadTranscript()
        }
    }
    
    private func loadTranscript() {
        guard transcriptSegments == nil else { return }
        
        isLoadingTranscript = true
        Task {
            transcriptSegments = await dataService.getVideoTranscript(id: video.id)
            isLoadingTranscript = false
        }
    }
}

struct TranscriptRow: View {
    let transcript: PoliticalTranscript
    
    var body: some View {
        NavigationLink(destination: TranscriptDetailView(transcript: transcript)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(transcript.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(transcript.speaker)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(transcript.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    ForEach(transcript.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Text(transcript.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct TranscriptDetailView: View {
    let transcript: PoliticalTranscript
    @State private var isBookmarked = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(transcript.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(transcript.speaker)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(transcript.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        ForEach(transcript.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Divider()
                
                // Content
                Text(transcript.content)
                    .font(.body)
                    .lineSpacing(4)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { isBookmarked.toggle() }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isBookmarked ? .blue : .gray)
                }
            }
        }
    }
}

struct TranscriptSearchView: View {
    @StateObject private var dataService = SimpleBackendDataService.shared
    @State private var searchText = ""
    @State private var selectedFilters: Any?
    @State private var showingFilters = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search transcripts...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            performSearch()
                        }
                        .onChange(of: searchText) { newValue in
                            if newValue.isEmpty {
                                dataService.searchResults = []
                            }
                        }
                    
                    Button(action: {
                        showingFilters.toggle()
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.blue)
                    }
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                            dataService.searchResults = []
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding()
                
                // Loading indicator
                if dataService.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Searching...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // Search Results
                if dataService.searchResults.isEmpty && !searchText.isEmpty && !dataService.isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No results found")
                            .font(.headline)
                        
                        Text("Try different keywords or adjust search filters")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Search All Transcripts") {
                            searchText = ""
                            Task {
                                await dataService.loadTranscripts()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 50)
                } else if !dataService.searchResults.isEmpty {
                    List(dataService.searchResults) { video in
                        BackendTranscriptRow(video: video)
                    }
                } else if searchText.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Smart Search")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Search through political transcripts using AI-powered intelligence")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Try searching for:")
                                .font(.headline)
                            
                            HStack {
                                Button("Healthcare policy") {
                                    searchText = "Healthcare policy"
                                    performSearch()
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Climate change") {
                                    searchText = "Climate change"
                                    performSearch()
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            HStack {
                                Button("Economic recovery") {
                                    searchText = "Economic recovery"
                                    performSearch()
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Education") {
                                    searchText = "Education"
                                    performSearch()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Search")
            .sheet(isPresented: $showingFilters) {
                BackendSearchFiltersView(filters: $selectedFilters)
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        Task {
            await dataService.searchTranscripts(query: searchText, filters: selectedFilters)
        }
    }
}

struct BackendSearchFiltersView: View {
    @Binding var filters: Any?
    @State private var selectedSpeakers: [String] = []
    @State private var selectedCategories: [String] = []
    @State private var selectedTags: [String] = []
    @Environment(\.dismiss) private var dismiss
    
    let availableSpeakers = ["Senator Johnson", "Secretary of Energy", "Multiple Speakers"]
    let availableCategories = ["Debates", "Committee Hearings", "Press Conferences"]
    let availableTags = ["healthcare", "climate", "economy", "debate", "energy", "environment"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Speakers") {
                    ForEach(availableSpeakers, id: \.self) { speaker in
                        HStack {
                            Text(speaker)
                            Spacer()
                            if selectedSpeakers.contains(speaker) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedSpeakers.contains(speaker) {
                                selectedSpeakers.removeAll { $0 == speaker }
                            } else {
                                selectedSpeakers.append(speaker)
                            }
                        }
                    }
                }
                
                Section("Categories") {
                    ForEach(availableCategories, id: \.self) { category in
                        HStack {
                            Text(category)
                            Spacer()
                            if selectedCategories.contains(category) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedCategories.contains(category) {
                                selectedCategories.removeAll { $0 == category }
                            } else {
                                selectedCategories.append(category)
                            }
                        }
                    }
                }
                
                Section("Tags") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(availableTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedTags.contains(tag) ? Color.blue : Color.gray.opacity(0.1))
                                .foregroundColor(selectedTags.contains(tag) ? .white : .primary)
                                .cornerRadius(16)
                                .onTapGesture {
                                    if selectedTags.contains(tag) {
                                        selectedTags.removeAll { $0 == tag }
                                    } else {
                                        selectedTags.append(tag)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        selectedSpeakers = []
                        selectedCategories = []
                        selectedTags = []
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func applyFilters() {
        // For now, just set to nil - would properly implement SearchFilterModel later
        filters = nil
    }
}

struct BookmarksView: View {
    @StateObject private var dataService = SimpleBackendDataService.shared
    
    var body: some View {
        NavigationView {
            VStack {
                if dataService.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading bookmarks...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if dataService.bookmarks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Bookmarks")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Bookmark political transcripts to access them quickly. Use the bookmark button on any transcript.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        NavigationLink(destination: TranscriptsView()) {
                            Text("Browse Transcripts")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List(dataService.bookmarks) { video in
                        BookmarkedTranscriptRow(video: video)
                    }
                    .refreshable {
                        await dataService.loadBookmarks()
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .onAppear {
                Task {
                    await dataService.loadBookmarks()
                }
            }
        }
    }
}

struct BookmarkedTranscriptRow: View {
    let video: VideoModel
    @StateObject private var dataService = SimpleBackendDataService.shared
    
    var body: some View {
        NavigationLink(destination: BackendTranscriptDetailView(video: video)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: {
                        dataService.toggleBookmark(for: video)
                    }) {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                HStack {
                    Text(video.speaker ?? "Unknown Speaker")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Bookmarked")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                if let description = video.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    ForEach(video.tags?.prefix(3) ?? [], id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text(TimeInterval(video.duration).formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct SimpleBookmark: Identifiable {
    let id: UUID
    let title: String
    let transcriptTitle: String
    let timestamp: TimeInterval
    let note: String
}

struct SimpleBookmarkRow: View {
    let bookmark: SimpleBookmark
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(bookmark.title)
                .font(.headline)
            
            Text(bookmark.transcriptTitle)
                .font(.subheadline)
                .foregroundColor(.blue)
            
            if !bookmark.note.isEmpty {
                Text(bookmark.note)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Timestamp: \(bookmark.timestamp, specifier: "%.1f")s")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

struct SimpleCollaborationView: View {
    @State private var isConnected = false
    @State private var collaborators: [String] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Connection Status
                VStack(spacing: 12) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.gray)
                        .frame(width: 20, height: 20)
                    
                    Text(isConnected ? "Connected" : "Offline")
                        .font(.headline)
                        .foregroundColor(isConnected ? .green : .gray)
                }
                
                // Collaboration Features
                VStack(spacing: 16) {
                    Button("Start Collaboration Session") {
                        isConnected.toggle()
                        if isConnected {
                            collaborators = ["Alice Johnson", "Bob Smith"]
                        } else {
                            collaborators = []
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Join Session") {
                        // Join session logic
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                if !collaborators.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Collaborators")
                            .font(.headline)
                        
                        ForEach(collaborators, id: \.self) { collaborator in
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                
                                Text(collaborator)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text("Online")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Collaboration Features:")
                        .font(.headline)
                    
                    Text("• Real-time transcript editing")
                    Text("• Shared bookmarks and annotations")
                    Text("• Live cursors and presence")
                    Text("• Chat and comments")
                    Text("• Version history")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Collaboration")
        }
    }
}

struct AnalyticsView: View {
    @StateObject private var dataService = SimpleBackendDataService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Stats
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        StatCard(title: "Total Transcripts", value: "\(dataService.transcripts.count)", icon: "doc.text")
                        StatCard(title: "Bookmarks", value: "\(dataService.bookmarks.count)", icon: "bookmark")
                        StatCard(title: "Search Results", value: "\(dataService.searchResults.count)", icon: "magnifyingglass")
                        StatCard(title: "Backend Status", value: dataService.error == nil ? "Connected" : "Offline", icon: "wifi")
                    }
                    
                    // Connection Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Backend Connection")
                            .font(.headline)
                        
                        HStack {
                            Circle()
                                .fill(dataService.error == nil ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            
                            Text(dataService.error == nil ? "Connected to backend API" : "Backend connection failed")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if dataService.error != nil {
                                Button("Retry") {
                                    Task {
                                        await dataService.retry()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Data Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Overview")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            DataRow(label: "Available Transcripts", value: "\(dataService.transcripts.count)")
                            DataRow(label: "Search Results", value: "\(dataService.searchResults.count)")
                            DataRow(label: "Bookmarked Items", value: "\(dataService.bookmarks.count)")
                            DataRow(label: "Loading State", value: dataService.isLoading ? "Loading..." : "Ready")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Popular Categories
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Content Categories")
                            .font(.headline)
                        
                        let categories = Array(Set(dataService.transcripts.compactMap { $0.category }))
                        ForEach(categories, id: \.self) { category in
                            HStack {
                                Text(category)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(dataService.transcripts.filter { $0.category == category }.count)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Performance Metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance Metrics")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            MetricRow(title: "Search Response Time", value: "0.8s", status: .good)
                            MetricRow(title: "Transcription Accuracy", value: "94.2%", status: .good)
                            MetricRow(title: "User Engagement", value: "67%", status: .warning)
                            MetricRow(title: "System Uptime", value: "99.9%", status: .excellent)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Analytics")
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

enum Trend {
    case up, down, stable
    
    var icon: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
}

struct TopicRow: View {
    let topic: String
    let mentions: Int
    let trend: Trend
    
    var body: some View {
        HStack {
            Text(topic)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
                
                Text("\(mentions) mentions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

enum MetricStatus {
    case excellent, good, warning, critical
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let status: MetricStatus
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(status.color)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}