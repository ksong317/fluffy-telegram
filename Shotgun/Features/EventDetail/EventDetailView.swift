import SwiftUI

struct EventDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @State private var viewModel: EventDetailViewModel

    init(event: Event) {
        _viewModel = State(initialValue: EventDetailViewModel(event: event))
    }

    private var userID: UUID? { appState.currentUserID }

    var body: some View {
        List {
            headerSection
            if viewModel.event.moneyType != .free { paymentSection }
            participantsSection
            actionSection
            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle(viewModel.event.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: Sections

    private var headerSection: some View {
        Section {
            LabeledContent("Place", value: viewModel.event.placeText)
            LabeledContent("Leaves", value: viewModel.event.startsAt.formatted(date: .omitted, time: .shortened))
            LabeledContent("Closes", value: viewModel.event.closesAt.formatted(date: .omitted, time: .shortened))
            LabeledContent("Audience", value: viewModel.event.audience.label)
            LabeledContent("Spots left", value: "\(viewModel.spotsRemaining) of \(viewModel.event.capacity)")
            HStack {
                Text("Cost")
                Spacer()
                MoneyPill(moneyType: viewModel.event.moneyType, amount: viewModel.event.amount)
            }
            if let note = viewModel.event.note, !note.isEmpty {
                LabeledContent("Note", value: note)
            }
        } header: {
            Text("Hosted by \(viewModel.hostProfile?.displayName ?? "…")")
        }
    }

    private var paymentSection: some View {
        Section("Payment") {
            if let venmo = viewModel.hostProfile?.venmoHandle, !venmo.isEmpty {
                LabeledContent("Venmo", value: venmo)
                if viewModel.myParticipation(userID) != nil {
                    Button {
                        payWithVenmo(handle: venmo)
                    } label: {
                        Label("Pay with Venmo", systemImage: "dollarsign.circle")
                    }
                }
            } else {
                Text("Host hasn't added a Venmo handle yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var participantsSection: some View {
        Section("Joined (\(viewModel.participants.count))") {
            if viewModel.participants.isEmpty {
                Text("No one yet — be the first.").foregroundStyle(.secondary)
            }
            ForEach(viewModel.participants) { participant in
                HStack {
                    VStack(alignment: .leading) {
                        Text(viewModel.displayName(for: participant.userID))
                        if let note = participant.note, !note.isEmpty {
                            Text(note).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if viewModel.event.moneyType != .free {
                        Image(systemName: participant.paid ? "checkmark.seal.fill" : "circle")
                            .foregroundStyle(participant.paid ? .green : .secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        Section {
            if viewModel.isHost(userID) {
                hostControls
            } else if let mine = viewModel.myParticipation(userID) {
                Toggle("I've paid", isOn: Binding(
                    get: { mine.paid },
                    set: { newValue in Task { await viewModel.setPaid(newValue, participantID: mine.id) } }
                ))
                .disabled(viewModel.event.moneyType == .free)

                AsyncButton(role: .destructive) {
                    await viewModel.leave()
                } label: {
                    Text("Leave")
                }
            } else {
                joinControls
            }
        }
    }

    @ViewBuilder
    private var joinControls: some View {
        if viewModel.event.isActive, !viewModel.isFull {
            TextField("Add a note (e.g. grab oat milk?)", text: $viewModel.joinNote)
            AsyncButton {
                await viewModel.join()
            } label: {
                Text("Join").frame(maxWidth: .infinity)
            }
        } else {
            Text(viewModel.isFull ? "This run is full." : "This run is closed.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var hostControls: some View {
        if viewModel.event.status == .open {
            AsyncButton { await viewModel.close() } label: { Text("Close run early") }
            AsyncButton(role: .destructive) { await viewModel.cancel() } label: { Text("Cancel run") }
        } else {
            Text("This run is \(viewModel.event.status.rawValue).")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Actions

    private func payWithVenmo(handle: String) {
        let note = viewModel.event.title
        if let appURL = VenmoLink.appURL(handle: handle, amount: viewModel.event.amount, note: note) {
            openURL(appURL) { accepted in
                if !accepted, let web = VenmoLink.webURL(handle: handle) {
                    openURL(web)
                }
            }
        }
    }
}
