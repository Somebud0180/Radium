import SwiftUI

struct ServerListView: View {
    @EnvironmentObject private var store: ServerStore
    @State private var selectedID: UUID?
    @State private var isAdding = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                ForEach(store.servers) { server in
                    NavigationLink(value: server.id) {
                        Label(server.name, systemImage: "server.rack")
                    }
                }
                .onDelete { indexSet in indexSet.map { store.servers[$0] }.forEach(store.delete) }
            }
            .navigationTitle("RCON Servers")
            .toolbar { Button("Add server", systemImage: "plus") { isAdding = true } }
        } detail: {
            if let server = store.servers.first(where: { $0.id == selectedID }) {
                ServerDetailView(server: server)
            } else {
                ContentUnavailableView("Select a server", systemImage: "server.rack", description: Text("Add an RCON server to get started."))
            }
        }
        .sheet(isPresented: $isAdding) { ServerEditorView() }
    }
}

struct ServerEditorView: View {
    @EnvironmentObject private var store: ServerStore
    @Environment(\.dismiss) private var dismiss
    var existing: ServerConfiguration?
    @State private var name = ""
    @State private var host = ""
    @State private var port = "25575"
    @State private var password = ""
    @State private var profile: ServerProfile = .minecraftJava
    @State private var warningAcknowledged = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Name", text: $name)
                    TextField("Host or IP address", text: $host).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Port", text: $port).keyboardType(.numberPad)
                    SecureField("RCON password", text: $password)
                    Picker("Profile", selection: $profile) { ForEach(ServerProfile.allCases) { Text($0.title).tag($0) } }
                }
                Section("Connection security") {
                    Label("RCON passwords and commands travel as plaintext over standard TCP.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Toggle("I understand this network risk", isOn: $warningAcknowledged)
                }
            }
            .navigationTitle(existing == nil ? "Add Server" : "Edit Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.isEmpty || host.isEmpty || password.isEmpty || !warningAcknowledged || UInt16(port) == nil) }
            }
            .onAppear {
                guard let existing else { return }
                name = existing.name; host = existing.host; port = String(existing.port); profile = existing.profile
                password = store.password(for: existing) ?? ""; warningAcknowledged = existing.hasAcknowledgedPlaintextRisk
            }
        }
    }

    private func save() {
        guard let port = UInt16(port) else { return }
        var server = existing ?? ServerConfiguration(name: name, host: host)
        server.name = name; server.host = host; server.port = port; server.profile = profile; server.hasAcknowledgedPlaintextRisk = warningAcknowledged
        if let index = store.servers.firstIndex(where: { $0.id == server.id }) { store.servers[index] = server } else { store.servers.append(server) }
        store.savePassword(password, for: server)
        dismiss()
    }
}
