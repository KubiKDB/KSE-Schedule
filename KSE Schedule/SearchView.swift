import SwiftUI

struct SearchView: View {
    @StateObject var viewModel: ScheduleViewModel
    @Binding var groups: [Group]
    @State private var searchText = ""
    
    var filteredGroups: [Group] {
            if searchText.isEmpty {
                return groups
            } else {
                return groups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
    }
    
    struct Group: Hashable, Comparable {
        var name: String
        var id: Int
        
        static func < (lhs: Group, rhs: Group) -> Bool {
                lhs.name < rhs.name
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredGroups.sorted(), id:\.self) { group in
                    Button {
                        if viewModel.groupIDs.contains(group.id) {
                            viewModel.groupIDs.removeAll { $0 == group.id }
                        } else {
                            viewModel.groupIDs.append(group.id)
                        }
                        viewModel.fetchSchedule()
                    } label: {
                        Label(group.name, systemImage: viewModel.groupIDs.contains(group.id) ? "minus" : "plus")
                            .foregroundStyle(viewModel.groupIDs.contains(group.id) ? .red : .blue)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search groups...")
            .navigationTitle("Groups")
            .onAppear {
                
            }
        }
    }
}
