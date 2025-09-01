import SwiftUI
import Combine

/// Service container managing all app services with proper dependency injection
@MainActor
class ServiceContainer: ObservableObject {
    
    // MARK: - Core Services
    @Published var analyticsService: AnalyticsService
    @Published var smartSearchService: SmartSearchService
    @Published var personalizationEngine: PersonalizationEngine
    @Published var bookmarkService: BookmarkService
    @Published var annotationService: AnnotationService
    @Published var exportService: ExportService
    @Published var collaborationService: CollaborationService
    @Published var advancedSearchIntelligence: AdvancedSearchIntelligence
    @Published var queryOptimizationEngine: QueryOptimizationEngine
    @Published var analyticsDashboardService: AnalyticsDashboardService
    
    // MARK: - Service State
    @Published var isInitialized = false
    @Published var initializationError: Error?
    
    // MARK: - Initialization
    init() {
        // Initialize core services first
        self.analyticsService = AnalyticsService()
        
        // Initialize services with dependencies
        self.smartSearchService = SmartSearchService(analyticsService: analyticsService)
        self.personalizationEngine = PersonalizationEngine(analyticsService: analyticsService)
        self.bookmarkService = BookmarkService(analyticsService: analyticsService)
        self.annotationService = AnnotationService(analyticsService: analyticsService)
        self.exportService = ExportService(analyticsService: analyticsService)
        self.collaborationService = CollaborationService(analyticsService: analyticsService)
        
        // Initialize advanced services
        self.advancedSearchIntelligence = AdvancedSearchIntelligence(
            smartSearchService: smartSearchService,
            analyticsService: analyticsService,
            personalizationEngine: personalizationEngine
        )
        
        self.queryOptimizationEngine = QueryOptimizationEngine(analyticsService: analyticsService)
        
        self.analyticsDashboardService = AnalyticsDashboardService(
            analyticsService: analyticsService,
            collaborationService: collaborationService,
            smartSearchService: smartSearchService,
            personalizationEngine: personalizationEngine
        )
        
        // Start initialization
        Task {
            await initializeServices()
        }
    }
    
    // MARK: - Service Initialization
    func initializeServices() async {
        do {
            // Initialize all services in proper order
            await analyticsService.initialize()
            await smartSearchService.initialize()
            await personalizationEngine.initialize()
            await bookmarkService.initialize()
            await annotationService.initialize()
            await exportService.initialize()
            await collaborationService.initialize()
            await advancedSearchIntelligence.initialize()
            await queryOptimizationEngine.initialize()
            
            // Mark as initialized
            await MainActor.run {
                self.isInitialized = true
            }
            
            print("✅ All services initialized successfully")
            
        } catch {
            await MainActor.run {
                self.initializationError = error
            }
            print("❌ Service initialization failed: \(error)")
        }
    }
    
    // MARK: - Service Access Methods
    func getAnalyticsService() -> AnalyticsService {
        return analyticsService
    }
    
    func getSmartSearchService() -> SmartSearchService {
        return smartSearchService
    }
    
    func getPersonalizationEngine() -> PersonalizationEngine {
        return personalizationEngine
    }
    
    func getBookmarkService() -> BookmarkService {
        return bookmarkService
    }
    
    func getAnnotationService() -> AnnotationService {
        return annotationService
    }
    
    func getExportService() -> ExportService {
        return exportService
    }
    
    func getCollaborationService() -> CollaborationService {
        return collaborationService
    }
    
    func getAdvancedSearchIntelligence() -> AdvancedSearchIntelligence {
        return advancedSearchIntelligence
    }
    
    func getQueryOptimizationEngine() -> QueryOptimizationEngine {
        return queryOptimizationEngine
    }
    
    func getAnalyticsDashboardService() -> AnalyticsDashboardService {
        return analyticsDashboardService
    }
    
    // MARK: - Cleanup
    deinit {
        // Cleanup services if needed
        Task {
            await collaborationService.cleanup()
            await analyticsService.cleanup()
        }
    }
}

// MARK: - Service Extensions with Initialize Methods
extension AnalyticsService {
    func initialize() async {
        // Initialize analytics service
        await startEventProcessing()
        print("📊 AnalyticsService initialized")
    }
    
    func cleanup() async {
        // Cleanup analytics service
        print("🧹 AnalyticsService cleaned up")
    }
}

extension SmartSearchService {
    func initialize() async {
        // Initialize search service
        print("🔍 SmartSearchService initialized")
    }
}

extension PersonalizationEngine {
    func initialize() async {
        // Initialize personalization engine
        print("🎯 PersonalizationEngine initialized")
    }
}

extension BookmarkService {
    func initialize() async {
        // Initialize bookmark service
        print("🔖 BookmarkService initialized")
    }
}

extension AnnotationService {
    func initialize() async {
        // Initialize annotation service
        print("📝 AnnotationService initialized")
    }
}

extension ExportService {
    func initialize() async {
        // Initialize export service
        print("📤 ExportService initialized")
    }
}

extension CollaborationService {
    func initialize() async {
        // Initialize collaboration service
        print("👥 CollaborationService initialized")
    }
    
    func cleanup() async {
        // Cleanup collaboration service
        await disconnectFromCollaboration()
        print("🧹 CollaborationService cleaned up")
    }
}

extension AdvancedSearchIntelligence {
    func initialize() async {
        // Initialize advanced search intelligence
        print("🧠 AdvancedSearchIntelligence initialized")
    }
}

extension QueryOptimizationEngine {
    func initialize() async {
        // Initialize query optimization engine
        print("⚡ QueryOptimizationEngine initialized")
    }
}
