//
//  ServerEditorView.swift
//  Radium
//
//  Created by Ethan John Lagera on 7/21/26.
//

import SwiftUI

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
    @State private var lockWarning = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Name", text: $name)
                    TextField("Host or IP address", text: $host).radiumHostInputTraits()
                    TextField("Port", text: $port).radiumPortInputTraits()
                    SecureField("RCON password", text: $password)
                    Picker("Profile", selection: $profile) { ForEach(ServerProfile.allCases) { Text($0.title).tag($0) } }
                }
                Section("Connection security") {
                    Label("RCON passwords and commands travel as plaintext over standard TCP.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Toggle("I understand this network risk", isOn: $warningAcknowledged)
                        .disabled(lockWarning)
                }
            }
            .navigationTitle(existing == nil ? "Add Server" : "Edit Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.isEmpty || host.isEmpty || password.isEmpty || !warningAcknowledged || UInt16(port) == nil) }
            }
            .onAppear {
                guard let existing else { return }
                name = existing.name
                host = existing.host
                port = String(existing.port)
                profile = existing.profile
                password = store.password(for: existing) ?? ""
                warningAcknowledged = existing.hasAcknowledgedPlaintextRisk
                lockWarning = existing.hasAcknowledgedPlaintextRisk
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

private extension View {
    @ViewBuilder
    func radiumHostInputTraits() -> some View {
#if os(iOS)
        textInputAutocapitalization(.never).autocorrectionDisabled()
#else
        self
#endif
    }
    
    @ViewBuilder
    func radiumPortInputTraits() -> some View {
#if os(iOS)
        keyboardType(.numberPad)
#else
        self
#endif
    }
}
