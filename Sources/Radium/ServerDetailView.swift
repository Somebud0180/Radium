import SwiftUI

struct ServerDetailView: View {
    @EnvironmentObject private var store: ServerStore
    @ObservedObject private var session = RCONSession.shared
    let server: ServerConfiguration
    @State private var selectedTab = "Dashboard"
    @State private var isEditingServer = false
    @State private var showingShortcuts = false
    @State private var shortcuts: [ShortcutDefinition] = []

    var body: some View {
        VStack(spacing: 0) {
            connectionBar
            Picker("Section", selection: $selectedTab) {
                Text("Dashboard").tag("Dashboard")
                Text("Terminal").tag("Terminal")
                Text("Available Shortcuts").tag("Shortcuts")
            }
            .pickerStyle(.segmented).padding()
            Group {
                if selectedTab == "Dashboard" { DashboardView(shortcuts: $shortcuts) }
                else if selectedTab == "Terminal" { TerminalView() }
                else { AvailableShortcutsView(server: server, shortcuts: $shortcuts) }
            }
        }
        .navigationTitle(server.name)
        .toolbar { Button("Edit server", systemImage: "slider.horizontal.3") { isEditingServer = true } }
        .sheet(isPresented: $isEditingServer) { ServerEditorView(existing: server) }
        .task { shortcuts = store.shortcuts(for: server) }
        .onChange(of: shortcuts) { _, updated in store.replaceShortcuts(updated, for: server) }
        .onDisappear { session.disconnect() }
    }

    private var connectionBar: some View {
        HStack {
            switch session.state {
            case .disconnected: Label("Disconnected", systemImage: "circle")
            case .connecting: Label("Connecting…", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(.orange)
            case .connected: Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed(let error): Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(.red).lineLimit(1)
            }
            Spacer()
            if case .connected = session.state { Button("Disconnect") { session.disconnect() } }
            else { Button("Connect") { Task { await session.connect(to: server, password: store.password(for: server) ?? "") } } }
        }
        .padding(.horizontal).padding(.vertical, 10).background(.bar)
    }
}

struct DashboardView: View {
    @Binding var shortcuts: [ShortcutDefinition]
    @ObservedObject private var session = RCONSession.shared
    @State private var response = ""

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(shortcuts.filter(\.isPinned)) { shortcut in
                    ShortcutControl(shortcut: shortcut) { command in
                        response = await session.execute(command) ?? "Command was not sent."
                    }
                }
            }.padding()
            if !response.isEmpty { Text(response).font(.footnote).textSelection(.enabled).padding().frame(maxWidth: .infinity, alignment: .leading) }
        }
    }
}

struct ShortcutControl: View {
    let shortcut: ShortcutDefinition
    let run: (String) async -> Void
    @State private var switchState: Bool? = nil
    @State private var response = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(shortcut.label)
                .font(.headline)
            
            if !shortcut.description.isEmpty { Text(shortcut.description).font(.caption).foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
            
            HStack {
                Spacer()
                switch shortcut.controlType {
                case .button:
                    Button("Run") {
                        Task { await run(shortcut.command) }
                    }
                    .adaptiveGlassButton(prominent: true)
                    
                case .toggle:
                    Button("Run toggle") {
                        Task {
                            response = await RCONSession.shared.execute(shortcut.toggleConfiguration.command.isEmpty ? shortcut.command : shortcut.toggleConfiguration.command) ?? ""
                        }
                    }
                    
                    if !response.isEmpty { Text(String(response.prefix(shortcut.toggleConfiguration.responseExcerptLength))).font(.caption).lineLimit(3)
                    }
                    
                case .switch:
                    Toggle(
                        isOn: Binding(
                            get: { switchState ?? false },
                            set: { wanted in Task { await setSwitch(wanted) } }
                        )
                    ) {
                        Text(switchState == nil ? "Unknown" : (switchState! ? "On" : "Off"))
                    }
                    
                    Button("Refresh status") {
                        Task { await refresh() }
                    }
                    .font(.caption)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .adaptiveBackground()
        .task { if shortcut.controlType == .switch { await refresh() } }
    }

    private func refresh() async {
        guard let output = await RCONSession.shared.execute(shortcut.switchConfiguration.status) else { return }
        switchState = shortcut.switchConfiguration.state(for: output)
    }
    private func setSwitch(_ wanted: Bool) async {
        _ = await RCONSession.shared.execute(wanted ? shortcut.switchConfiguration.setOn : shortcut.switchConfiguration.setOff)
        await refresh()
    }
}

struct TerminalView: View {
    @ObservedObject private var session = RCONSession.shared
    @State private var command = ""
    var body: some View {
        VStack {
            List(session.history) { entry in
                VStack(alignment: .leading, spacing: 4) { Text("> \(entry.command)").font(.system(.body, design: .monospaced)); Text(entry.response).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
            }
            HStack { TextField("RCON command", text: $command, axis: .vertical).textFieldStyle(.roundedBorder); Button("Send") { let value = command; command = ""; Task { _ = await session.execute(value) } }.disabled(command.isEmpty) }.padding()
        }
    }
}
