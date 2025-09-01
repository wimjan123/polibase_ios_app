import SwiftUI

/// ContentManagementView provides a unified interface for advanced content management
/// including bookmarks, annotations, collections, and export capabilities
struct ContentManagementView: View {
    @StateObject private var bookmarkService = BookmarkService()
    @StateObject private var annotationService = AnnotationService(analyticsService: AnalyticsService())
    @StateObject private var exportService = ExportService(analyticsService: AnalyticsService())
    
    @State private var selectedTab: ContentTab = .bookmarks
    @State private var searchText = ""
    @State private var showingExportOptions = false
    @State private var showingAnnotationEditor = false
    @State private var showingCollectionCreator = false
    @State private var selectedItems: Set<String> = []
    @State private var filterType: ContentFilterType = .all
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar
                
                // Tab Picker
                tabPicker
                
                // Content Area
                contentArea
                    .refreshable {
                        await refreshContent()
                    }
            }
            .navigationTitle("Content Management")
            .navigationBarItems(
                leading: leadingNavigationItems,
                trailing: trailingNavigationItems
            )
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView(
                    exportService: exportService,
                    selectedItems: Array(selectedItems),
                    contentType: selectedTab
                )
            }
            .sheet(isPresented: $showingAnnotationEditor) {
                AnnotationEditorView(annotationService: annotationService)
            }
            .sheet(isPresented: $showingCollectionCreator) {
                CollectionCreatorView(bookmarkService: bookmarkService)
            }
        }
        .onAppear {
            Task {
                await loadInitialContent()
            }
        }
    }
    
    // MARK: - View Components
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search content...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        performSearch()
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Filter Options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ContentFilterType.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.displayName,
                            isSelected: filterType == filter,
                            action: {
                                filterType = filter
                                performSearch()
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var tabPicker: some View {
        Picker("Content Type", selection: $selectedTab) {
            ForEach(ContentTab.allCases, id: \.self) { tab in
                HStack {
                    Image(systemName: tab.icon)
                    Text(tab.displayName)
                }
                .tag(tab)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private var contentArea: some View {
        GeometryReader { geometry in
            switch selectedTab {
            case .bookmarks:
                BookmarksContentView(
                    bookmarkService: bookmarkService,
                    searchText: searchText,
                    filterType: filterType,
                    selectedItems: $selectedItems,
                    geometry: geometry
                )
            case .annotations:
                AnnotationsContentView(
                    annotationService: annotationService,
                    searchText: searchText,
                    filterType: filterType,
                    selectedItems: $selectedItems,
                    geometry: geometry
                )
            case .collections:
                CollectionsContentView(
                    bookmarkService: bookmarkService,
                    searchText: searchText,
                    filterType: filterType,
                    selectedItems: $selectedItems,
                    geometry: geometry
                )
            case .exports:
                ExportsContentView(
                    exportService: exportService,
                    searchText: searchText,
                    selectedItems: $selectedItems,
                    geometry: geometry
                )
            }
        }
    }
    
    private var leadingNavigationItems: some View {
        HStack {
            // Selection Controls
            if !selectedItems.isEmpty {
                Button("Clear") {
                    selectedItems.removeAll()
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    private var trailingNavigationItems: some View {
        HStack {
            // Action Buttons
            if !selectedItems.isEmpty {
                Menu {
                    Button(action: { showingExportOptions = true }) {
                        Label("Export Selected", systemImage: "square.and.arrow.up")
                    }
                    
                    if selectedTab == .bookmarks {
                        Button(action: { addToCollection() }) {
                            Label("Add to Collection", systemImage: "folder.badge.plus")
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: { deleteSelected() }) {
                        Label("Delete Selected", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            
            // Add Button
            Button(action: { showAddMenu() }) {
                Image(systemName: "plus")
            }
        }
    }
    
    // MARK: - Content Views
    
    private struct BookmarksContentView: View {
        @ObservedObject var bookmarkService: BookmarkService
        let searchText: String
        let filterType: ContentFilterType
        @Binding var selectedItems: Set<String>
        let geometry: GeometryProxy
        
        var filteredBookmarks: [BookmarkModel] {
            bookmarkService.bookmarks.filter { bookmark in
                let matchesSearch = searchText.isEmpty || 
                                   bookmark.title.localizedCaseInsensitiveContains(searchText) ||
                                   bookmark.notes?.localizedCaseInsensitiveContains(searchText) == true
                
                let matchesFilter = filterType == .all || {
                    switch filterType {
                    case .recent: return bookmark.createdAt.isWithinLastWeek
                    case .favorites: return bookmark.isFavorite
                    case .shared: return bookmark.isShared
                    case .private: return !bookmark.isShared
                    default: return true
                    }
                }()
                
                return matchesSearch && matchesFilter
            }
        }
        
        var body: some View {
            if filteredBookmarks.isEmpty {
                EmptyStateView(
                    icon: "bookmark",
                    title: "No Bookmarks Found",
                    description: searchText.isEmpty ? 
                        "Start bookmarking videos to see them here" : 
                        "No bookmarks match your search criteria"
                )
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: max(1, Int(geometry.size.width / 300))),
                    spacing: 16
                ) {
                    ForEach(filteredBookmarks) { bookmark in
                        BookmarkCard(
                            bookmark: bookmark,
                            isSelected: selectedItems.contains(bookmark.id),
                            onSelectionChanged: { isSelected in
                                if isSelected {
                                    selectedItems.insert(bookmark.id)
                                } else {
                                    selectedItems.remove(bookmark.id)
                                }
                            },
                            onTap: {
                                // Navigate to video detail
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }
    
    private struct AnnotationsContentView: View {
        @ObservedObject var annotationService: AnnotationService
        let searchText: String
        let filterType: ContentFilterType
        @Binding var selectedItems: Set<String>
        let geometry: GeometryProxy
        
        var filteredAnnotations: [AnnotationModel] {
            annotationService.annotations.filter { annotation in
                let matchesSearch = searchText.isEmpty || 
                                   annotation.content.localizedCaseInsensitiveContains(searchText) ||
                                   annotation.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
                
                let matchesFilter = filterType == .all || {
                    switch filterType {
                    case .recent: return annotation.createdAt.isWithinLastWeek
                    case .shared: return annotation.isPublic || annotation.collaborators.count > 1
                    case .private: return !annotation.isPublic && annotation.collaborators.count <= 1
                    default: return true
                    }
                }()
                
                return matchesSearch && matchesFilter
            }
        }
        
        var body: some View {
            if filteredAnnotations.isEmpty {
                EmptyStateView(
                    icon: "note.text",
                    title: "No Annotations Found",
                    description: searchText.isEmpty ? 
                        "Start annotating videos to see them here" : 
                        "No annotations match your search criteria"
                )
            } else {
                List {
                    ForEach(filteredAnnotations) { annotation in
                        AnnotationRow(
                            annotation: annotation,
                            isSelected: selectedItems.contains(annotation.id),
                            onSelectionChanged: { isSelected in
                                if isSelected {
                                    selectedItems.insert(annotation.id)
                                } else {
                                    selectedItems.remove(annotation.id)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    private struct CollectionsContentView: View {
        @ObservedObject var bookmarkService: BookmarkService
        let searchText: String
        let filterType: ContentFilterType
        @Binding var selectedItems: Set<String>
        let geometry: GeometryProxy
        
        var filteredCollections: [CollectionModel] {
            bookmarkService.collections.filter { collection in
                let matchesSearch = searchText.isEmpty || 
                                   collection.name.localizedCaseInsensitiveContains(searchText) ||
                                   collection.description?.localizedCaseInsensitiveContains(searchText) == true
                
                let matchesFilter = filterType == .all || {
                    switch filterType {
                    case .recent: return collection.createdAt.isWithinLastWeek
                    case .shared: return collection.isShared
                    case .private: return !collection.isShared
                    default: return true
                    }
                }()
                
                return matchesSearch && matchesFilter
            }
        }
        
        var body: some View {
            if filteredCollections.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: "No Collections Found",
                    description: searchText.isEmpty ? 
                        "Create collections to organize your bookmarks" : 
                        "No collections match your search criteria"
                )
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: max(1, Int(geometry.size.width / 250))),
                    spacing: 16
                ) {
                    ForEach(filteredCollections) { collection in
                        CollectionCard(
                            collection: collection,
                            isSelected: selectedItems.contains(collection.id),
                            onSelectionChanged: { isSelected in
                                if isSelected {
                                    selectedItems.insert(collection.id)
                                } else {
                                    selectedItems.remove(collection.id)
                                }
                            },
                            onTap: {
                                // Navigate to collection detail
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }
    
    private struct ExportsContentView: View {
        @ObservedObject var exportService: ExportService
        let searchText: String
        @Binding var selectedItems: Set<String>
        let geometry: GeometryProxy
        
        var filteredExports: [ExportHistoryModel] {
            exportService.exportHistory.filter { export in
                searchText.isEmpty || 
                export.filename.localizedCaseInsensitiveContains(searchText) ||
                export.videoTitles.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        var body: some View {
            if filteredExports.isEmpty {
                EmptyStateView(
                    icon: "square.and.arrow.up",
                    title: "No Exports Found",
                    description: searchText.isEmpty ? 
                        "Export some content to see your export history here" : 
                        "No exports match your search criteria"
                )
            } else {
                List {
                    ForEach(filteredExports) { export in
                        ExportRow(
                            export: export,
                            isSelected: selectedItems.contains(export.id),
                            onSelectionChanged: { isSelected in
                                if isSelected {
                                    selectedItems.insert(export.id)
                                } else {
                                    selectedItems.remove(export.id)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Card Components
    
    private struct BookmarkCard: View {
        let bookmark: BookmarkModel
        let isSelected: Bool
        let onSelectionChanged: (Bool) -> Void
        let onTap: () -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bookmark.title)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Text(bookmark.video?.speaker ?? "Unknown Speaker")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Selection checkbox
                    Button(action: { onSelectionChanged(!isSelected) }) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .blue : .secondary)
                    }
                }
                
                // Thumbnail
                AsyncImage(url: bookmark.video?.thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            Image(systemName: "video")
                                .foregroundColor(.gray)
                        )
                }
                .cornerRadius(8)
                
                // Metadata
                VStack(alignment: .leading, spacing: 4) {
                    if let notes = bookmark.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(bookmark.createdAt.formatted(.relative(presentation: .abbreviated)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if bookmark.isFavorite {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                        }
                        
                        if bookmark.isShared {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.blue)
                                .font(.caption2)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .onTapGesture {
                onTap()
            }
        }
    }
    
    private struct CollectionCard: View {
        let collection: CollectionModel
        let isSelected: Bool
        let onSelectionChanged: (Bool) -> Void
        let onTap: () -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(collection.name)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text("\(collection.bookmarkIds.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { onSelectionChanged(!isSelected) }) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .blue : .secondary)
                    }
                }
                
                // Icon and content preview
                VStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    
                    if let description = collection.description {
                        Text(description)
                            .font(.caption)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                
                // Metadata
                HStack {
                    Text(collection.createdAt.formatted(.relative(presentation: .abbreviated)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if collection.isShared {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                            .font(.caption2)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .onTapGesture {
                onTap()
            }
        }
    }
    
    private struct AnnotationRow: View {
        let annotation: AnnotationModel
        let isSelected: Bool
        let onSelectionChanged: (Bool) -> Void
        
        var body: some View {
            HStack {
                // Selection checkbox
                Button(action: { onSelectionChanged(!isSelected) }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Type and timestamp
                    HStack {
                        Label(annotation.type.displayName, systemImage: annotation.type.icon)
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(formatTimestamp(annotation.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Content
                    Text(annotation.content)
                        .lineLimit(3)
                    
                    // Tags and metadata
                    HStack {
                        if !annotation.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(annotation.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Text(annotation.createdAt.formatted(.relative(presentation: .abbreviated)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        
        private func formatTimestamp(_ seconds: TimeInterval) -> String {
            let hours = Int(seconds) / 3600
            let minutes = Int(seconds) % 3600 / 60
            let secs = Int(seconds) % 60
            
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, secs)
            } else {
                return String(format: "%d:%02d", minutes, secs)
            }
        }
    }
    
    private struct ExportRow: View {
        let export: ExportHistoryModel
        let isSelected: Bool
        let onSelectionChanged: (Bool) -> Void
        
        var body: some View {
            HStack {
                // Selection checkbox
                Button(action: { onSelectionChanged(!isSelected) }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Filename and format
                    HStack {
                        Text(export.filename)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(export.format.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    // Content preview
                    if !export.videoTitles.isEmpty {
                        Text(export.videoTitles.joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Metadata
                    HStack {
                        Text("\(export.itemCount) items")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(ByteCountFormatter.string(fromByteCount: export.fileSize, countStyle: .file))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(export.createdAt.formatted(.relative(presentation: .abbreviated)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Helper Components
    
    private struct FilterChip: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(isSelected ? .white : .primary)
                    .cornerRadius(16)
            }
        }
    }
    
    private struct EmptyStateView: View {
        let icon: String
        let title: String
        let description: String
        
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialContent() async {
        // Load content for all services
        async let bookmarksTask = bookmarkService.loadBookmarks()
        async let annotationsTask = annotationService.loadAnnotations(for: "all")
        
        do {
            _ = try await bookmarksTask
            _ = try await annotationsTask
        } catch {
            print("Failed to load initial content: \(error)")
        }
    }
    
    private func refreshContent() async {
        await loadInitialContent()
    }
    
    private func performSearch() {
        // Trigger search across all content types
        // This would be handled by the individual content views
    }
    
    private func showAddMenu() {
        switch selectedTab {
        case .bookmarks:
            // Show bookmark creation
            break
        case .annotations:
            showingAnnotationEditor = true
        case .collections:
            showingCollectionCreator = true
        case .exports:
            showingExportOptions = true
        }
    }
    
    private func addToCollection() {
        // Add selected items to a collection
    }
    
    private func deleteSelected() {
        // Delete selected items
        Task {
            do {
                switch selectedTab {
                case .bookmarks:
                    for id in selectedItems {
                        try await bookmarkService.deleteBookmark(id)
                    }
                case .annotations:
                    for id in selectedItems {
                        try await annotationService.deleteAnnotation(id)
                    }
                case .collections:
                    for id in selectedItems {
                        try await bookmarkService.deleteCollection(id)
                    }
                case .exports:
                    // Delete export files
                    break
                }
                selectedItems.removeAll()
            } catch {
                print("Failed to delete items: \(error)")
            }
        }
    }
}

// MARK: - Enums

enum ContentTab: String, CaseIterable {
    case bookmarks = "bookmarks"
    case annotations = "annotations"
    case collections = "collections"
    case exports = "exports"
    
    var displayName: String {
        switch self {
        case .bookmarks: return "Bookmarks"
        case .annotations: return "Annotations"
        case .collections: return "Collections"
        case .exports: return "Exports"
        }
    }
    
    var icon: String {
        switch self {
        case .bookmarks: return "bookmark"
        case .annotations: return "note.text"
        case .collections: return "folder"
        case .exports: return "square.and.arrow.up"
        }
    }
}

enum ContentFilterType: String, CaseIterable {
    case all = "all"
    case recent = "recent"
    case favorites = "favorites"
    case shared = "shared"
    case `private` = "private"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .recent: return "Recent"
        case .favorites: return "Favorites"
        case .shared: return "Shared"
        case .private: return "Private"
        }
    }
}

// MARK: - Supporting Views

struct ExportOptionsView: View {
    @ObservedObject var exportService: ExportService
    let selectedItems: [String]
    let contentType: ContentTab
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: ExportFormat = .pdf
    @State private var selectedCitationStyle: CitationStyle = .apa
    @State private var includeMetadata = true
    @State private var includeTimestamps = true
    @State private var includeAnalysis = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Options") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    
                    Picker("Citation Style", selection: $selectedCitationStyle) {
                        ForEach(CitationStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                }
                
                Section("Include") {
                    Toggle("Metadata", isOn: $includeMetadata)
                    Toggle("Timestamps", isOn: $includeTimestamps)
                    Toggle("Analysis", isOn: $includeAnalysis)
                }
                
                Section {
                    Button("Export \(selectedItems.count) Items") {
                        performExport()
                    }
                    .disabled(selectedItems.isEmpty)
                }
            }
            .navigationTitle("Export Options")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Export") { performExport() }
            )
        }
    }
    
    private func performExport() {
        Task {
            // Perform export based on content type
            dismiss()
        }
    }
}

struct AnnotationEditorView: View {
    @ObservedObject var annotationService: AnnotationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Annotation Editor")
                .navigationTitle("New Annotation")
                .navigationBarItems(
                    leading: Button("Cancel") { dismiss() },
                    trailing: Button("Save") { dismiss() }
                )
        }
    }
}

struct CollectionCreatorView: View {
    @ObservedObject var bookmarkService: BookmarkService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Collection Creator")
                .navigationTitle("New Collection")
                .navigationBarItems(
                    leading: Button("Cancel") { dismiss() },
                    trailing: Button("Create") { dismiss() }
                )
        }
    }
}

// MARK: - Extensions

extension Date {
    var isWithinLastWeek: Bool {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return self > weekAgo
    }
}

#Preview {
    ContentManagementView()
}
