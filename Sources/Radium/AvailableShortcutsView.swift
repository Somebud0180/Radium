import SwiftUI

struct AvailableShortcutsView: View {
    let server: ServerConfiguration
    @Binding var shortcuts: [ShortcutDefinition]
    @ObservedObject private var session = RCONSession.shared
    @State private var editing: ShortcutDefinition?
    @State private var isAdding = false
    @State private var discoveryMessage: String?

    var body: some View {
        List {
            if let discoveryMessage { Section { Text(discoveryMessage).font(.footnote).foregroundStyle(.secondary) } }
            Section("Suggested and custom shortcuts") {
                ForEach(shortcuts) { shortcut in
                    Button { editing = shortcut } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(shortcut.label).foregroundStyle(.primary)
                                Text(shortcut.rationale ?? shortcut.command).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if shortcut.isPinned { Image(systemName: "pin.fill").foregroundStyle(.tint) }
                            if let confidence = shortcut.confidence { Text(confidence.rawValue.capitalized).font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                }
                .onDelete { shortcuts.remove(atOffsets: $0) }
            }
        }
        .overlay { if shortcuts.isEmpty { ContentUnavailableView("No shortcuts", systemImage: "command", description: Text("Add one manually or discover commands from the server.")) } }
        .toolbar {
            Button("Discover from help", systemImage: "wand.and.stars") { discover() }
            Button("Add shortcut", systemImage: "plus") { isAdding = true }
        }
        .sheet(item: $editing) { item in ShortcutEditorView(shortcut: item) { update($0) } }
        .sheet(isPresented: $isAdding) { ShortcutEditorView(shortcut: ShortcutDefinition(label: "", command: "")) { shortcuts.append($0) } }
    }

    private func update(_ value: ShortcutDefinition) {
        guard let index = shortcuts.firstIndex(where: { $0.id == value.id }) else { return }
        shortcuts[index] = value
    }
    private func discover() {
        Task {
            guard let result = await session.execute("help") else { discoveryMessage = "Connect to this server before discovering commands."; return }
            let found = ShortcutInference.suggestions(from: result)
            let existing = Set(shortcuts.map(\.command))
            shortcuts.append(contentsOf: found.filter { !existing.contains($0.command) })
            discoveryMessage = found.isEmpty ? "No recognizable commands were found in the help response." : "Added \(found.count) suggestions. Review their commands before pinning."
        }
    }
}

struct ShortcutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shortcut: ShortcutDefinition
    let save: (ShortcutDefinition) -> Void

    init(shortcut: ShortcutDefinition, save: @escaping (ShortcutDefinition) -> Void) {
        _shortcut = State(initialValue: shortcut); self.save = save
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Shortcut") {
                    TextField("Label", text: $shortcut.label)
                    TextField("Description", text: $shortcut.description, axis: .vertical)
                    Picker("Control type", selection: $shortcut.controlType) { ForEach(ShortcutControlType.allCases) { Text($0.title).tag($0) } }
                    Toggle("Pin to dashboard", isOn: $shortcut.isPinned)
                }
                if let rationale = shortcut.rationale { Section("Suggestion") { Text(rationale); if let confidence = shortcut.confidence { Text("Confidence: \(confidence.rawValue.capitalized)").foregroundStyle(.secondary) } } }
                commandSection
            }
            .navigationTitle("Edit Shortcut")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save(shortcut); dismiss() }.disabled(shortcut.label.isEmpty || !isValid) } }
        }
    }

    @ViewBuilder private var commandSection: some View {
        switch shortcut.controlType {
        case .switch:
            Section("Switch commands") {
                TextField("Set on", text: $shortcut.switchConfiguration.setOn)
                TextField("Set off", text: $shortcut.switchConfiguration.setOff)
                TextField("Check status", text: $shortcut.switchConfiguration.status)
                TextField("On keywords (comma-separated)", text: keywordsBinding(\.onKeywords))
                TextField("Off keywords (comma-separated)", text: keywordsBinding(\.offKeywords))
            }
        case .toggle:
            Section("Toggle command") { TextField("Command", text: $shortcut.toggleConfiguration.command); Stepper("Response excerpt: \(shortcut.toggleConfiguration.responseExcerptLength) characters", value: $shortcut.toggleConfiguration.responseExcerptLength, in: 40...500, step: 20) }
        case .button, .terminal:
            Section("Command") { TextField("RCON command", text: $shortcut.command, axis: .vertical) }
        }
    }
    private var isValid: Bool {
        switch shortcut.controlType {
        case .switch: return !shortcut.switchConfiguration.setOn.isEmpty && !shortcut.switchConfiguration.setOff.isEmpty && !shortcut.switchConfiguration.status.isEmpty
        case .toggle: return !(shortcut.toggleConfiguration.command.isEmpty ? shortcut.command : shortcut.toggleConfiguration.command).isEmpty
        default: return !shortcut.command.isEmpty
        }
    }
    private func keywordsBinding(_ keyPath: WritableKeyPath<SwitchConfiguration, [String]>) -> Binding<String> {
        Binding(get: { shortcut.switchConfiguration[keyPath: keyPath].joined(separator: ", ") }, set: { shortcut.switchConfiguration[keyPath: keyPath] = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } })
    }
}
