import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var library: GameLibrary
    @State private var tab = 0
    @State private var showImporter = false

    var body: some View {
        TabView(selection: $tab) {
            LibraryView(importFiles: { showImporter = true }, findGames: { tab = 1 })
                .tabItem { Label("Library", systemImage: "square.grid.2x2.fill") }
                .tag(0)
            FindView(importFiles: { showImporter = true })
                .tabItem { Label("Find", systemImage: "magnifyingglass") }
                .tag(1)
        }
        .toolbarBackground(ArcadeTheme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.html], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                Task { await library.importFiles(urls); tab = 0 }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { library.errorMessage = error.localizedDescription }
            }
        }
        .fullScreenCover(item: $library.activeGame) { game in
            GamePlayerView(game: game, repository: library.repository) { library.activeGame = nil }
                .ignoresSafeArea()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
        .alert("Something didn't load", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
            Button("OK", role: .cancel) { library.errorMessage = nil }
        } message: { Text(library.errorMessage ?? "") }
        .overlay(alignment: .top) {
            if library.isBusy {
                HStack(spacing: 10) {
                    ProgressView().tint(ArcadeTheme.lime)
                    Text(library.isReady ? "Importing game…" : "Getting your games ready…")
                        .font(.subheadline.weight(.medium))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 12)
                .accessibilityIdentifier("importProgress")
            }
        }
        .overlay(alignment: .bottom) {
            if let notice = library.notice {
                Label(notice, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ArcadeTheme.lime)
                    .padding(16)
                    .background(ArcadeTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 74)
                    .onTapGesture { library.notice = nil }
                    .task(id: notice) {
                        try? await Task.sleep(for: .seconds(4))
                        if library.notice == notice { library.notice = nil }
                    }
            }
        }
    }
}
