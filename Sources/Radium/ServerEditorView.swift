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
    @ObservedObject var session = RCONSession.shared
    
    @State private var name = ""
    @State private var host = ""
    @State private var port = "25575"
    @State private var password = ""
    @State private var profile: ServerProfile = .minecraftJava
    @State private var warningAcknowledged = false
    @State private var lockWarning = false
    @State private var showConnectionState: Bool = false
    @State private var error: String = ""
    
    var existing: ServerConfiguration?

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Name", text: $name)
                    
                    TextField("Host or IP address", text: $host).radiumHostInputTraits()
                        .onChange(of: host) {
                            showConnectionState = false
                        }
                    
                    TextField("Port", text: $port).radiumPortInputTraits()
                        .onChange(of: port) {
                            showConnectionState = false
                        }
                    
                    SecureField("RCON password", text: $password)
                    
                    Picker("Profile", selection: $profile) { ForEach(ServerProfile.allCases) { Text($0.title).tag($0) } }
                }
                
                Section {
                    Button(action: {
                        testConnection()
                    }, label: {
                        Text("Test connection")
                    })
                    
                    if showConnectionState {
                        switch session.state {
                        case .disconnected: Label("Disconnected", systemImage: "circle")
                        case .connecting: Label("Connecting…", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(.orange)
                        case .connected: Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        case .failed(let error): Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(.red)
                        }
                    } else if !error.isEmpty {
                        Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(.red)
                    }
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
    
    private func testConnection() {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedHost.isEmpty, let portValue = UInt16(trimmedPort) else {
            error = "Missing or invalid host/port"
            showConnectionState = false
            return
        }
        
        error = ""
        
        if session.state != .disconnected && session.state != .failed("") {
            session.disconnect()
        }
        
        Task {
            showConnectionState = true
            
            let testConfig = ServerConfiguration(
                name: name,
                host: trimmedHost,
                port: portValue,
                profile: profile
            )
            
            await session.connect(to: testConfig, password: password)
        }
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
