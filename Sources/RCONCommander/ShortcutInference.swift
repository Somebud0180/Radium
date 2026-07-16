import Foundation

enum ShortcutInference {
    static func suggestions(from helpOutput: String) -> [ShortcutDefinition] {
        let commands = parseCommands(helpOutput)
        let set = Set(commands)
        return commands.map { command in
            let label = command.replacingOccurrences(of: "/", with: "").capitalized
            let base = command.replacingOccurrences(of: " status", with: "")
            let hasStatus = set.contains("\(base) status") || set.contains("\(base)status")
            if command.contains(" on") || command.contains(" off") {
                let normalized = command.replacingOccurrences(of: " on", with: "").replacingOccurrences(of: " off", with: "")
                let on = "\(normalized) on"
                let off = "\(normalized) off"
                if set.contains(on), set.contains(off), set.contains("\(normalized) status") {
                    var shortcut = ShortcutDefinition(label: label, command: command, controlType: .switch, confidence: .high, rationale: "Found on, off, and status commands.")
                    shortcut.switchConfiguration = .init(setOn: on, setOff: off, status: "\(normalized) status")
                    return shortcut
                }
            }
            if hasStatus {
                var shortcut = ShortcutDefinition(label: label, command: command, controlType: .toggle, confidence: .medium, rationale: "Found a neighboring status command; review before pinning.")
                shortcut.toggleConfiguration.command = command
                return shortcut
            }
            return ShortcutDefinition(label: label, command: command, controlType: .button, confidence: .low, rationale: "No safe state semantics were found.")
        }
    }

    private static func parseCommands(_ output: String) -> [String] {
        let matches = output.matches(of: /(?m)^\/?([a-z][a-z0-9:_-]*(?:\s+(?:on|off|status))?)(?:\s|$)/)
        return Array(Set(matches.map { String($0.1) })).sorted()
    }
}
