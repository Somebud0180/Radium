import XCTest
@testable import RCONCommander

final class ShortcutInferenceTests: XCTestCase {
    func testInfersSwitchWhenAllCommandsExist() {
        let values = ShortcutInference.suggestions(from: "gamerule keepInventory on\ngamerule keepInventory off\ngamerule keepInventory status")
        XCTAssertTrue(values.contains { $0.controlType == .switch })
    }
    func testSwitchUsesKeywordsAndUnknownIsSafe() {
        let config = SwitchConfiguration(onKeywords: ["enabled"], offKeywords: ["disabled"])
        XCTAssertEqual(config.state(for: "Feature enabled"), true)
        XCTAssertEqual(config.state(for: "Feature disabled"), false)
        XCTAssertNil(config.state(for: "No result"))
    }
}
