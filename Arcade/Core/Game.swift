import Foundation

struct Game: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    let originalFilename: String
    let size: Int64
    let importedAt: Date
    var lastPlayedAt: Date?
    let sourceURL: URL?

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var symbol: String {
        let symbols = ["gamecontroller.fill", "sparkles", "bolt.fill", "moon.stars.fill"]
        return symbols[Int(id.uuid.0) % symbols.count]
    }

    static func title(for filename: String) -> String {
        let name = (filename as NSString).deletingPathExtension
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Untitled game" : name
    }
}

enum ImportError: LocalizedError {
    case notHTML, emptyFile, http(Int), invalidURL, missingGame, cancelled

    var errorDescription: String? {
        switch self {
        case .notHTML: return "Choose an HTML game (.html or .htm). For a game with separate assets, export it as a single HTML file first."
        case .emptyFile: return "This file is empty. Choose another HTML game."
        case .http(let code): return "The website returned error \(code). Try the game's direct HTML download link."
        case .invalidURL: return "Enter a valid http or https link."
        case .missingGame: return "This game's file is missing. Import it again from Files."
        case .cancelled: return "Import cancelled."
        }
    }
}

enum WebAddress {
    static func resolve(_ text: String) -> URL? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.contains("://") {
            guard let url = URL(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  url.host != nil else { return nil }
            return url
        }
        if !value.contains(" "), value.contains("."), let url = URL(string: "https://" + value), url.host != nil {
            return url
        }
        var components = URLComponents(string: "https://duckduckgo.com/")!
        components.queryItems = [URLQueryItem(name: "q", value: value)]
        return components.url
    }
}
