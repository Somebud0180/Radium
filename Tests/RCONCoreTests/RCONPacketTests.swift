import XCTest
@testable import RCONCore

final class RCONPacketTests: XCTestCase {
    func testPacketRoundTrip() throws {
        let original = RCONPacket(requestID: 42, type: .command, body: "say Hello")
        XCTAssertEqual(try RCONPacket.decode(from: original.encoded()), original)
    }
    func testRejectsMalformedPacket() {
        XCTAssertThrowsError(try RCONPacket.decode(from: Data([1, 2, 3])))
    }
}
