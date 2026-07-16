import Foundation

enum ServerProfile: String, Codable, CaseIterable, Identifiable {
    case minecraftJava
    case generic
    var id: String { rawValue }
    var title: String { self == .minecraftJava ? "Minecraft: Java Edition" : "Generic RCON" }
}

struct ServerConfiguration: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var host: String
    var port: UInt16 = 25575
    var profile: ServerProfile = .minecraftJava
    var passwordKey: String { "rcon-password-\(id.uuidString)" }
    var hasAcknowledgedPlaintextRisk = false
}

enum ShortcutControlType: String, Codable, CaseIterable, Identifiable {
    case button, toggle, `switch`
    var id: String { rawValue }
    var title: String {
        switch self {
        case .button: "Button"
        case .toggle: "Toggle action"
        case .switch: "Switch"
        }
    }
}

enum SuggestionConfidence: String, Codable {
    case high, medium, low
}

struct SwitchConfiguration: Codable, Hashable {
    var setOn = ""
    var setOff = ""
    var status = ""
    var onKeywords = ["on", "enabled", "true"]
    var offKeywords = ["off", "disabled", "false"]

    func state(for response: String) -> Bool? {
        let value = response.lowercased()
        if onKeywords.contains(where: { !$0.isEmpty && value.contains($0.lowercased()) }) { return true }
        if offKeywords.contains(where: { !$0.isEmpty && value.contains($0.lowercased()) }) { return false }
        return nil
    }
}

struct ToggleConfiguration: Codable, Hashable {
    var command = ""
    var responseExcerptLength = 160
}

struct ShortcutDefinition: Identifiable, Codable, Hashable {
    var id = UUID()
    var label: String
    var description: String = ""
    var command: String
    var controlType: ShortcutControlType = .button
    var isPinned = false
    var confidence: SuggestionConfidence? = nil
    var rationale: String? = nil
    var switchConfiguration = SwitchConfiguration()
    var toggleConfiguration = ToggleConfiguration()
}

struct TerminalEntry: Identifiable, Hashable {
    let id = UUID()
    let command: String
    let response: String
    let date = Date()
}

enum MinecraftCatalog {
    static let curated: [ShortcutDefinition] = [
        .init(label: "List players", description: "Show online players", command: "list", isPinned: true),
        .init(label: "Save world", description: "Save all loaded chunks", command: "save-all", isPinned: true),
        .init(label: "Weather clear", description: "Set clear weather", command: "weather clear", isPinned: true),
        .init(label: "Daytime", description: "Set time to day", command: "time set day", isPinned: true)
    ]
}
