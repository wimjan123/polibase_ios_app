import SwiftUI
import Combine

struct RealtimeCollaborationToolbar: View {
    @ObservedObject var collaborationService: CollaborationService
    let documentId: String
    let documentType: CollaborationDocumentType
    
    @State private var showingCollaborators = false
    @State private var showingInvite = false
    @State private var cursorPositions: [String: CursorPosition] = [:]
    @State private var userSelections: [String: TextSelection] = [:]
    
    var body: some View {
        HStack(spacing: 12) {
            // Connection Status Indicator
            connectionIndicator
            
            // Active Collaborators
            if !collaborationService.activeCollaborators.isEmpty {
                collaboratorsIndicator
            }
            
            // Real-time Activity Indicator
            if hasRecentActivity {
                activityIndicator
            }
            
            Spacer()
            
            // Collaboration Actions
            collaborationActions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
                .offset(y: -0.25),
            alignment: .top
        )
        .sheet(isPresented: $showingCollaborators) {
            ActiveCollaboratorsSheet(collaborationService: collaborationService)
        }
        .sheet(isPresented: $showingInvite) {
            InviteCollaboratorsSheet(
                documentId: documentId,
                documentType: documentType,
                collaborationService: collaborationService
            )
        }
        .onReceive(collaborationService.$realtimeUpdates) { updates in
            processRealtimeUpdates(updates)
        }
    }
    
    // MARK: - View Components
    
    private var connectionIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
            
            if collaborationService.connectionStatus.isConnected {
                Image(systemName: "wifi")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var collaboratorsIndicator: some View {
        Button(action: { showingCollaborators = true }) {
            HStack(spacing: -8) {
                ForEach(Array(collaborationService.activeCollaborators.prefix(3).enumerated()), id: \.element.id) { index, collaborator in
                    CollaboratorAvatar(
                        collaborator: collaborator,
                        size: 24,
                        showStatus: false
                    )
                    .zIndex(Double(3 - index))
                }
                
                if collaborationService.activeCollaborators.count > 3 {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray3))
                            .frame(width: 24, height: 24)
                        
                        Text("+\(collaborationService.activeCollaborators.count - 3)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var activityIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .opacity(hasRecentActivity ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: hasRecentActivity)
            
            Text("Live")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
    }
    
    private var collaborationActions: some View {
        HStack(spacing: 8) {
            // Invite Button
            Button(action: { showingInvite = true }) {
                Image(systemName: "person.badge.plus")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
            }
            .disabled(!collaborationService.isCollaborationEnabled)
            
            // Share Button
            Button(action: shareDocument) {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            }
            .disabled(!collaborationService.isCollaborationEnabled)
            
            // Settings Button
            Menu {
                Button("Leave Session", action: leaveSession)
                Button("Export Activity", action: exportActivity)
                Divider()
                Button("Collaboration Settings", action: openSettings)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(6)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
        }
    }
    
    private var connectionColor: Color {
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
    
    private var hasRecentActivity: Bool {
        let fiveSecondsAgo = Date().addingTimeInterval(-5)
        return collaborationService.realtimeUpdates.contains { update in
            (update.timestamp ?? Date.distantPast) > fiveSecondsAgo
        }
    }
}

// MARK: - Helper Methods
private extension RealtimeCollaborationToolbar {
    
    func processRealtimeUpdates(_ updates: [RealtimeUpdate]) {
        for update in updates {
            switch update.type {
            case .cursorPosition:
                if let userId = update.userId,
                   let positionData = update.data["position"] as? [String: Any] {
                    cursorPositions[userId] = CursorPosition.fromDictionary(positionData)
                }
            case .selection:
                if let userId = update.userId,
                   let selectionData = update.data["selection"] as? [String: Any] {
                    userSelections[userId] = TextSelection.fromDictionary(selectionData)
                }
            default:
                break
            }
        }
    }
    
    func shareDocument() {
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
    
    func leaveSession() {
        Task {
            if let activeSession = collaborationService.collaborationSessions.first(where: { $0.isActive }) {
                try await collaborationService.leaveCollaborationSession(activeSession.id)
            }
        }
    }
    
    func exportActivity() {
        // Implement activity export
    }
    
    func openSettings() {
        // Implement settings
    }
}

// MARK: - Supporting Views

struct CollaboratorAvatar: View {
    let collaborator: Collaborator
    let size: CGFloat
    let showStatus: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor)
                .frame(width: size, height: size)
            
            Text(String(collaborator.userName.prefix(1)))
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
            
            if showStatus {
                Circle()
                    .fill(collaborator.isActive ? Color.green : Color.gray)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .offset(x: size * 0.35, y: size * 0.35)
            }
        }
    }
    
    private var avatarColor: Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .red]
        let index = abs(collaborator.userId.hashValue) % colors.count
        return colors[index]
    }
}

struct ActiveCollaboratorsSheet: View {
    @ObservedObject var collaborationService: CollaborationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Active Collaborators") {
                    ForEach(collaborationService.activeCollaborators) { collaborator in
                        CollaboratorDetailRow(collaborator: collaborator)
                    }
                }
                
