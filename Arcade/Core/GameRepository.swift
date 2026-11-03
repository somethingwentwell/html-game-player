import Foundation

/// Serializes disk work away from the UI. Imported game bytes are never rewritten.
actor GameRepository {
    let root: URL
    private let files = FileManager.default

    init(root: URL = URL.applicationSupportDirectory.appendingPathComponent("HTMLArcade", isDirectory: true)) {
        self.root = root
    }

    func load() throws -> [Game] {
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        let index = root.appendingPathComponent("library.json")
        guard files.fileExists(atPath: index.path) else { return [] }
        // A damaged index is surfaced to the user, never silently overwritten.
        return try JSONDecoder().decode([Game].self, from: Data(contentsOf: index))
    }

    func fileURL(for game: Game) -> URL {
        root.appendingPathComponent(game.id.uuidString, isDirectory: true).appendingPathComponent("game.html")
    }

    func importFile(_ url: URL, filename: String? = nil, sourceURL: URL? = nil) throws -> Game {
        let original = (filename ?? url.lastPathComponent as String) as NSString
        guard ["html", "htm"].contains(original.pathExtension.lowercased()) else { throw ImportError.notHTML }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<Game, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
            result = Result { try copyValidatedFile(readable, filename: original.lastPathComponent, sourceURL: sourceURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ImportError.missingGame }
        return try result.get()
    }

    private func copyValidatedFile(_ url: URL, filename: String, sourceURL: URL?) throws -> Game {
        let source = url.resolvingSymlinksInPath()
        let handle = try FileHandle(forReadingFrom: source)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 65_536) ?? Data()
        guard !header.isEmpty else { throw ImportError.emptyFile }
        let text = String(decoding: header, as: UTF8.self).lowercased()
        guard text.contains("<html") || text.contains("<!doctype html") || text.contains("<head") || text.contains("<body") else {
            throw ImportError.notHTML
        }
        let attributes = try files.attributesOfItem(atPath: source.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let game = Game(id: UUID(), title: Game.title(for: filename), originalFilename: filename,
                        size: size, importedAt: Date(), sourceURL: sourceURL)
        let destination = fileURL(for: game)
        try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        do { try files.copyItem(at: source, to: destination) }
        catch {
            try? files.removeItem(at: destination.deletingLastPathComponent())
            throw error
        }
        return game
    }

    func save(_ games: [Game]) throws {
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(games).write(to: root.appendingPathComponent("library.json"), options: .atomic)
    }

    func removeFiles(for game: Game) throws {
        let directory = fileURL(for: game).deletingLastPathComponent()
        if files.fileExists(atPath: directory.path) { try files.removeItem(at: directory) }
    }
}
