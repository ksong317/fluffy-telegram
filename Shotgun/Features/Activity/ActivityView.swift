import SwiftUI

struct ActivityView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ActivityViewModel()

    private var me: UUID? { appState.currentUserID }

    var body: some View {
        NavigationStack {
            List {
                Section("Hosted by you") {
                    if viewModel.hosted.isEmpty {
                        Text("You haven't hosted anything yet.").foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.hosted) { event in
                        NavigationLink(value: event) { row(event) }
                    }
                }

                Section("You joined") {
                    if viewModel.joined.isEmpty {
                        Text("You haven't joined anything yet.").foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.joined) { event in
                        NavigationLink(value: event) { row(event) }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Activity")
            .navigationDestination(for: Event.self) { EventDetailView(event: $0) }
            .refreshable { if let me { await viewModel.load(me: me) } }
            .task { if let me { await viewModel.load(me: me) } }
        }
    }

    private func row(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(event.title).font(.headline)
                Spacer()
                Text(event.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(event.startsAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
