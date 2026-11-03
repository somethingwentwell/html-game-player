import XCTest
import CryptoKit
@testable import HTMLArcade

final class GameRepositoryTests: XCTestCase {
    private var directory: URL!
    private var repository: GameRepository!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        repository = GameRepository(root: directory.appendingPathComponent("Library"))
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    private func fixture(_ name: String, text: String = "<!doctype html><html><body>Game</body></html>") throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }

    func testImportPersistsExactBytesAndSurvivesSourceRemoval() async throws {
        let original = try fixture("A-Game.HTML", text: "<!doctype html><html><script>localStorage.save='✓'</script></html>")
        let expected = try Data(contentsOf: original)
        let game = try await repository.importFile(original)
        try await repository.save([game])
        try FileManager.default.removeItem(at: original)
        let stored = await repository.fileURL(for: game)
        XCTAssertEqual(try Data(contentsOf: stored), expected)
        let reopened = try await GameRepository(root: directory.appendingPathComponent("Library")).load()
        XCTAssertEqual(reopened, [game])
        XCTAssertEqual(game.title, "A Game")
    }

    func testDuplicateNamesHaveSeparateFilesAndSaveIdentities() async throws {
        let original = try fixture("index.html")
        let first = try await repository.importFile(original)
        let second = try await repository.importFile(original)
        XCTAssertNotEqual(first.id, second.id)
        let firstURL = await repository.fileURL(for: first)
        let secondURL = await repository.fileURL(for: second)
        XCTAssertNotEqual(firstURL, secondURL)
        try await repository.removeFiles(for: first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
    }

    func testRejectsFakeHTMLAndNonHTMLFiles() async throws {
        for (filename, text) in [("fake.html", "This is a PDF"), ("game.zip", "<html>Game</html>"), ("empty.html", "")] {
            let file = try fixture(filename, text: text)
            do { _ = try await repository.importFile(file); XCTFail("Accepted \(filename)") }
            catch { XCTAssertTrue(error is ImportError) }
        }
    }

    func testSymlinkImportsCopyContentRatherThanAnExternalReference() async throws {
        let original = try fixture("original.html")
        let link = directory.appendingPathComponent("linked.html")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original)
        let game = try await repository.importFile(link)
        let stored = await repository.fileURL(for: game)
        let expected = try Data(contentsOf: original)
        try FileManager.default.removeItem(at: original)
        XCTAssertEqual(try Data(contentsOf: stored), expected)
        XCTAssertEqual(game.size, Int64(expected.count))
    }

    func testSuppliedLargeGamePreservesEveryByte() async throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("fixtures/PokeSurvivor-Offline.html")
        guard FileManager.default.fileExists(atPath: fixture.path) else { throw XCTSkip("Optional local game fixture is absent") }
        let game = try await repository.importFile(fixture)
        XCTAssertGreaterThan(game.size, 100_000_000)
        let stored = await repository.fileURL(for: game)
        func digest(_ url: URL) throws -> SHA256.Digest {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hash = SHA256()
            while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { hash.update(data: chunk) }
            return hash.finalize()
        }
        XCTAssertEqual(try digest(fixture), try digest(stored))
    }

    func testCorruptIndexIsNotOverwrittenByLoad() async throws {
        _ = try await repository.load()
        let index = directory.appendingPathComponent("Library/library.json")
        try Data("damaged".utf8).write(to: index)
        do { _ = try await repository.load(); XCTFail("Accepted corrupt index") } catch {}
        XCTAssertEqual(try String(contentsOf: index), "damaged")
    }

    func testSearchAndURLResolutionRejectUnsafeSchemes() {
        XCTAssertEqual(WebAddress.resolve("example.com/game.html")?.absoluteString, "https://example.com/game.html")
        XCTAssertEqual(WebAddress.resolve("https://example.com/a?b=1")?.host, "example.com")
        XCTAssertEqual(WebAddress.resolve("single file games")?.host, "duckduckgo.com")
        XCTAssertNil(WebAddress.resolve("file:///etc/passwd"))
        XCTAssertNil(WebAddress.resolve("javascript://alert(1)"))
        XCTAssertNil(WebAddress.resolve("  "))
    }
}
