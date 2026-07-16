import Foundation
import RCONCore

@MainActor
final class RCONSession: ObservableObject {
    static let shared = RCONSession()
    enum State: Equatable { case disconnected, connecting, connected, failed(String) }
    @Published private(set) var state: State = .disconnected
    @Published private(set) var history: [TerminalEntry] = []
    private let client = RCONClient()

    func connect(to server: ServerConfiguration, password: String) async {
        state = .connecting
        do {
            try await client.connect(host: server.host, port: server.port)
            try await client.authenticate(password: password)
            state = .connected
        } catch { state = .failed(error.localizedDescription) }
    }

    func execute(_ command: String) async -> String? {
        guard case .connected = state else { return nil }
        do {
            let response = try await client.execute(command: command)
            history.insert(.init(command: command, response: response), at: 0)
            return response
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    func disconnect() { Task { await client.disconnect() }; state = .disconnected }
}
