import SwiftUI
import Combine

struct CollaborationView: View {
    @StateObject private var collaborationService: CollaborationService
    @StateObject private var analyticsService: AnalyticsService
    @State private var selectedDocumentId: String = ""
    @State private var selectedDocumentType: CollaborationDocumentType = .transcript
    @State private var showingSessionCreation = false
    @State private var showingJoinSession = false
    @State private var sessionIdToJoin = ""
    @State private var showingCollaborators = false
    @State private var showingStatistics = false
    @State private var currentCursorPosition: CursorPosition?
    
    // MARK: - Initialization
    init(analyticsService: AnalyticsService) {
        self._analyticsService = StateObject(wrappedValue: analyticsService)
        self._collaborationService = StateObject(wrappedValue: CollaborationService(analyticsService: analyticsService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Collaboration Header
                collaborationHeader
                
                // Connection Status Bar
                connectionStatusBar
                
                // Main Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Active Sessions Section
                        if !collaborationService.collaborationSessions.isEmpty {
                            activeSessionsSection
                        }
                        
                        // Active Collaborators Section
                        if !collaborationService.activeCollaborators.isEmpty {
                            activeCollaboratorsSection
                        }
                        
                        // Recent Updates Section
                        if !collaborationService.realtimeUpdates.isEmpty {
                            recentUpdatesSection
                        }
                        
                        // Quick Actions Section
                        quickActionsSection
                        
                        // Collaboration Statistics
                        statisticsSection
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Collaboration")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showingSessionCreation) {
                SessionCreationView(
                    collaborationService: collaborationService,
                    selectedDocumentType: $selectedDocumentType,
                    selectedDocumentId: $selectedDocumentId
                )
            }
            .sheet(isPresented: $showingJoinSession) {
                JoinSessionView(
                    collaborationService: collaborationService,
                    sessionIdToJoin: $sessionIdToJoin
                )
            }
            .sheet(isPresented: $showingCollaborators) {
                CollaboratorsView(collaborationService: collaborationService)
            }
            .sheet(isPresented: $showingStatistics) {
                StatisticsView(collaborationService: collaborationService)
            }
        }
    }
    
    // MARK: - View Components
    
