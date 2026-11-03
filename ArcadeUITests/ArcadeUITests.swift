import XCTest

final class ArcadeUITests: XCTestCase {
    @MainActor
    func testSuppliedLargeOfflineGame() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("fixtures/PokeSurvivor-Offline.html")
        guard FileManager.default.fileExists(atPath: fixture.path) else { throw XCTSkip("Optional local PokeSurvivor fixture is absent") }
        let app = XCUIApplication()
        app.terminate()
        XCUIDevice.shared.orientation = .landscapeLeft
        // CoreSimulator reports orientation before its window rotation animation finishes.
        Thread.sleep(forTimeInterval: 2)
        app.launchEnvironment["ARCADE_IMPORT_FILE"] = fixture.path
        app.launch()
        let featured = app.buttons["featuredGame"]
        let imported = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "PokeSurvivor"), object: featured)
        XCTAssertEqual(XCTWaiter.wait(for: [imported], timeout: 60), .completed)
        featured.tap()
        XCTAssertTrue(app.buttons["gameMenu"].waitForExistence(timeout: 15))
        let game = app.webViews.firstMatch
        XCTAssertTrue(game.waitForExistence(timeout: 30))
        // The supplied game starts with a canvas splash, so DOM button counts aren't a readiness signal.
        let opening = app.staticTexts["Opening PokeSurvivor Offline…"]
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: opening)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 30), .completed)
        let capture = XCUIScreen.main.screenshot()
        let screenshot = XCTAttachment(screenshot: capture)
        screenshot.name = "PokeSurvivor 104 MB offline game"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testLibraryFindAndNativeFilesPicker() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["featuredGame"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Find"].tap()
        let browse = app.buttons["browseDeviceFiles"]
        XCTAssertTrue(browse.waitForExistence(timeout: 5))
        browse.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Searchable native Files importer"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
    }

    @MainActor
    func testFullScreenPlayerAndReturnToLibrary() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["featuredGame"].waitForExistence(timeout: 30))
        let orbit = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Orbit")).firstMatch
        for _ in 0..<4 {
            if orbit.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(orbit.isHittable)
        orbit.tap()
        let menu = app.buttons["gameMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        XCTAssertTrue(app.webViews.staticTexts["Stay in orbit."].waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Full-screen Orbit player"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        menu.tap()
        let back = app.buttons["Back to Library"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.buttons["importGame"].waitForExistence(timeout: 5))
    }
}
