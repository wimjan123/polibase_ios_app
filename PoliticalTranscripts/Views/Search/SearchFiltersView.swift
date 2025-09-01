import SwiftUI

struct SearchFiltersView: View {
    @Binding var filters: SearchFilterModel
    @Environment(\.dismiss) private var dismiss
    @State private var tempFilters: SearchFilterModel
    
    init(filters: Binding<SearchFilterModel>) {
        self._filters = filters
        self._tempFilters = State(initialValue: filters.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Speakers") {
                    ForEach(availableSpeakers, id: \.self) { speaker in
                        HStack {
                            Text(speaker)
                            Spacer()
                            if tempFilters.speakers.contains(speaker) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if tempFilters.speakers.contains(speaker) {
                                tempFilters.speakers.removeAll { $0 == speaker }
                            } else {
                                tempFilters.speakers.append(speaker)
                            }
                        }
                    }
                }
                
                Section("Sources") {
                    ForEach(availableSources, id: \.self) { source in
                        HStack {
                            Text(source)
                            Spacer()
                            if tempFilters.sources.contains(source) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if tempFilters.sources.contains(source) {
                                tempFilters.sources.removeAll { $0 == source }
                            } else {
                                tempFilters.sources.append(source)
                            }
                        }
                    }
                }
                
                Section("Categories") {
                    ForEach(availableCategories, id: \.self) { category in
                        HStack {
                            Text(category)
                            Spacer()
                            if tempFilters.categories.contains(category) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if tempFilters.categories.contains(category) {
                                tempFilters.categories.removeAll { $0 == category }
                            } else {
                                tempFilters.categories.append(category)
                            }
                        }
                    }
                }
                
                Section("Language") {
                    ForEach(availableLanguages, id: \.self) { language in
                        HStack {
                            Text(language)
                            Spacer()
                            if tempFilters.language == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if tempFilters.language == language {
                                tempFilters.language = nil
                            } else {
                                tempFilters.language = language
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Results")
            .navigationBarItems(
                leading: Button("Reset") { 
                    tempFilters = SearchFilterModel()
                },
                trailing: Button("Apply") { 
                    filters = tempFilters
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - Data Sources
    private var availableSpeakers: [String] {
        [
            "President Biden",
            "Speaker McCarthy",
            "Senator Schumer",
            "Representative Pelosi",
            "Governor DeSantis"
        ]
    }
    
    private var availableSources: [String] {
        [
            "House Committee",
            "Senate Committee", 
            "White House",
            "Press Conference",
            "Floor Speech"
        ]
    }
    
    private var availableCategories: [String] {
        [
            "Healthcare",
            "Economy", 
            "Foreign Policy",
            "Environment",
            "Education"
        ]
    }
    
    private var availableLanguages: [String] {
        [
            "English",
            "Spanish",
            "French"
        ]
    }
}

#Preview {
    SearchFiltersView(filters: .constant(SearchFilterModel()))
}
