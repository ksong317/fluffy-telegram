import SwiftUI

struct CreateEventView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CreateEventViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    TextField("e.g. Trader Joe's run", text: $viewModel.title)
                    TextField("Place (e.g. Trader Joe's on 5th)", text: $viewModel.placeText)
                }

                Section("When") {
                    DatePicker("Leaving", selection: $viewModel.startsAt)
                    DatePicker("Closes", selection: $viewModel.closesAt)
                }

                Section("Who & how many") {
                    Stepper("Capacity: \(viewModel.capacity)", value: $viewModel.capacity, in: 1...20)
                    Picker("Audience", selection: $viewModel.audience) {
                        ForEach(EventAudience.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section("Money") {
                    Picker("Type", selection: $viewModel.moneyType) {
                        ForEach(MoneyType.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.moneyType.requiresAmount {
                        TextField("Amount", text: $viewModel.amountText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Note (optional)") {
                    TextField("e.g. text me your order", text: $viewModel.note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle("New run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AsyncButton {
                        guard let uid = appState.currentUserID else { return }
                        if await viewModel.create(hostID: uid) { dismiss() }
                    } label: {
                        Text("Post")
                    }
                    .disabled(!viewModel.canCreate)
                }
            }
        }
    }
}
