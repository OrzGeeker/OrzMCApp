import XCTest
@testable import OrzMCDesignSystem

final class ContentStateTests: XCTestCase {
    func testContentStateStoresDisplayMetadata() {
        let state = ContentState(
            title: "No Selection",
            message: "Pick an item",
            systemImage: "cube.box"
        )

        XCTAssertEqual(state.title, "No Selection")
        XCTAssertEqual(state.message, "Pick an item")
        XCTAssertEqual(state.systemImage, "cube.box")
    }
}
