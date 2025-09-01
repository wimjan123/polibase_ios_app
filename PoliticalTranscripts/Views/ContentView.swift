import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var navigationState = NavigationState()
    
    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                // iPhone layout with NavigationStack
                NavigationStack(path: $navigationState.path) {
                    MainContentView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            } else {
                // iPad layout with NavigationSplitView
                NavigationSplitView {
                    SidebarView()
                        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
                } content: {
                    if navigationState.selectedSidebarItem != nil {
                        ContentListView()
                            .navigationSplitViewColumnWidth(min: 300, ideal: 350)
                    } else {
                        EmptyContentView()
                    }
                } detail: {
                    DetailView()
                        .navigationSplitViewColumnWidth(min: 400, ideal: 600)
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .environmentObject(navigationState)
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .search:
            Text("Search View")
                .navigationTitle("Search")
        case .videoDetail(let video):
            Text("Video Detail: \(video.title)")
                .navigationTitle("Video Details")
        case .playlist(let playlist):
            Text("Playlist: \(playlist.name)")
                .navigationTitle("Playlist")
        case .settings:
            Text("Settings View")
                .navigationTitle("Settings")
        }
    }
}

// MARK: - Navigation State
class NavigationState: ObservableObject {
    @Published var path = NavigationPath()
    @Published var selectedSidebarItem: SidebarItem?
    @Published var selectedVideo: VideoModel?
    @Published var selectedPlaylist: PlaylistModel?
    
    func navigate(to destination: NavigationDestination) {
        path.append(destination)
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
}

// MARK: - Sidebar Items
enum SidebarItem: String, CaseIterable, Identifiable {
    case search = "Search"
    case videos = "Videos"  
    case playlists = "Playlists"
    case history = "History"
    case favorites = "Favorites"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .videos: return "play.rectangle"
        case .playlists: return "list.bullet.rectangle"
        case .history: return "clock"
        case .favorites: return "heart"
        }
    }
}

// MARK: - Main Content View
struct MainContentView: View {
    @EnvironmentObject private var navigationState: NavigationState
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "video.and.waveform")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
            
            VStack(spacing: 16) {
                Text("Political Transcripts")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Browse and search political video transcripts with advanced filtering and playlist management")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                NavigationButton(
                    title: "Search Transcripts",
                    icon: "magnifyingglass",
                    action: { navigationState.navigate(to: .search) }
                )
                
                NavigationButton(
                    title: "Browse Videos",
                    icon: "play.rectangle",
                    action: { /* Handle browse videos */ }
                )
                
                NavigationButton(
                    title: "My Playlists",
                    icon: "list.bullet.rectangle",
                    action: { /* Handle playlists */ }
                )
            }
        }
        .padding()
        .navigationTitle("Political Transcripts")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @EnvironmentObject private var navigationState: NavigationState
    
    var body: some View {
        List(SidebarItem.allCases, selection: $navigationState.selectedSidebarItem) { item in
            NavigationLink(value: item) {
                Label(item.rawValue, systemImage: item.icon)
            }
        }
        .navigationTitle("Browse")
        .listStyle(.sidebar)
    }
}

// MARK: - Content List View
struct ContentListView: View {
    @EnvironmentObject private var navigationState: NavigationState
    
    var body: some View {
        Group {
            if let selectedItem = navigationState.selectedSidebarItem {
                switch selectedItem {
                case .search:
                    Text("Search Content")
                case .videos:
                    Text("Videos List")
                case .playlists:
                    Text("Playlists List")
                case .history:
                    Text("Search History")
                case .favorites:
                    Text("Favorite Videos")
                }
            } else {
                EmptyContentView()
            }
        }
        .navigationTitle(navigationState.selectedSidebarItem?.rawValue ?? "")
    }
}

// MARK: - Detail View
struct DetailView: View {
    @EnvironmentObject private var navigationState: NavigationState
    
    var body: some View {
        if let selectedVideo = navigationState.selectedVideo {
            Text("Video Detail: \(selectedVideo.title)")
                .navigationTitle("Video Details")
        } else if let selectedPlaylist = navigationState.selectedPlaylist {
            Text("Playlist Detail: \(selectedPlaylist.name)")
                .navigationTitle("Playlist Details")
        } else {
            EmptyDetailView()
        }
    }
}

// MARK: - Empty Views
struct EmptyContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Select an item from the sidebar")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.and.waveform")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Select a video or playlist to view details")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Navigation Button
struct NavigationButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