    private var collaborationHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Real-time Collaboration")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Work together on political transcripts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Collaboration Toggle
                Toggle("Enable", isOn: .constant(collaborationService.isCollaborationEnabled))
                    .labelsHidden()
                    .disabled(collaborationService.connectionStatus != .connected)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: { showingSessionCreation = true }) {
                    Label("Start Session", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(20)
                }
                
                Button(action: { showingJoinSession = true }) {
                    Label("Join Session", systemImage: "person.2.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(20)
                }
                
                Spacer()
                
                Button(action: { showingStatistics = true }) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var connectionStatusBar: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(collaborationService.connectionStatus.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if !collaborationService.activeCollaborators.isEmpty {
                Text("\(collaborationService.activeCollaborators.count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var activeSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "rectangle.3.group.fill")
                    .foregroundColor(.blue)
                Text("Active Sessions")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                Button("View All") {
                    // Navigate to full sessions view
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(collaborationService.collaborationSessions.filter { $0.isActive }) { session in
                    SessionCard(session: session, collaborationService: collaborationService)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, x: 0, y: 1)
    }
    
    private var activeCollaboratorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.green)
                Text("Active Collaborators")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                Button("Show All") {
                    showingCollaborators = true
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(collaborationService.activeCollaborators) { collaborator in
                        CollaboratorCard(collaborator: collaborator)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, x: 0, y: 1)
    }
    
    private var recentUpdatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                Text("Recent Activity")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            LazyVStack(spacing: 8) {
                ForEach(collaborationService.realtimeUpdates.prefix(5), id: \.id) { update in
                    UpdateCard(update: update)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, x: 0, y: 1)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text("Quick Actions")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Share Link",
                    icon: "link",
                    color: .blue
                ) {
                    shareCollaborationLink()
                }
                
                QuickActionButton(
                    title: "Export Session",
                    icon: "square.and.arrow.up",
                    color: .green
                ) {
                    exportCollaborationSession()
                }
                
                QuickActionButton(
                    title: "Invite Users",
                    icon: "person.badge.plus",
                    color: .purple
                ) {
                    inviteCollaborators()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, x: 0, y: 1)
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.pink)
                Text("Collaboration Stats")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                Button("Details") {
                    showingStatistics = true
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            let stats = collaborationService.getCollaborationStatistics()
            
            HStack(spacing: 16) {
                StatisticCard(
                    title: "Active Sessions",
                    value: "\(stats.activeSessions)",
                    icon: "rectangle.3.group",
                    color: .blue
                )
                
                StatisticCard(
                    title: "Collaborators",
                    value: "\(stats.totalCollaborators)",
                    icon: "person.3",
                    color: .green
                )
                
                StatisticCard(
                    title: "Updates (24h)",
                    value: "\(stats.updatesLast24Hours)",
                    icon: "clock",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, x: 0, y: 1)
    }
    
    private var statusColor: Color {
        switch collaborationService.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
}

// MARK: - Helper Methods
private extension CollaborationView {
    
    func shareCollaborationLink() {
        // Implement sharing functionality
        guard let session = collaborationService.collaborationSessions.first(where: { $0.isActive }) else { return }
        
        let shareURL = "polibase://collaborate/join/\(session.id)"
        let activityController = UIActivityViewController(
            activityItems: [shareURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
    
    func exportCollaborationSession() {
        // Implement export functionality
        Task {
            await analyticsService.trackEvent("collaboration_session_export_requested")
        }
    }
    
    func inviteCollaborators() {
        // Implement invitation functionality
        Task {
            await analyticsService.trackEvent("collaboration_invite_requested")
        }
    }
}

// MARK: - Supporting Views

struct SessionCard: View {
    let session: CollaborationSession
    let collaborationService: CollaborationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: documentTypeIcon(session.documentType))
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Spacer()
                
                Text(session.permissions.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Text(session.documentType.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Created \(timeAgo(session.createdAt))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                let collaborators = collaborationService.getActiveCollaborators(for: session.id)
                
                if !collaborators.isEmpty {
                    ForEach(collaborators.prefix(3), id: \.id) { collaborator in
                        Circle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text(String(collaborator.userName.prefix(1)))
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    if collaborators.count > 3 {
                        Text("+\(collaborators.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        try await collaborationService.leaveCollaborationSession(session.id)
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func documentTypeIcon(_ type: CollaborationDocumentType) -> String {
        switch type {
        case .transcript: return "doc.text"
        case .annotation: return "note.text"
        case .bookmark: return "bookmark"
        case .collection: return "folder"
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
}

struct CollaboratorCard: View {
    let collaborator: Collaborator
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.7))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(collaborator.userName.prefix(1)))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
                .overlay(
                    Circle()
                        .fill(collaborator.isActive ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                        .offset(x: 14, y: 14)
                )
            
            VStack(spacing: 2) {
                Text(collaborator.userName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(timeAgo(collaborator.lastSeen))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 70)
        .padding(.vertical, 8)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else {
            return "\(Int(interval / 3600))h"
        }
    }
}

struct UpdateCard: View {
    let update: RealtimeUpdate
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: updateTypeIcon(update.type))
                .foregroundColor(updateTypeColor(update.type))
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(updateTypeDescription(update.type))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let userName = update.userName {
                    Text("by \(userName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let timestamp = update.timestamp {
                Text(timeAgo(timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func updateTypeIcon(_ type: RealtimeUpdate.UpdateType) -> String {
        switch type {
        case .cursorPosition: return "cursor.rays"
        case .textEdit: return "pencil"
        case .annotation: return "note.text"
        case .presence: return "person.circle"
        case .selection: return "selection.pin.in.out"
        }
    }
    
    private func updateTypeColor(_ type: RealtimeUpdate.UpdateType) -> Color {
        switch type {
        case .cursorPosition: return .blue
        case .textEdit: return .green
        case .annotation: return .purple
        case .presence: return .orange
        case .selection: return .pink
        }
    }
    
    private func updateTypeDescription(_ type: RealtimeUpdate.UpdateType) -> String {
        switch type {
        case .cursorPosition: return "Cursor moved"
        case .textEdit: return "Text edited"
        case .annotation: return "Annotation added"
        case .presence: return "User joined"
        case .selection: return "Text selected"
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Sheet Views

struct SessionCreationView: View {
    let collaborationService: CollaborationService
    @Binding var selectedDocumentType: CollaborationDocumentType
    @Binding var selectedDocumentId: String
    @Environment(\.dismiss) private var dismiss
    @State private var permissions: CollaborationPermissions = .readWrite
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Document") {
                    Picker("Type", selection: $selectedDocumentType) {
                        ForEach(CollaborationDocumentType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    TextField("Document ID", text: $selectedDocumentId)
                        .textContentType(.none)
                }
                
                Section("Permissions") {
                    Picker("Default Permissions", selection: $permissions) {
                        ForEach(CollaborationPermissions.allCases, id: \.self) { permission in
                            Text(permission.displayName).tag(permission)
                        }
                    }
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Create") { createSession() }
                    .disabled(selectedDocumentId.isEmpty || isCreating)
            )
        }
    }
    
    private func createSession() {
        guard !selectedDocumentId.isEmpty else { return }
        
        isCreating = true
        
        Task {
            do {
                _ = try await collaborationService.startCollaborationSession(
                    documentId: selectedDocumentId,
                    documentType: selectedDocumentType,
                    permissions: permissions
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to create session: \(error)")
            }
            
            await MainActor.run {
                isCreating = false
            }
        }
    }
}

struct JoinSessionView: View {
    let collaborationService: CollaborationService
    @Binding var sessionIdToJoin: String
    @Environment(\.dismiss) private var dismiss
    @State private var isJoining = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Session") {
                    TextField("Session ID", text: $sessionIdToJoin)
                        .textContentType(.none)
                        .autocapitalization(.none)
                }
                
                Section {
                    Text("Enter the session ID provided by the session creator to join an active collaboration.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Join Session")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Join") { joinSession() }
                    .disabled(sessionIdToJoin.isEmpty || isJoining)
            )
        }
    }
    
    private func joinSession() {
        guard !sessionIdToJoin.isEmpty else { return }
        
        isJoining = true
        
        Task {
            do {
                try await collaborationService.joinCollaborationSession(sessionIdToJoin)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to join session: \(error)")
            }
            
            await MainActor.run {
                isJoining = false
            }
        }
    }
}

struct CollaboratorsView: View {
    let collaborationService: CollaborationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(collaborationService.activeCollaborators) { collaborator in
                    CollaboratorRow(collaborator: collaborator)
                }
            }
            .navigationTitle("Collaborators")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct CollaboratorRow: View {
    let collaborator: Collaborator
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.7))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(collaborator.userName.prefix(1)))
                        .font(.subheadline)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(collaborator.userName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Last seen \(timeAgo(collaborator.lastSeen))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Circle()
                .fill(collaborator.isActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60)) minutes ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600)) hours ago"
        } else {
            return "\(Int(interval / 86400)) days ago"
        }
    }
}

struct StatisticsView: View {
    let collaborationService: CollaborationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                let stats = collaborationService.getCollaborationStatistics()
                
                LazyVStack(spacing: 16) {
                    StatisticDetailCard(
                        title: "Active Sessions",
                        value: "\(stats.activeSessions)",
                        description: "Currently running collaboration sessions",
                        icon: "rectangle.3.group.fill",
                        color: .blue
                    )
                    
                    StatisticDetailCard(
                        title: "Total Collaborators",
                        value: "\(stats.totalCollaborators)",
                        description: "Users participating in active sessions",
                        icon: "person.3.fill",
                        color: .green
                    )
                    
                    StatisticDetailCard(
                        title: "Recent Updates",
                        value: "\(stats.updatesLast24Hours)",
                        description: "Real-time updates in the last 24 hours",
                        icon: "clock.arrow.circlepath",
                        color: .orange
                    )
                    
                    StatisticDetailCard(
                        title: "Average Session",
                        value: formatDuration(stats.averageSessionDuration),
                        description: "Average duration of completed sessions",
                        icon: "timer",
                        color: .purple
                    )
                    
                    StatisticDetailCard(
                        title: "Conflicts Resolved",
                        value: "\(stats.conflictsResolved)",
                        description: "Edit conflicts automatically resolved",
                        icon: "checkmark.shield.fill",
                        color: .pink
                    )
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "\(Int(duration))s"
        } else if duration < 3600 {
            return "\(Int(duration / 60))m"
        } else {
            return "\(Int(duration / 3600))h"
        }
    }
}

struct StatisticDetailCard: View {
    let title: String
    let value: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview
#Preview {
    CollaborationView(analyticsService: AnalyticsService())
}
