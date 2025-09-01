//
//  ContentView.swift
//  PoliticalTranscripts
//
//  Main application interface with functional features
//

import SwiftUI

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
        .accentColor(.blue)
    }
}

struct TranscriptsView: View {
    @State private var transcripts: [PoliticalTranscript] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if transcripts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Transcripts Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Import or create your first political transcript to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Import Sample Transcripts") {
                            loadSampleTranscripts()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                } else {
                    List(transcripts) { transcript in
                        TranscriptRow(transcript: transcript)
                    }
                }
            }
            .navigationTitle("Political Transcripts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        loadSampleTranscripts()
                    }
                }
            }
        }
    }
    
    private func loadSampleTranscripts() {
        isLoading = true
        
        // Simulate loading with sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            transcripts = [
                PoliticalTranscript(
                    id: UUID(),
                    title: "Presidential Debate 2024",
                    speaker: "Multiple Speakers",
                    date: Date(),
                    content: "Tonight's debate covers economic policy, healthcare reform, and climate change initiatives. The candidates present their vision for America's future while addressing key concerns from voters across the nation...",
                    tags: ["debate", "economy", "healthcare"],
                    duration: 7200
                ),
                PoliticalTranscript(
                    id: UUID(),
                    title: "Senate Healthcare Committee",
                    speaker: "Senator Johnson",
                    date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                    content: "The committee convenes to discuss the proposed healthcare legislation and its impact on rural communities. Key provisions include expanded coverage and reduced prescription costs...",
                    tags: ["healthcare", "rural", "legislation"],
                    duration: 3600
                ),
                PoliticalTranscript(
                    id: UUID(),
                    title: "Climate Policy Address",
                    speaker: "Secretary of Energy",
                    date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                    content: "Today we announce new initiatives for clean energy transition and carbon reduction targets. These policies will create jobs while protecting our environment...",
                    tags: ["climate", "energy", "environment"],
                    duration: 1800
                )
            ]
            isLoading = false
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
    @State private var searchText = ""
    @State private var searchResults: [PoliticalTranscript] = []
    
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
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                            searchResults = []
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding()
                
                if searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No results found")
                            .font(.headline)
                        
                        Text("Try different keywords or check spelling")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                } else if !searchResults.isEmpty {
                    List(searchResults) { transcript in
                        TranscriptRow(transcript: transcript)
                    }
                } else {
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
                            
                            Text("• Healthcare policy")
                            Text("• Climate change")
                            Text("• Economic recovery")
                            Text("• Specific speaker names")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Search")
        }
    }
    
    private func performSearch() {
        // Simulate search results
        searchResults = [
            PoliticalTranscript(
                title: "Healthcare Reform Discussion",
                speaker: "Senator Smith",
                date: Date(),
                content: "The proposed healthcare reforms will significantly impact millions of Americans...",
                tags: ["healthcare", "reform"],
                duration: 2400
            )
        ]
    }
}

struct BookmarksView: View {
    @State private var bookmarks: [SimpleBookmark] = []
    
    var body: some View {
        NavigationView {
            VStack {
                if bookmarks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Bookmarks")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Bookmark important moments in transcripts to access them quickly")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Add Sample Bookmarks") {
                            loadSampleBookmarks()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List(bookmarks) { bookmark in
                        SimpleBookmarkRow(bookmark: bookmark)
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        loadSampleBookmarks()
                    }
                }
            }
        }
    }
    
    private func loadSampleBookmarks() {
        bookmarks = [
            SimpleBookmark(
                id: UUID(),
                title: "Key Healthcare Point",
                transcriptTitle: "Healthcare Committee",
                timestamp: 245.0,
                note: "Important discussion about rural healthcare access"
            ),
            SimpleBookmark(
                id: UUID(),
                title: "Climate Action Plan",
                transcriptTitle: "Environmental Policy",
                timestamp: 1200.0,
                note: "Detailed carbon reduction timeline"
            )
        ]
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
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Stats
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        StatCard(title: "Total Transcripts", value: "12", icon: "doc.text")
                        StatCard(title: "Hours Analyzed", value: "47.3", icon: "clock")
                        StatCard(title: "Bookmarks", value: "89", icon: "bookmark")
                        StatCard(title: "Searches", value: "156", icon: "magnifyingglass")
                    }
                    
                    // Usage Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Weekly Usage")
                            .font(.headline)
                        
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue)
                                    Text("Usage Analytics")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Charts and insights coming soon")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                    
                    // Popular Topics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trending Topics")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            TopicRow(topic: "Healthcare Reform", mentions: 23, trend: .up)
                            TopicRow(topic: "Climate Policy", mentions: 18, trend: .up)
                            TopicRow(topic: "Economic Recovery", mentions: 15, trend: .stable)
                            TopicRow(topic: "Education Funding", mentions: 12, trend: .down)
                        }
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