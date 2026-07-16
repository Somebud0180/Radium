import Foundation
import Security

@MainActor
final class ServerStore: ObservableObject {
    @Published var servers: [ServerConfiguration] = [] { didSet { save() } }
    @Published var shortcuts: [UUID: [ShortcutDefinition]] = [:] { didSet { saveShortcuts() } }
    private let serversKey = "saved-rcon-servers"
    private let shortcutsKey = "saved-rcon-shortcuts"

    init() {
        if let data = UserDefaults.standard.data(forKey: serversKey), let value = try? JSONDecoder().decode([ServerConfiguration].self, from: data) { servers = value }
        if let data = UserDefaults.standard.data(forKey: shortcutsKey), let value = try? JSONDecoder().decode([UUID: [ShortcutDefinition]].self, from: data) { shortcuts = value }
    }

    func shortcuts(for server: ServerConfiguration) -> [ShortcutDefinition] {
        if let saved = shortcuts[server.id] { return saved }
        return server.profile == .minecraftJava ? MinecraftCatalog.curated : []
    }

    func replaceShortcuts(_ value: [ShortcutDefinition], for server: ServerConfiguration) { shortcuts[server.id] = value }
    func password(for server: ServerConfiguration) -> String? { Keychain.password(for: server.passwordKey) }
    func savePassword(_ password: String, for server: ServerConfiguration) { Keychain.save(password, for: server.passwordKey) }
    func delete(_ server: ServerConfiguration) { Keychain.delete(server.passwordKey); shortcuts.removeValue(forKey: server.id); servers.removeAll { $0.id == server.id } }

    private func save() { UserDefaults.standard.set(try? JSONEncoder().encode(servers), forKey: serversKey) }
    private func saveShortcuts() { UserDefaults.standard.set(try? JSONEncoder().encode(shortcuts), forKey: shortcutsKey) }
}

enum Keychain {
    static func password(for key: String) -> String? {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecReturnData: true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ password: String, for key: String) {
        delete(key)
        SecItemAdd([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecValueData: Data(password.utf8)] as CFDictionary, nil)
    }
    static func delete(_ key: String) { SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key] as CFDictionary) }
}
