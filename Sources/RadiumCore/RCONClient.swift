import Foundation
import Network

public actor RCONClient {
    private var connection: NWConnection?
    private var requestID: Int32 = 1
    private let timeout: Duration

    public init(timeout: Duration = .seconds(8)) { self.timeout = timeout }

    public func connect(host: String, port: UInt16) async throws {
        await disconnect()
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { throw RCONError.connectionFailed("Invalid port") }
        let newConnection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        connection = newConnection
        newConnection.start(queue: .global(qos: .userInitiated))
        do {
            try await withTimeout { [weak self] in
                guard let self else { throw RCONError.disconnected }
                return try await self.waitUntilReady(newConnection)
            }
        } catch {
            await disconnect()
            throw error
        }
    }

    public func authenticate(password: String) async throws {
        let id = nextRequestID()
        try await send(RCONPacket(requestID: id, type: .authentication, body: password))
        let response = try await receivePacket()
        guard response.type == .authenticationResponse else { throw RCONError.protocolViolation("Expected authentication response") }
        guard response.requestID != -1, response.requestID == id else { throw RCONError.authenticationFailed }
    }

    public func execute(command: String) async throws -> String {
        let id = nextRequestID()
        try await send(RCONPacket(requestID: id, type: .command, body: command))
        let response = try await receivePacket()
        guard response.requestID == id, response.type == .responseValue else {
            throw RCONError.protocolViolation("Unexpected command response")
        }
        return response.body
    }

    public func disconnect() {
        connection?.cancel()
        connection = nil
    }

    private func nextRequestID() -> Int32 {
        defer { requestID = requestID == Int32.max ? 1 : requestID + 1 }
        return requestID
    }

    private func waitUntilReady(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: continuation.resume()
                case .failed(let error): continuation.resume(throwing: RCONError.connectionFailed(error.localizedDescription))
                case .cancelled: continuation.resume(throwing: RCONError.disconnected)
                default: break
                }
            }
        }
    }

    private func send(_ packet: RCONPacket) async throws {
        guard let connection else { throw RCONError.disconnected }
        try await withTimeout {
            try await withCheckedThrowingContinuation { continuation in
                connection.send(content: packet.encoded(), completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: RCONError.connectionFailed(error.localizedDescription)) }
                    else { continuation.resume() }
                })
            }
        }
    }

    private func receivePacket() async throws -> RCONPacket {
        guard let connection else { throw RCONError.disconnected }
        var frame = Data()
        while frame.count < 4 {
            frame.append(try await receiveChunk(connection, minimum: 4 - frame.count))
        }
        let size = try frame.readInt32(at: 0)
        guard size >= 10, size <= 4_194_304 else { throw RCONError.malformedPacket }
        var packet = frame
        while packet.count < Int(size) + 4 {
            packet.append(try await receiveChunk(connection, minimum: Int(size) + 4 - packet.count))
        }
        return try RCONPacket.decode(from: packet)
    }

    private func receiveChunk(_ connection: NWConnection, minimum: Int) async throws -> Data {
        try await withTimeout {
            try await withCheckedThrowingContinuation { continuation in
                connection.receive(minimumIncompleteLength: minimum, maximumLength: 65_536) { data, _, complete, error in
                    if let error { continuation.resume(throwing: RCONError.connectionFailed(error.localizedDescription)) }
                    else if let data, !data.isEmpty { continuation.resume(returning: data) }
                    else if complete { continuation.resume(throwing: RCONError.disconnected) }
                    else { continuation.resume(throwing: RCONError.disconnected) }
                }
            }
        }
    }

    private func withTimeout<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask { try await Task.sleep(for: self.timeout); throw RCONError.timedOut }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
