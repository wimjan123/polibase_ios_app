import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Header
                searchHeaderView
                
                // Content Area
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    noResultsView
                } else if viewModel.searchResults.isEmpty {
                    emptyStateView
                } else {
                    searchResultsView
                }
            }
            .navigationTitle("Search Transcripts")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $viewModel.showFilters) {
                SearchFiltersView(filters: $viewModel.filters)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Search Error", isPresented: $viewModel.showError) {
                Button("Retry") {
                    Task {
                        await viewModel.performSearch()
                    }
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .onAppear {
            viewModel.loadSearchHistory()
        }
    }
    
    // MARK: - Search Header
    private var searchHeaderView: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                searchBar
                filterButton
            }
            .padding(.horizontal)
            
            // Quick Filters
            if viewModel.hasActiveFilters {
                activeFiltersView
            }
            
            // Search Suggestions
            if viewModel.showSuggestions && !viewModel.suggestions.isEmpty {
                suggestionsView
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search political transcripts...", text: $viewModel.searchQuery)
                .focused($isSearchFieldFocused)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .onSubmit {
                    Task {
                        await viewModel.performSearch()
                    }
                }
                .onChange(of: viewModel.searchQuery) { _ in
                    viewModel.onSearchQueryChanged()
                }
            
            if !viewModel.searchQuery.isEmpty {
                Button(action: viewModel.clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private var filterButton: some View {
        Button(action: { viewModel.showFilters = true }) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                if viewModel.activeFilterCount > 0 {
                    Text("\(viewModel.activeFilterCount)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - Active Filters
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.activeFilterTags, id: \.self) { tag in
                    FilterTagView(
                        text: tag,
                        onRemove: { viewModel.removeFilter(tag) }
                    )
                }
                
                Button("Clear All") {
                    viewModel.clearAllFilters()
                }
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Suggestions
    private var suggestionsView: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.suggestions.prefix(5), id: \.id) { suggestion in
                SuggestionRowView(
                    suggestion: suggestion,
                    searchQuery: viewModel.searchQuery,
                    onTap: { viewModel.selectSuggestion(suggestion) }
                )
                
                if suggestion.id != viewModel.suggestions.prefix(5).last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // MARK: - Content Views
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching transcripts...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Try adjusting your search terms or filters")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button("Clear Filters") {
                    viewModel.clearAllFilters()
                }
                .buttonStyle(.bordered)
                
                Button("Search Tips") {
                    viewModel.showSearchTips = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "video.and.waveform")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Search Political Transcripts")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Find speeches, debates, and interviews by searching for specific topics, speakers, or phrases.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Quick Search Suggestions
            if !viewModel.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Searches")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 120))
                    ], spacing: 8) {
                        ForEach(viewModel.recentSearches.prefix(6), id: \.id) { search in
                            Button(search.query) {
                                viewModel.selectRecentSearch(search)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var searchResultsView: some View {
        VStack(spacing: 0) {
            // Results Header
            searchResultsHeader
            
            // Results List
            List {
                ForEach(viewModel.searchResults, id: \.id) { result in
                    SearchResultRowView(
                        result: result,
                        searchQuery: viewModel.searchQuery,
                        onTap: { viewModel.selectSearchResult(result) }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .onAppear {
                        if result.id == viewModel.searchResults.last?.id {
                            Task {
                                await viewModel.loadMoreResults()
                            }
                        }
                    }
                }
                
                // Load More Section
                if viewModel.hasMoreResults {
                    loadMoreSection
                }
            }
            .listStyle(.plain)
            .refreshable {
                await viewModel.refreshResults()
            }
        }
    }
    
    private var searchResultsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if viewModel.totalResults > 0 {
                    Text("\(viewModel.totalResults) results")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Showing \(min(viewModel.searchResults.count, viewModel.totalResults)) of \(viewModel.totalResults)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(viewModel.searchResults.count) results")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // Sort Button
            Menu {
                ForEach(SearchFilterModel.SortOption.allCases, id: \.self) { option in
                    Button(action: {
                        viewModel.filters.sortBy = option
                        Task {
                            await viewModel.performSearch()
                        }
                    }) {
                        HStack {
                            Text(option.displayName)
                            if viewModel.filters.sortBy == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button(action: {
                    viewModel.filters.sortOrder = viewModel.filters.sortOrder == .ascending ? .descending : .ascending
                    Task {
                        await viewModel.performSearch()
                    }
                }) {
                    HStack {
                        Text("Sort Order: \(viewModel.filters.sortOrder.displayName)")
                        Image(systemName: viewModel.filters.sortOrder == .ascending ? "arrow.up" : "arrow.down")
                    }
                }
            } label: {
                HStack {
                    Text("Sort")
                    Image(systemName: "arrow.up.arrow.down")
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var loadMoreSection: some View {
        HStack {
            Spacer()
            
            if viewModel.isLoadingMore {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading more results...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                Button("Load More Results") {
                    Task {
                        await viewModel.loadMoreResults()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding()
            }
            
            Spacer()
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Supporting Views
struct FilterTagView: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SuggestionRowView: View {
    let suggestion: SearchSuggestionModel
    let searchQuery: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: suggestion.type.icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    highlightedText
                    
                    if let category = suggestion.category {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let frequency = suggestion.frequency, frequency > 1 {
                    Text("\(frequency)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var highlightedText: some View {
        Text(highlightedAttributedString)
            .font(.body)
    }
    
    private var highlightedAttributedString: AttributedString {
        var attributedString = AttributedString(suggestion.text)
        
        if !searchQuery.isEmpty {
            let range = suggestion.text.lowercased().range(of: searchQuery.lowercased())
            if let range = range {
                let nsRange = NSRange(range, in: suggestion.text)
                let startIndex = attributedString.startIndex
                let start = attributedString.index(startIndex, offsetByCharacters: nsRange.location)
                let end = attributedString.index(start, offsetByCharacters: nsRange.length)
                
                attributedString[start..<end].foregroundColor = .blue
                attributedString[start..<end].font = .body.weight(.semibold)
            }
        }
        
        return attributedString
    }
}

struct SearchResultRowView: View {
    let result: SearchResultModel
    let searchQuery: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Video Info
                HStack(spacing: 12) {
                    AsyncImage(url: result.video.thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "video")
                                    .foregroundColor(.secondary)
                            )
                    }
                    .frame(width: 80, height: 60)
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.video.title)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        HStack {
                            if let speaker = result.video.speaker {
                                Text(speaker)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(result.video.formattedDuration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text(result.formattedRelevanceScore)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                            
                            Text("\(result.matchCount) matches")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                }
                
                // Matching Segments Preview
                if !result.matchingSegments.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(result.matchingSegments.prefix(2), id: \.id) { segment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(segment.formattedStartTime)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                    
                                    if let speaker = segment.speaker {
                                        Text(speaker)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                
                                Text(segment.text.truncated(to: 150))
                                    .font(.callout)
                                    .foregroundColor(.primary)
                                    .lineLimit(3)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        if result.matchingSegments.count > 2 {
                            Text("+ \(result.matchingSegments.count - 2) more matches")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.leading, 12)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SearchView()
}
