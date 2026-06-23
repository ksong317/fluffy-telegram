import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showingCreate = false
    @State private var showingAccount = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.events.isEmpty, !viewModel.isLoading {
                    ContentUnavailableView(
                        "Nothing happening yet",
                        systemImage: "figure.walk",
                        description: Text("When a friend posts a run, it shows up here. Tap + to start one.")
                    )
                } else {
                    List(viewModel.events) { event in
                        NavigationLink(value: event) {
                            EventCardView(event: event, hostName: viewModel.hostName(for: event))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Feed")
            .navigationDestination(for: Event.self) { event in
                EventDetailView(event: event)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingAccount = true } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCreate = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .sheet(isPresented: $showingCreate, onDismiss: { Task { await viewModel.load() } }) {
                CreateEventView()
            }
            .sheet(isPresented: $showingAccount) {
                AccountView()
            }
            .overlay {
                if viewModel.isLoading, viewModel.events.isEmpty {
                    ProgressView()
                }
            }
        }
    }
}
