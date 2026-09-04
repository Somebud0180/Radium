import Foundation
import Network
import os

public actor RCONClient {
    private let logger = Logger(subsystem: "com.radium.RadiumCore", category: "RCONClient")
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
        logger.debug("Authenticating with ID: \(id)")
        try await send(RCONPacket(requestID: id, type: .authentication, body: password))
        
        while true {
            let response = try await receivePacket()
            logger.debug("Received authentication response: type=\(response.type.wireValue), id=\(response.requestID)")
            if response.type == .command { // SERVERDATA_AUTH_RESPONSE
                guard response.requestID != -1, response.requestID == id else {
                    logger.error("Authentication failed: ID mismatch or -1")
                    throw RCONError.authenticationFailed 
                }
                logger.info("Authentication successful")
                return
            } else if response.type == .responseValue {
                logger.debug("Ignoring extra SERVERDATA_RESPONSE_VALUE during authentication")
                continue
            } else {
                logger.error("Unexpected packet type during authentication: \(response.type.wireValue)")
                throw RCONError.protocolViolation("Expected authentication response")
            }
        }
    }

    public func execute(command: String) async throws -> String {
        let commandID = nextRequestID()
        logger.debug("Executing command: '\(command)' with ID: \(commandID)")
        try await send(RCONPacket(requestID: commandID, type: .command, body: command))
        
        let terminatorID = nextRequestID()
        logger.debug("Sending terminator with ID: \(terminatorID)")
        try await send(RCONPacket(requestID: terminatorID, type: .command, body: ""))
        
        var fullResponse = ""
        while true {
            let response = try await receivePacket()
            logger.debug("Received packet: ID=\(response.requestID), type=\(response.type.wireValue), size=\(response.body.count)")
            
            if response.requestID == commandID {
                if response.type == .responseValue {
                    fullResponse += response.body
                } else {
                    logger.warning("Received packet with command ID but unexpected type: \(response.type.wireValue)")
                }
            } else if response.requestID == terminatorID {
                if response.type == .responseValue {
                    logger.debug("Received terminator response, finishing execute")
                    return fullResponse
                } else {
                    logger.warning("Received packet with terminator ID but unexpected type: \(response.type.wireValue)")
                }
            } else {
                logger.warning("Received unexpected packet ID: \(response.requestID), expected \(commandID) or \(terminatorID)")
            }
        }
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
        
        let packet = try RCONPacket.decode(from: packetData)
        logger.debug("Decoded packet: ID=\(packet.requestID), type=\(packet.type.wireValue)")
        return packet
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
