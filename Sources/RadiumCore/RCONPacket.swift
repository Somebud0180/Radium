import Foundation

/// RCON uses wire value `2` for both an outbound command and an authentication reply.
/// Request context distinguishes those two packet meanings.
public enum RCONPacketType: Sendable {
    case responseValue
    case command
    case authentication

    var wireValue: Int32 {
        switch self {
        case .responseValue: 0
        case .command: 2
        case .authentication: 3
        }
    }

    static func decode(wireValue: Int32) -> RCONPacketType? {
        switch wireValue {
        case 0: .responseValue
        case 2: .command
        case 3: .authentication
        default: nil
        }
    }
}

public struct RCONPacket: Equatable, Sendable {
    public let requestID: Int32
    public let type: RCONPacketType
    public let body: String

    public init(requestID: Int32, type: RCONPacketType, body: String) {
        self.requestID = requestID
        self.type = type
        self.body = body
    }

    public func encoded() -> Data {
        var payload = Data()
        payload.appendLittleEndian(requestID)
        payload.appendLittleEndian(type.wireValue)
        payload.append(body.data(using: .utf8) ?? Data())
        payload.append(contentsOf: [0, 0])
        var frame = Data()
        frame.appendLittleEndian(Int32(payload.count))
        frame.append(payload)
        return frame
    }

    public static func decode(from data: Data) throws -> RCONPacket {
        guard data.count >= 14 else { throw RCONError.malformedPacket }
        let declaredLength = try data.readInt32(at: 0)
        guard declaredLength >= 10, Int(declaredLength) + 4 == data.count else { throw RCONError.malformedPacket }
        let requestID = try data.readInt32(at: 4)
        let rawType = try data.readInt32(at: 8)
        guard let type = RCONPacketType.decode(wireValue: rawType), data.suffix(2) == Data([0, 0]) else {
            throw RCONError.malformedPacket
        }
        let bodyData = data.subdata(in: 12..<(data.count - 2))
        guard let body = String(data: bodyData, encoding: .utf8) else { throw RCONError.malformedPacket }
        return RCONPacket(requestID: requestID, type: type, body: body)
    }
}

public enum RCONError: LocalizedError, Sendable, Equatable {
    case connectionFailed(String)
    case authenticationFailed
    case protocolViolation(String)
    case malformedPacket
    case timedOut
    case disconnected

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let message): return "Could not connect: \(message)"
        case .authenticationFailed: return "The RCON password was rejected."
        case .protocolViolation(let message): return "RCON protocol error: \(message)"
        case .malformedPacket: return "The server sent an invalid RCON packet."
        case .timedOut: return "The RCON server did not respond in time."
        case .disconnected: return "The RCON connection was closed."
        }
    }
}

extension Data {
    mutating func appendLittleEndian(_ value: Int32) {
        var littleEndian = value.littleEndian
        append(Data(bytes: &littleEndian, count: MemoryLayout<Int32>.size))
    }

    func readInt32(at offset: Int) throws -> Int32 {
        guard offset >= 0, offset + 4 <= count else { throw RCONError.malformedPacket }
        return withUnsafeBytes { rawBuffer in
            rawBuffer.loadUnaligned(fromByteOffset: offset, as: Int32.self).littleEndian
        }
    }
}
