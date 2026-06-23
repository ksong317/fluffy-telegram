import SwiftUI

struct FriendsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = FriendsViewModel()

    private var me: UUID? { appState.currentUserID }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.searchText.isEmpty {
                    requestsSection
                    friendsSection
                } else {
                    searchSection
                }

                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Friends")
            .searchable(text: $viewModel.searchText, prompt: "Find by name or Venmo")
            .onChange(of: viewModel.searchText) { _, _ in
                guard let me else { return }
                Task { await viewModel.search(me: me) }
            }
            .refreshable { if let me { await viewModel.load(me: me) } }
            .task { if let me { await viewModel.load(me: me) } }
        }
    }

    @ViewBuilder
    private var requestsSection: some View {
        if !viewModel.incoming.isEmpty {
            Section("Requests") {
                ForEach(viewModel.incoming, id: \.friendship.id) { item in
                    HStack {
                        Text(item.profile.displayName)
                        Spacer()
                        AsyncButton {
                            if let me { await viewModel.accept(item.friendship, me: me) }
                        } label: {
                            Text("Accept")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        AsyncButton(role: .destructive) {
                            if let me { await viewModel.remove(otherID: item.profile.id, me: me) }
                        } label: {
                            Text("Decline")
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var friendsSection: some View {
        Section("Your friends") {
            if viewModel.friends.isEmpty {
                Text("No friends yet — search to add some.").foregroundStyle(.secondary)
            }
            ForEach(viewModel.friends) { friend in
                HStack {
                    Button {
                        if let me { Task { await viewModel.toggleClose(friend: friend.id, me: me) } }
                    } label: {
                        Image(systemName: viewModel.isClose(friend.id) ? "star.fill" : "star")
                            .foregroundStyle(viewModel.isClose(friend.id) ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)

                    Text(friend.displayName)
                    Spacer()
                }
                .swipeActions {
                    Button(role: .destructive) {
                        if let me { Task { await viewModel.remove(otherID: friend.id, me: me) } }
                    } label: {
                        Label("Remove", systemImage: "person.badge.minus")
                    }
                }
            }
        }

        if !viewModel.outgoing.isEmpty {
            Section("Sent requests") {
                ForEach(viewModel.outgoing, id: \.friendship.id) { item in
                    Text(item.profile.displayName).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var searchSection: some View {
        Section("Results") {
            if viewModel.searchResults.isEmpty {
                Text("No matches.").foregroundStyle(.secondary)
            }
            ForEach(viewModel.searchResults) { profile in
                HStack {
                    Text(profile.displayName)
                    Spacer()
                    if viewModel.hasRelationship(with: profile.id) {
                        Text("Pending / added").font(.caption).foregroundStyle(.secondary)
                    } else {
                        AsyncButton {
                            if let me { await viewModel.sendRequest(me: me, to: profile.id) }
                        } label: {
                            Text("Add")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}
