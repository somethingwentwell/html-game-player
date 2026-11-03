import XCTest
import WebKit
@testable import HTMLArcade

@MainActor
final class WebKitStorageTests: XCTestCase {
    private final class Loader: NSObject, WKNavigationDelegate {
        var completion: CheckedContinuation<Void, Error>?
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { completion?.resume(); completion = nil }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            completion?.resume(throwing: error); completion = nil
        }
    }

    private func open(_ file: URL, profile: UUID) async throws -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: profile)
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 640), configuration: config)
        let loader = Loader()
        view.navigationDelegate = loader
        try await withCheckedThrowingContinuation { continuation in
            loader.completion = continuation
            view.loadFileURL(file, allowingReadAccessTo: file.deletingLastPathComponent())
        }
        view.navigationDelegate = nil
        return view
    }

    func testGameSavePersistsAcrossWebViewsAndIsIsolatedFromOtherGames() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("game.html")
        try Data("<!doctype html><html><body>Save test</body></html>".utf8).write(to: file)
        let firstID = UUID(), secondID = UUID()
        let first = try await open(file, profile: firstID)
        _ = try await first.evaluateJavaScript("localStorage.setItem('score', '42')")
        let reopened = try await open(file, profile: firstID)
        let score = try await reopened.evaluateJavaScript("localStorage.getItem('score')")
        XCTAssertEqual(score as? String, "42")
        let separate = try await open(file, profile: secondID)
        let separateScore = try await separate.evaluateJavaScript("localStorage.getItem('score')")
        XCTAssertTrue(separateScore is NSNull)
        WKWebsiteDataStore.remove(forIdentifier: firstID) { _ in }
        WKWebsiteDataStore.remove(forIdentifier: secondID) { _ in }
    }
}
