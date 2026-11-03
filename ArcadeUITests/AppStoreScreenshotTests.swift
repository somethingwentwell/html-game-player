import XCTest

final class AppStoreScreenshotTests: XCTestCase {
    @MainActor
    func testStoreScreenshots() throws {
        let app = XCUIApplication()
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["featuredGame"].waitForExistence(timeout: 30))
        capture("AppStore-01-Library")

        app.buttons["Find"].firstMatch.tap()
        XCTAssertTrue(app.buttons["browseDeviceFiles"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.links["githubGameList"].exists || app.buttons["githubGameList"].exists)
        capture("AppStore-02-Find")

        app.buttons["Library"].firstMatch.tap()
        app.buttons["featuredGame"].tap()
        XCTAssertTrue(app.buttons["gameMenu"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.webViews.staticTexts["Stay in orbit."].waitForExistence(timeout: 15))
        // WebKit can expose its accessibility tree before its first composited frame.
        Thread.sleep(forTimeInterval: 2)
        capture("AppStore-03-Play")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