                if !collaborationService.realtimeUpdates.isEmpty {
                    Section("Recent Activity") {
                        ForEach(collaborationService.realtimeUpdates.prefix(10), id: \.id) { update in
                            ActivityRow(update: update)
                        }
                    }
                }
            }
            .navigationTitle("Collaboration")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct CollaboratorDetailRow: View {
    let collaborator: Collaborator
    
    var body: some View {
        HStack(spacing: 12) {
            CollaboratorAvatar(
                collaborator: collaborator,
                size: 40,
                showStatus: true
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(collaborator.userName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Joined \(timeAgo(collaborator.joinedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let location = collaborator.currentLocation {
                    Text("In \(location.documentSection ?? "document")")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(collaborator.isActive ? "Active" : "Away")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(collaborator.isActive ? .green : .gray)
                
                Text("Last seen \(timeAgo(collaborator.lastSeen))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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

struct ActivityRow: View {
    let update: RealtimeUpdate
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activityIcon(update.type))
                .foregroundColor(activityColor(update.type))
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activityDescription(update.type))
                    .font(.subheadline)
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
        .padding(.vertical, 2)
    }
    
    private func activityIcon(_ type: RealtimeUpdate.UpdateType) -> String {
        switch type {
        case .cursorPosition: return "cursor.rays"
        case .textEdit: return "pencil"
        case .annotation: return "note.text"
        case .presence: return "person.circle"
        case .selection: return "selection.pin.in.out"
        }
    }
    
    private func activityColor(_ type: RealtimeUpdate.UpdateType) -> Color {
        switch type {
        case .cursorPosition: return .blue
        case .textEdit: return .green
        case .annotation: return .purple
        case .presence: return .orange
        case .selection: return .pink
        }
    }
    
    private func activityDescription(_ type: RealtimeUpdate.UpdateType) -> String {
        switch type {
        case .cursorPosition: return "Moved cursor"
        case .textEdit: return "Edited text"
        case .annotation: return "Added annotation"
        case .presence: return "Joined session"
        case .selection: return "Selected text"
        }
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

struct InviteCollaboratorsSheet: View {
    let documentId: String
    let documentType: CollaborationDocumentType
    @ObservedObject var collaborationService: CollaborationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var inviteEmail = ""
    @State private var invitePermissions: CollaborationPermissions = .readWrite
    @State private var shareableLink = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Invite by Email") {
                    TextField("Email address", text: $inviteEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    Picker("Permissions", selection: $invitePermissions) {
                        ForEach(CollaborationPermissions.allCases, id: \.self) { permission in
                            Text(permission.displayName).tag(permission)
                        }
                    }
                    
                    Button("Send Invite") {
                        sendEmailInvite()
                    }
                    .disabled(inviteEmail.isEmpty)
                }
                
                Section("Share Link") {
                    HStack {
                        Text(shareableLink.isEmpty ? "Generating link..." : shareableLink)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if !shareableLink.isEmpty {
                            Button("Copy") {
                                UIPasteboard.general.string = shareableLink
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    Button("Share Link") {
                        shareInviteLink()
                    }
                    .disabled(shareableLink.isEmpty)
                }
                
                Section {
                    Text("Collaborators will be able to \(invitePermissions.displayName.lowercased()) this \(documentType.displayName.lowercased()).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Invite Collaborators")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Done") { dismiss() }
            )
            .onAppear {
                generateShareableLink()
            }
        }
    }
    
    private func sendEmailInvite() {
        // Implement email invitation
        Task {
            // In a real app, this would send an email invitation
            await collaborationService.analyticsService.trackEvent("collaboration_email_invite_sent", parameters: [
                "document_id": documentId,
                "document_type": documentType.rawValue,
                "permissions": invitePermissions.rawValue
            ])
        }
    }
    
    private func generateShareableLink() {
        // Generate a shareable link for the collaboration session
        if let activeSession = collaborationService.collaborationSessions.first(where: { $0.isActive }) {
            shareableLink = "https://polibase.app/collaborate/join/\(activeSession.id)"
        }
    }
    
    private func shareInviteLink() {
        let activityController = UIActivityViewController(
            activityItems: [shareableLink],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
}

// MARK: - Supporting Models

struct TextSelection: Codable, Equatable {
    let startPosition: Int
    let endPosition: Int
    let selectedText: String
    let documentId: String
    let timestamp: Date
    
    func toDictionary() -> [String: Any] {
        return [
            "startPosition": startPosition,
            "endPosition": endPosition,
            "selectedText": selectedText,
            "documentId": documentId,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> TextSelection {
        return TextSelection(
            startPosition: dict["startPosition"] as? Int ?? 0,
            endPosition: dict["endPosition"] as? Int ?? 0,
            selectedText: dict["selectedText"] as? String ?? "",
            documentId: dict["documentId"] as? String ?? "",
            timestamp: Date(timeIntervalSince1970: dict["timestamp"] as? TimeInterval ?? 0)
        )
    }
}

// MARK: - Preview
#Preview {
    RealtimeCollaborationToolbar(
        collaborationService: CollaborationService(analyticsService: AnalyticsService()),
        documentId: "sample-document",
        documentType: .transcript
    )
}
