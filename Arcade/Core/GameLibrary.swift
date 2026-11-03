import SwiftUI
import WebKit

@MainActor
final class GameLibrary: ObservableObject {
    @Published private(set) var games: [Game] = []
    @Published private(set) var isBusy = false
    @Published private(set) var isReady = false
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published var activeGame: Game?
    let repository: GameRepository
    private var initialized = false
    private var indexIsHealthy = true

    init(repository: GameRepository = GameRepository()) { self.repository = repository }

    var sortedGames: [Game] {
        games.sorted { ($0.lastPlayedAt ?? $0.importedAt) > ($1.lastPlayedAt ?? $1.importedAt) }
    }

    func start() async {
        guard !initialized else { return }
        initialized = true
        isBusy = true
        defer { isBusy = false; isReady = true }
        do {
            games = try await repository.load()
            let defaults = UserDefaults.standard
            if !defaults.bool(forKey: "starterGamesImported") {
                let urls = Bundle.main.urls(forResourcesWithExtension: "html", subdirectory: "LocalGames") ?? []
                for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    let game = try await repository.importFile(url)
                    games.append(game)
                }
                try await repository.save(games)
                defaults.set(true, forKey: "starterGamesImported")
            }
        } catch {
            indexIsHealthy = false
            errorMessage = "Couldn't open the library: \(error.localizedDescription)"
        }
    }

    func importFiles(_ urls: [URL]) async {
        guard !isBusy, indexIsHealthy else { return }
        isBusy = true
        defer { isBusy = false }
        var imported = 0
        var failures: [String] = []
        for url in urls {
            do { try await addFile(url); imported += 1 }
            catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        if imported > 0 { notice = imported == 1 ? "Game added to Library" : "\(imported) games added to Library" }
        if !failures.isEmpty { errorMessage = failures.joined(separator: "\n\n") }
    }

    private func addFile(_ url: URL, filename: String? = nil, sourceURL: URL? = nil) async throws {
        let game = try await repository.importFile(url, filename: filename, sourceURL: sourceURL)
        do {
            try await repository.save(games + [game])
            games.append(game)
        } catch {
            try? await repository.removeFiles(for: game)
            throw error
        }
    }

    func importDownload(_ file: URL, filename: String, sourceURL: URL?) async {
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        guard !isBusy, indexIsHealthy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await addFile(file, filename: filename, sourceURL: sourceURL)
            notice = "Game added to Library"
        } catch { errorMessage = error.localizedDescription }
    }

    func importWebPage(_ url: URL) async {
        guard !isBusy, indexIsHealthy else { return }
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
            errorMessage = ImportError.invalidURL.localizedDescription; return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            // URLSession downloads to disk, so a 100 MB game isn't held in a Swift String.
            let (temporary, response) = try await URLSession.shared.download(from: url)
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard let http = response as? HTTPURLResponse else { throw ImportError.invalidURL }
            guard (200..<300).contains(http.statusCode) else { throw ImportError.http(http.statusCode) }
            let mime = response.mimeType?.lowercased() ?? ""
            guard ["text/html", "application/xhtml+xml", "application/octet-stream", ""].contains(mime) else {
                throw ImportError.notHTML
            }
            var filename = response.suggestedFilename ?? url.lastPathComponent
            if !["html", "htm"].contains((filename as NSString).pathExtension.lowercased()) {
                filename = (url.host ?? "Web game") + ".html"
            }
            try await addFile(temporary, filename: filename, sourceURL: response.url ?? url)
            notice = "Game added. Web games may still need internet for their assets."
        } catch { errorMessage = error.localizedDescription }
    }

    func play(_ game: Game) async {
        guard let index = games.firstIndex(where: { $0.id == game.id }) else { return }
        let file = await repository.fileURL(for: game)
        guard FileManager.default.fileExists(atPath: file.path) else {
            errorMessage = ImportError.missingGame.localizedDescription; return
        }
        var updated = games
        updated[index].lastPlayedAt = Date()
        do {
            try await repository.save(updated)
            games = updated
            activeGame = updated[index]
        } catch { errorMessage = error.localizedDescription }
    }

    func rename(_ game: Game, to title: String) async {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let index = games.firstIndex(where: { $0.id == game.id }) else { return }
        var updated = games
        updated[index].title = title
        do { try await repository.save(updated); games = updated }
        catch { errorMessage = error.localizedDescription }
    }

    func delete(_ game: Game) async {
        let updated = games.filter { $0.id != game.id }
        do {
            try await repository.save(updated)
            games = updated
            try await repository.removeFiles(for: game)
            WKWebsiteDataStore.remove(forIdentifier: game.id) { _ in }
        } catch { errorMessage = error.localizedDescription }
    }
}
