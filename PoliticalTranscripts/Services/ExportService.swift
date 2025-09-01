import Foundation
import UniformTypeIdentifiers

/// ExportService provides comprehensive export capabilities with academic citations,
/// multi-format support, and professional document generation
@MainActor
class ExportService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var lastExportedItems: [ExportedItemModel] = []
    @Published var exportHistory: [ExportHistoryModel] = []
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let analyticsService: AnalyticsService
    private let fileManager = FileManager.default
    private let dateFormatter = ISO8601DateFormatter()
    
    // MARK: - Configuration
    private let maxExportItems = 1000
    private let exportCacheDirectory: URL
    
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
        
        // Setup export cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.exportCacheDirectory = documentsPath.appendingPathComponent("ExportCache")
        
        createExportCacheDirectory()
        loadExportHistory()
    }
    
    // MARK: - Video Export Methods
    
    /// Exports video transcripts with comprehensive metadata
    func exportVideoTranscripts(
        videos: [VideoModel],
        format: ExportFormat,
        citationStyle: CitationStyle = .apa,
        includeMetadata: Bool = true,
        includeTimestamps: Bool = true,
        customTemplate: String? = nil
    ) async throws -> ExportResultModel {
        guard !videos.isEmpty else {
            throw ExportError.noContentToExport
        }
        
        guard videos.count <= maxExportItems else {
            throw ExportError.tooManyItems
        }
        
        isExporting = true
        exportProgress = 0.0
        defer { 
            isExporting = false
            exportProgress = 0.0
        }
        
        let exportId = UUID().uuidString
        let startTime = Date()
        
        do {
            // Prepare export data
            await updateProgress(0.1, message: "Preparing export data...")
            let exportData = try await prepareVideoExportData(
                videos: videos,
                includeMetadata: includeMetadata,
                includeTimestamps: includeTimestamps
            )
            
            // Generate citations
            await updateProgress(0.3, message: "Generating citations...")
            let citations = generateCitations(for: videos, style: citationStyle)
            
            // Create export content
            await updateProgress(0.5, message: "Formatting content...")
            let content = try await formatExportContent(
                data: exportData,
                citations: citations,
                format: format,
                template: customTemplate
            )
            
            // Save to file
            await updateProgress(0.8, message: "Saving export file...")
            let fileURL = try await saveExportToFile(
                content: content,
                format: format,
                filename: generateFilename(for: videos, format: format)
            )
            
            // Create result
            await updateProgress(1.0, message: "Export completed!")
            let result = ExportResultModel(
                id: exportId,
                fileURL: fileURL,
                format: format,
                itemCount: videos.count,
                fileSize: try getFileSize(at: fileURL),
                citationStyle: citationStyle,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(7 * 24 * 3600), // 7 days
                metadata: ExportMetadata(
                    includeMetadata: includeMetadata,
                    includeTimestamps: includeTimestamps,
                    customTemplate: customTemplate != nil
                )
            )
            
            // Update history
            await updateExportHistory(result: result, videos: videos)
            
            // Track analytics
            await analyticsService.trackExportCompleted(
                exportId: exportId,
                format: format.rawValue,
                itemCount: videos.count,
                citationStyle: citationStyle.rawValue,
                duration: Date().timeIntervalSince(startTime)
            )
            
            return result
            
        } catch {
            await analyticsService.trackExportFailed(
                exportId: exportId,
                format: format.rawValue,
                error: error.localizedDescription
            )
            throw error
        }
    }
    
    /// Exports search results with comprehensive analysis
    func exportSearchResults(
        results: [SearchResultModel],
        query: String,
        filters: SearchFilterModel,
        format: ExportFormat,
        citationStyle: CitationStyle = .apa,
        includeAnalysis: Bool = true,
        includeCharts: Bool = false
    ) async throws -> ExportResultModel {
        guard !results.isEmpty else {
            throw ExportError.noContentToExport
        }
        
        isExporting = true
        exportProgress = 0.0
        defer { 
            isExporting = false
            exportProgress = 0.0
        }
        
        let exportId = UUID().uuidString
        let startTime = Date()
        
        do {
            // Prepare search analysis
            await updateProgress(0.1, message: "Analyzing search results...")
            let analysis = try await generateSearchAnalysis(
                results: results,
                query: query,
                filters: filters,
                includeCharts: includeCharts
            )
            
            // Generate citations
            await updateProgress(0.3, message: "Generating citations...")
            let videos = results.map { $0.video }
            let citations = generateCitations(for: videos, style: citationStyle)
            
            // Create comprehensive export
            await updateProgress(0.5, message: "Creating comprehensive export...")
            let content = try await formatSearchResultsExport(
                results: results,
                query: query,
                filters: filters,
                analysis: analysis,
                citations: citations,
                format: format,
                includeAnalysis: includeAnalysis
            )
            
            // Save to file
            await updateProgress(0.8, message: "Saving export file...")
            let filename = "search-results-\(query.lowercased().replacingOccurrences(of: " ", with: "-"))-\(dateFormatter.string(from: Date()))"
            let fileURL = try await saveExportToFile(
                content: content,
                format: format,
                filename: filename
            )
            
            // Create result
            await updateProgress(1.0, message: "Export completed!")
            let result = ExportResultModel(
                id: exportId,
                fileURL: fileURL,
                format: format,
                itemCount: results.count,
                fileSize: try getFileSize(at: fileURL),
                citationStyle: citationStyle,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(7 * 24 * 3600),
                metadata: ExportMetadata(
                    searchQuery: query,
                    includeAnalysis: includeAnalysis,
                    includeCharts: includeCharts
                )
            )
            
            // Track analytics
            await analyticsService.trackSearchExportCompleted(
                exportId: exportId,
                query: query,
                resultCount: results.count,
                format: format.rawValue,
                duration: Date().timeIntervalSince(startTime)
            )
            
            return result
            
        } catch {
            await analyticsService.trackExportFailed(
                exportId: exportId,
                format: format.rawValue,
                error: error.localizedDescription
            )
            throw error
        }
    }
    
    /// Exports bookmarks and collections
    func exportBookmarks(
        bookmarks: [BookmarkModel],
        collections: [CollectionModel],
        format: ExportFormat,
        citationStyle: CitationStyle = .apa,
        includeNotes: Bool = true,
        includeCollections: Bool = true
    ) async throws -> ExportResultModel {
        guard !bookmarks.isEmpty || !collections.isEmpty else {
            throw ExportError.noContentToExport
        }
        
        isExporting = true
        exportProgress = 0.0
        defer { 
            isExporting = false
            exportProgress = 0.0
        }
        
        let exportId = UUID().uuidString
        
        do {
            // Prepare bookmark data
            await updateProgress(0.2, message: "Organizing bookmarks...")
            let organizedData = try await organizeBookmarkData(
                bookmarks: bookmarks,
                collections: collections,
                includeNotes: includeNotes,
                includeCollections: includeCollections
            )
            
            // Generate citations for bookmarked videos
            await updateProgress(0.4, message: "Generating citations...")
            let videos = bookmarks.compactMap { $0.video }
            let citations = generateCitations(for: videos, style: citationStyle)
            
            // Format export content
            await updateProgress(0.6, message: "Formatting content...")
            let content = try await formatBookmarksExport(
                data: organizedData,
                citations: citations,
                format: format
            )
            
            // Save to file
            await updateProgress(0.8, message: "Saving export file...")
            let filename = "bookmarks-export-\(dateFormatter.string(from: Date()))"
            let fileURL = try await saveExportToFile(
                content: content,
                format: format,
                filename: filename
            )
            
            // Create result
            await updateProgress(1.0, message: "Export completed!")
            let result = ExportResultModel(
                id: exportId,
                fileURL: fileURL,
                format: format,
                itemCount: bookmarks.count + collections.count,
                fileSize: try getFileSize(at: fileURL),
                citationStyle: citationStyle,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(7 * 24 * 3600),
                metadata: ExportMetadata(
                    includeNotes: includeNotes,
                    includeCollections: includeCollections
                )
            )
            
            return result
            
        } catch {
            throw error
        }
    }
    
    // MARK: - Citation Generation
    
    private func generateCitations(for videos: [VideoModel], style: CitationStyle) -> [CitationModel] {
        return videos.compactMap { video in
            generateCitation(for: video, style: style)
        }
    }
    
    private func generateCitation(for video: VideoModel, style: CitationStyle) -> CitationModel? {
        let citation: String
        
        switch style {
        case .apa:
            citation = generateAPACitation(for: video)
        case .mla:
            citation = generateMLACitation(for: video)
        case .chicago:
            citation = generateChicagoCitation(for: video)
        case .harvard:
            citation = generateHarvardCitation(for: video)
        case .ieee:
            citation = generateIEEECitation(for: video)
        }
        
        return CitationModel(
            id: video.id,
            videoId: video.id,
            style: style,
            citation: citation,
            shortCitation: generateShortCitation(for: video, style: style),
            createdAt: Date()
        )
    }
    
    private func generateAPACitation(for video: VideoModel) -> String {
        let author = video.speaker ?? "Unknown Speaker"
        let year = Calendar.current.component(.year, from: video.publishedDate)
        let title = video.title
        let source = video.source ?? "Political Transcripts Database"
        let url = video.url.absoluteString
        let accessDate = DateFormatter.mediumDateFormatter.string(from: Date())
        
        return "\(author) (\(year)). \(title) [Video]. \(source). \(url) (accessed \(accessDate))."
    }
    
    private func generateMLACitation(for video: VideoModel) -> String {
        let author = video.speaker ?? "Unknown Speaker"
        let title = "\"\(video.title)\""
        let source = video.source ?? "Political Transcripts Database"
        let date = DateFormatter.mediumDateFormatter.string(from: video.publishedDate)
        let url = video.url.absoluteString
        let accessDate = DateFormatter.mediumDateFormatter.string(from: Date())
        
        return "\(author). \(title) \(source), \(date), \(url). Accessed \(accessDate)."
    }
    
    private func generateChicagoCitation(for video: VideoModel) -> String {
        let author = video.speaker ?? "Unknown Speaker"
        let title = "\"\(video.title)\""
        let source = video.source ?? "Political Transcripts Database"
        let date = DateFormatter.mediumDateFormatter.string(from: video.publishedDate)
        let url = video.url.absoluteString
        let accessDate = DateFormatter.mediumDateFormatter.string(from: Date())
        
        return "\(author). \(title) \(source). \(date). \(url) (accessed \(accessDate))."
    }
    
    private func generateHarvardCitation(for video: VideoModel) -> String {
        let author = video.speaker ?? "Unknown Speaker"
        let year = Calendar.current.component(.year, from: video.publishedDate)
        let title = video.title
        let source = video.source ?? "Political Transcripts Database"
        let url = video.url.absoluteString
        let accessDate = DateFormatter.mediumDateFormatter.string(from: Date())
        
        return "\(author) \(year), \(title), \(source), viewed \(accessDate), <\(url)>."
    }
    
    private func generateIEEECitation(for video: VideoModel) -> String {
        let author = video.speaker ?? "Unknown Speaker"
        let title = "\"\(video.title)\""
        let source = video.source ?? "Political Transcripts Database"
        let date = DateFormatter.mediumDateFormatter.string(from: video.publishedDate)
        let url = video.url.absoluteString
        let accessDate = DateFormatter.mediumDateFormatter.string(from: Date())
        
        return "\(author), \(title), \(source), \(date). [Online]. Available: \(url). [Accessed: \(accessDate)]."
    }
    
    private func generateShortCitation(for video: VideoModel, style: CitationStyle) -> String {
        let author = video.speaker ?? "Unknown"
        let year = Calendar.current.component(.year, from: video.publishedDate)
        
        switch style {
        case .apa, .harvard:
            return "(\(author), \(year))"
        case .mla:
            return "(\(author))"
        case .chicago:
            return "\(author), \(year)"
        case .ieee:
            return "[\(video.id.prefix(8))]"
        }
    }
    
    // MARK: - Content Formatting
    
    private func prepareVideoExportData(
        videos: [VideoModel],
        includeMetadata: Bool,
        includeTimestamps: Bool
    ) async throws -> VideoExportData {
        var processedVideos: [ProcessedVideoModel] = []
        
        for (index, video) in videos.enumerated() {
            let progress = Double(index) / Double(videos.count) * 0.2 // 20% of total progress
            await updateProgress(progress, message: "Processing video \(index + 1) of \(videos.count)...")
            
            let processedVideo = ProcessedVideoModel(
                video: video,
                formattedTranscript: formatTranscript(video.transcriptSegments, includeTimestamps: includeTimestamps),
                metadata: includeMetadata ? extractMetadata(from: video) : nil,
                wordCount: calculateWordCount(video.transcriptSegments)
            )
            
            processedVideos.append(processedVideo)
        }
        
        return VideoExportData(
            videos: processedVideos,
            totalVideos: videos.count,
            totalWordCount: processedVideos.reduce(0) { $0 + $1.wordCount },
            exportDate: Date()
        )
    }
    
    private func formatExportContent(
        data: VideoExportData,
        citations: [CitationModel],
        format: ExportFormat,
        template: String?
    ) async throws -> Data {
        switch format {
        case .json:
            return try JSONEncoder().encode(data)
        case .csv:
            return try formatAsCSV(data: data, citations: citations)
        case .markdown:
            return try formatAsMarkdown(data: data, citations: citations, template: template)
        case .pdf:
            return try await formatAsPDF(data: data, citations: citations, template: template)
        case .docx:
            return try formatAsDocx(data: data, citations: citations, template: template)
        case .html:
            return try formatAsHTML(data: data, citations: citations, template: template)
        }
    }
    
    private func formatAsCSV(data: VideoExportData, citations: [CitationModel]) throws -> Data {
        var csv = "ID,Title,Speaker,Date,Duration,Source,Category,Word Count,Citation,Transcript\n"
        
        for video in data.videos {
            let citation = citations.first { $0.videoId == video.video.id }?.citation ?? ""
            let transcript = video.formattedTranscript.replacingOccurrences(of: "\"", with: "\"\"")
            
            let row = [
                video.video.id,
                video.video.title,
                video.video.speaker ?? "",
                DateFormatter.mediumDateFormatter.string(from: video.video.publishedDate),
                video.video.formattedDuration,
                video.video.source ?? "",
                video.video.category ?? "",
                String(video.wordCount),
                citation,
                "\"\(transcript)\""
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv.data(using: .utf8) ?? Data()
    }
    
    private func formatAsMarkdown(data: VideoExportData, citations: [CitationModel], template: String?) throws -> Data {
        var markdown = template ?? defaultMarkdownTemplate
        
        // Replace template variables
        markdown = markdown.replacingOccurrences(of: "{{export_date}}", with: DateFormatter.fullDateFormatter.string(from: data.exportDate))
        markdown = markdown.replacingOccurrences(of: "{{video_count}}", with: String(data.totalVideos))
        markdown = markdown.replacingOccurrences(of: "{{word_count}}", with: String(data.totalWordCount))
        
        // Add content
        var content = ""
        var bibliographyContent = ""
        
        for video in data.videos {
            let citation = citations.first { $0.videoId == video.video.id }
            
            content += "## \(video.video.title)\n\n"
            content += "**Speaker:** \(video.video.speaker ?? "Unknown")\n"
            content += "**Date:** \(DateFormatter.mediumDateFormatter.string(from: video.video.publishedDate))\n"
            content += "**Duration:** \(video.video.formattedDuration)\n"
            content += "**Source:** \(video.video.source ?? "Unknown")\n\n"
            
            if let citation = citation {
                content += "**Citation:** \(citation.shortCitation)\n\n"
                bibliographyContent += "- \(citation.citation)\n"
            }
            
            content += "### Transcript\n\n"
            content += video.formattedTranscript + "\n\n"
            content += "---\n\n"
        }
        
        markdown = markdown.replacingOccurrences(of: "{{content}}", with: content)
        markdown = markdown.replacingOccurrences(of: "{{bibliography}}", with: bibliographyContent)
        
        return markdown.data(using: .utf8) ?? Data()
    }
    
    private func formatAsPDF(data: VideoExportData, citations: [CitationModel], template: String?) async throws -> Data {
        // This would integrate with a PDF generation library like PDFKit
        // For now, return markdown as text
        let markdownData = try formatAsMarkdown(data: data, citations: citations, template: template)
        return markdownData
    }
    
    private func formatAsDocx(data: VideoExportData, citations: [CitationModel], template: String?) throws -> Data {
        // This would integrate with a DOCX generation library
        // For now, return markdown as text
        let markdownData = try formatAsMarkdown(data: data, citations: citations, template: template)
        return markdownData
    }
    
    private func formatAsHTML(data: VideoExportData, citations: [CitationModel], template: String?) throws -> Data {
        let markdownData = try formatAsMarkdown(data: data, citations: citations, template: template)
        let markdown = String(data: markdownData, encoding: .utf8) ?? ""
        
        // Basic Markdown to HTML conversion
        var html = markdown
            .replacingOccurrences(of: "# ", with: "<h1>")
            .replacingOccurrences(of: "\n", with: "</h1>\n", options: .literal, range: html.range(of: "<h1>"))
            .replacingOccurrences(of: "## ", with: "<h2>")
            .replacingOccurrences(of: "\n", with: "</h2>\n")
            .replacingOccurrences(of: "### ", with: "<h3>")
            .replacingOccurrences(of: "\n", with: "</h3>\n")
            .replacingOccurrences(of: "**", with: "<strong>", options: .literal)
            .replacingOccurrences(of: "**", with: "</strong>", options: .literal)
            .replacingOccurrences(of: "\n\n", with: "</p>\n<p>")
            .replacingOccurrences(of: "---", with: "<hr>")
        
        html = "<html><body><p>" + html + "</p></body></html>"
        
        return html.data(using: .utf8) ?? Data()
    }
    
    // MARK: - Helper Methods
    
    private func generateSearchAnalysis(
        results: [SearchResultModel],
        query: String,
        filters: SearchFilterModel,
        includeCharts: Bool
    ) async throws -> SearchAnalysisModel {
        // Generate comprehensive analysis of search results
        let speakerCounts = Dictionary(grouping: results) { $0.video.speaker ?? "Unknown" }
            .mapValues { $0.count }
        
        let sourceCounts = Dictionary(grouping: results) { $0.video.source ?? "Unknown" }
            .mapValues { $0.count }
        
        let categoryCounts = Dictionary(grouping: results) { $0.video.category ?? "Unknown" }
            .mapValues { $0.count }
        
        let dateRange = results.map { $0.video.publishedDate }.sorted()
        let earliestDate = dateRange.first ?? Date()
        let latestDate = dateRange.last ?? Date()
        
        return SearchAnalysisModel(
            query: query,
            totalResults: results.count,
            averageRelevanceScore: results.map { $0.relevanceScore }.reduce(0, +) / Double(results.count),
            speakerDistribution: speakerCounts,
            sourceDistribution: sourceCounts,
            categoryDistribution: categoryCounts,
            dateRange: DateInterval(start: earliestDate, end: latestDate),
            topKeywords: extractTopKeywords(from: results),
            charts: includeCharts ? generateChartData(from: results) : nil
        )
    }
    
    private func extractTopKeywords(from results: [SearchResultModel]) -> [String] {
        // Simple keyword extraction - could be enhanced with NLP
        let allText = results.compactMap { result in
            result.video.transcriptSegments?.map { $0.text }.joined(separator: " ")
        }.joined(separator: " ")
        
        let words = allText.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }
        
        let wordCounts = Dictionary(grouping: words) { $0 }
            .mapValues { $0.count }
        
        return Array(wordCounts.sorted { $0.value > $1.value }.prefix(10).map { $0.key })
    }
    
    private func generateChartData(from results: [SearchResultModel]) -> ChartDataModel {
        // Generate data for charts - timeline, distribution, etc.
        return ChartDataModel(
            timeline: generateTimelineData(from: results),
            distribution: generateDistributionData(from: results),
            trends: generateTrendData(from: results)
        )
    }
    
    private func generateTimelineData(from results: [SearchResultModel]) -> [TimelineDataPoint] {
        let groupedByMonth = Dictionary(grouping: results) { result in
            Calendar.current.dateInterval(of: .month, for: result.video.publishedDate)?.start ?? result.video.publishedDate
        }
        
        return groupedByMonth.map { date, videos in
            TimelineDataPoint(date: date, count: videos.count)
        }.sorted { $0.date < $1.date }
    }
    
    private func generateDistributionData(from results: [SearchResultModel]) -> [DistributionDataPoint] {
        let speakerCounts = Dictionary(grouping: results) { $0.video.speaker ?? "Unknown" }
            .mapValues { $0.count }
        
        return speakerCounts.map { speaker, count in
            DistributionDataPoint(category: speaker, count: count)
        }.sorted { $0.count > $1.count }
    }
    
    private func generateTrendData(from results: [SearchResultModel]) -> [TrendDataPoint] {
        // Generate trend analysis
        return []
    }
    
    private func formatTranscript(_ segments: [TranscriptSegmentModel]?, includeTimestamps: Bool) -> String {
        guard let segments = segments else { return "No transcript available." }
        
        return segments.map { segment in
            if includeTimestamps {
                let timestamp = formatTimestamp(segment.startTime)
                return "[\(timestamp)] \(segment.text)"
            } else {
                return segment.text
            }
        }.joined(separator: "\n")
    }
    
    private func extractMetadata(from video: VideoModel) -> VideoMetadata {
        return VideoMetadata(
            duration: video.duration,
            viewCount: video.viewCount,
            isLive: video.isLive,
            language: video.language,
            tags: video.tags,
            transcriptWordCount: video.transcriptWordCount
        )
    }
    
    private func calculateWordCount(_ segments: [TranscriptSegmentModel]?) -> Int {
        guard let segments = segments else { return 0 }
        return segments.reduce(0) { $0 + $1.text.split(separator: " ").count }
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
    
    private func generateFilename(for videos: [VideoModel], format: ExportFormat) -> String {
        let timestamp = dateFormatter.string(from: Date())
        let prefix = videos.count == 1 ? videos.first?.title.prefix(30) ?? "transcript" : "transcripts"
        return "\(prefix)-\(timestamp).\(format.fileExtension)"
    }
    
    private func saveExportToFile(content: Data, format: ExportFormat, filename: String) async throws -> URL {
        let fileURL = exportCacheDirectory.appendingPathComponent(filename)
        try content.write(to: fileURL)
        return fileURL
    }
    
    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func createExportCacheDirectory() {
        try? fileManager.createDirectory(at: exportCacheDirectory, withIntermediateDirectories: true)
    }
    
    private func loadExportHistory() {
        // Load export history from UserDefaults or file
        if let data = UserDefaults.standard.data(forKey: "ExportHistory"),
           let history = try? JSONDecoder().decode([ExportHistoryModel].self, from: data) {
            self.exportHistory = history
        }
    }
    
    private func updateExportHistory(result: ExportResultModel, videos: [VideoModel]) async {
        let historyItem = ExportHistoryModel(
            id: result.id,
            filename: result.fileURL.lastPathComponent,
            format: result.format,
            itemCount: result.itemCount,
            fileSize: result.fileSize,
            createdAt: result.createdAt,
            videoTitles: videos.prefix(5).map { $0.title }
        )
        
        exportHistory.insert(historyItem, at: 0)
        
        // Keep only last 50 exports
        if exportHistory.count > 50 {
            exportHistory = Array(exportHistory.prefix(50))
        }
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(exportHistory) {
            UserDefaults.standard.set(data, forKey: "ExportHistory")
        }
    }
    
    private func updateProgress(_ progress: Double, message: String) async {
        await MainActor.run {
            self.exportProgress = progress
            print("Export Progress: \(Int(progress * 100))% - \(message)")
        }
    }
    
    // MARK: - Template Methods
    
    private var defaultMarkdownTemplate: String {
        return """
        # Political Transcripts Export
        
        **Export Date:** {{export_date}}
        **Total Videos:** {{video_count}}
        **Total Words:** {{word_count}}
        
        ---
        
        {{content}}
        
        ## Bibliography
        
        {{bibliography}}
        
        ---
        
        *Generated by Political Transcripts App*
        """
    }
    
    // MARK: - Cleanup Methods
    
    /// Cleans up old export files
    func cleanupOldExports() async {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        do {
            let files = try fileManager.contentsOfDirectory(at: exportCacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in files {
                if let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Failed to cleanup old exports: \(error)")
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
}

// MARK: - Data Models

struct ExportResultModel: Identifiable, Codable {
    let id: String
    let fileURL: URL
    let format: ExportFormat
    let itemCount: Int
    let fileSize: Int64
    let citationStyle: CitationStyle
    let createdAt: Date
    let expiresAt: Date
    let metadata: ExportMetadata
}

struct ExportMetadata: Codable {
    let includeMetadata: Bool?
    let includeTimestamps: Bool?
    let includeNotes: Bool?
    let includeCollections: Bool?
    let includeAnalysis: Bool?
    let includeCharts: Bool?
    let customTemplate: Bool?
    let searchQuery: String?
    
    init(
        includeMetadata: Bool? = nil,
        includeTimestamps: Bool? = nil,
        includeNotes: Bool? = nil,
        includeCollections: Bool? = nil,
        includeAnalysis: Bool? = nil,
        includeCharts: Bool? = nil,
        customTemplate: Bool? = nil,
        searchQuery: String? = nil
    ) {
        self.includeMetadata = includeMetadata
        self.includeTimestamps = includeTimestamps
        self.includeNotes = includeNotes
        self.includeCollections = includeCollections
        self.includeAnalysis = includeAnalysis
        self.includeCharts = includeCharts
        self.customTemplate = customTemplate
        self.searchQuery = searchQuery
    }
}

struct ExportHistoryModel: Identifiable, Codable {
    let id: String
    let filename: String
    let format: ExportFormat
    let itemCount: Int
    let fileSize: Int64
    let createdAt: Date
    let videoTitles: [String]
}

struct ExportedItemModel: Identifiable, Codable {
    let id: String
    let title: String
    let type: String
    let size: Int64
    let createdAt: Date
}

struct CitationModel: Identifiable, Codable {
    let id: String
    let videoId: String
    let style: CitationStyle
    let citation: String
    let shortCitation: String
    let createdAt: Date
}

struct VideoExportData: Codable {
    let videos: [ProcessedVideoModel]
    let totalVideos: Int
    let totalWordCount: Int
    let exportDate: Date
}

struct ProcessedVideoModel: Codable {
    let video: VideoModel
    let formattedTranscript: String
    let metadata: VideoMetadata?
    let wordCount: Int
}

struct VideoMetadata: Codable {
    let duration: TimeInterval
    let viewCount: Int?
    let isLive: Bool?
    let language: String?
    let tags: [String]?
    let transcriptWordCount: Int
}

struct SearchAnalysisModel: Codable {
    let query: String
    let totalResults: Int
    let averageRelevanceScore: Double
    let speakerDistribution: [String: Int]
    let sourceDistribution: [String: Int]
    let categoryDistribution: [String: Int]
    let dateRange: DateInterval
    let topKeywords: [String]
    let charts: ChartDataModel?
}

struct ChartDataModel: Codable {
    let timeline: [TimelineDataPoint]
    let distribution: [DistributionDataPoint]
    let trends: [TrendDataPoint]
}

struct TimelineDataPoint: Codable {
    let date: Date
    let count: Int
}

struct DistributionDataPoint: Codable {
    let category: String
    let count: Int
}

struct TrendDataPoint: Codable {
    let date: Date
    let value: Double
    let trend: String
}

enum CitationStyle: String, Codable, CaseIterable {
    case apa = "apa"
    case mla = "mla"
    case chicago = "chicago"
    case harvard = "harvard"
    case ieee = "ieee"
    
    var displayName: String {
        switch self {
        case .apa: return "APA"
        case .mla: return "MLA"
        case .chicago: return "Chicago"
        case .harvard: return "Harvard"
        case .ieee: return "IEEE"
        }
    }
}

enum ExportFormat: String, Codable, CaseIterable {
    case json = "json"
    case csv = "csv"
    case markdown = "md"
    case pdf = "pdf"
    case docx = "docx"
    case html = "html"
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        case .docx: return "Word Document"
        case .html: return "HTML"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
    
    var utType: UTType {
        switch self {
        case .json: return .json
        case .csv: return .commaSeparatedText
        case .markdown: return .plainText
        case .pdf: return .pdf
        case .docx: return UTType("org.openxmlformats.wordprocessingml.document")!
        case .html: return .html
        }
    }
}

// MARK: - Errors

enum ExportError: Error, LocalizedError {
    case noContentToExport
    case tooManyItems
    case fileCreationFailed
    case templateNotFound
    case formatNotSupported
    case insufficientStorage
    
    var errorDescription: String? {
        switch self {
        case .noContentToExport:
            return "No content available to export"
        case .tooManyItems:
            return "Too many items selected for export"
        case .fileCreationFailed:
            return "Failed to create export file"
        case .templateNotFound:
            return "Export template not found"
        case .formatNotSupported:
            return "Export format not supported"
        case .insufficientStorage:
            return "Insufficient storage space for export"
        }
    }
}
