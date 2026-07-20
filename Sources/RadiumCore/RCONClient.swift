import Foundation
import Network

public actor RCONClient {
    private var connection: NWConnection?
    private var requestID: Int32 = 1
    private let timeout: Duration
    private var buffer = Data()

    public init(timeout: Duration = .seconds(8)) { self.timeout = timeout }

    public func connect(host: String, port: UInt16) async throws {
        disconnect()
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
            disconnect()
            throw error
        }
    }

    public func authenticate(password: String) async throws {
        let id = nextRequestID()
        try await send(RCONPacket(requestID: id, type: .authentication, body: password))
        let response = try await receivePacket()
        guard response.type == .command else { throw RCONError.protocolViolation("Expected authentication response") }
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
        buffer.removeAll()
    }

    private func nextRequestID() -> Int32 {
        defer { requestID = requestID == Int32.max ? 1 : requestID + 1 }
        return requestID
    }

    private func waitUntilReady(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: RCONError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: RCONError.disconnected)
                default: break
                }
            }
        }
    }

    private func send(_ packet: RCONPacket) async throws {
        guard let connection else { throw RCONError.disconnected }
        try await withTimeout {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                connection.send(content: packet.encoded(), completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: RCONError.connectionFailed(error.localizedDescription)) }
                    else { continuation.resume() }
                })
            }
        }
    }

    private func receivePacket() async throws -> RCONPacket {
        guard let connection else { throw RCONError.disconnected }
        
        while buffer.count < 4 {
            let needed = 4 - buffer.count
            buffer.append(try await receiveChunk(connection, minimum: needed))
        }
        
        let size = try buffer.readInt32(at: 0)
        
        guard size >= 10, size <= 4_194_304 else { throw RCONError.malformedPacket }
        
        let totalLength = Int(size) + 4
        
        while buffer.count < totalLength {
            let needed = totalLength - buffer.count
            buffer.append(try await receiveChunk(connection, minimum: needed))
        }
        
        let packetData = buffer.subdata(in: 0..<totalLength)
        
        buffer.removeSubrange(0..<totalLength)
        
        return try RCONPacket.decode(from: packetData)
    }

    private func receiveChunk(_ connection: NWConnection, minimum: Int) async throws -> Data {
        try await withTimeout {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                    connection.receive(minimumIncompleteLength: minimum, maximumLength: 65_536) { data, _, complete, error in
                        if let error {
                            continuation.resume(throwing: RCONError.connectionFailed(error.localizedDescription))
                        } else if let data, !data.isEmpty {
                            continuation.resume(returning: data)
                        } else {
                            continuation.resume(throwing: RCONError.disconnected)
                        }
                    }
                }
            } onCancel: {
                connection.cancel()
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
