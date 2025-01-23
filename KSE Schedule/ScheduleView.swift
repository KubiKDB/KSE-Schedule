import SwiftUI

struct ScheduleView: View {
    @StateObject var viewModel = ScheduleViewModel()
    @State public var groups: [SearchView.Group] = []
    @State private var showSelection: Bool = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.groupIDs.count > 20 {
                    Text("Too many groups selected")
                } else if viewModel.isLoading {
                    ProgressView("Fetching Schedule...")
                        .padding()
                } else {
                    List(viewModel.scheduleEntries, id: \.0) { day_tuple in
                        VStack(alignment: .leading) {
                            Text(day_tuple.0)
                                .font(.largeTitle)
                                .bold()
                                .padding(.top, 10)
                                .foregroundStyle(.blue)
                            
                            ForEach(day_tuple.1, id: \.id) { event in
                                VStack(alignment: .leading) {
                                    Text(event.title)
                                        .font(.headline)
                                    Text(event.location)
                                        .font(.subheadline)
                                    Text(event.desc)
                                        .font(.subheadline)
                                    Text("\(formatDate(event.startDate)) - \(formatDate(event.endDate))")
                                        .font(.subheadline)
                                        .foregroundStyle(.gray)
                                }
                                .padding(5)
                            }
                        }
                    }
                }
            }
            .navigationTitle("KSE Schedule")
            .toolbar {
                Button("Groups") {
                    showSelection = true
                }
            }
            .onAppear {
                if let filePath = Bundle.main.path(forResource: "Groups", ofType: "txt")
                {
                    for group_pair in viewModel.parseGroups(from: filePath) ?? []
                    {
                        let group = SearchView.Group(name: group_pair.1, id: group_pair.0)
                        groups.append(group)
                    }
                }
                viewModel.fetchSchedule()
            }
            .sheet(isPresented: $showSelection) {
                SearchView(
                    viewModel: viewModel,
                    groups: $groups
                )
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
#Preview {
    ScheduleView()
}
