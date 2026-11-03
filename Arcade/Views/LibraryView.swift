import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: GameLibrary
    let importFiles: () -> Void
    let findGames: () -> Void
    @State private var renameGame: Game?
    @State private var newTitle = ""
    @State private var deleteGame: Game?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BrandHeader()
                HStack(alignment: .lastTextBaseline) {
                    Text("Your library")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .tracking(-1)
                    Spacer()
                    Text(String(format: "%02d", library.games.count))
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundStyle(ArcadeTheme.muted)
                }
                .padding(.top, -12)

                if let game = library.sortedGames.first {
                    featuredGame(game)
                } else if library.isReady {
                    emptyLibrary
                }

                HStack(spacing: 12) {
                    PrimaryButton(title: "Import game", symbol: "plus", action: importFiles)
                        .accessibilityIdentifier("importGame")
                    Button(action: findGames) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 56, height: 54)
                            .background(ArcadeTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Find games")
                }
                .disabled(library.isBusy)

                if !library.games.isEmpty {
                    HStack {
                        Text("ALL GAMES").tracking(1.8)
                        Spacer()
                        Text("HOLD TO MANAGE").tracking(1)
                    }
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ArcadeTheme.muted)
                    .padding(.top, 8)
                    VStack(spacing: 10) {
                        ForEach(Array(library.sortedGames.enumerated()), id: \.element.id) { index, game in
                            gameRow(game, index: index)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "doc.badge.plus")
                    Text("Have an HTML file? Import from Files, Downloads, or iCloud Drive. Your games stay on this device.")
                }
                .font(.system(size: 12))
                .foregroundStyle(ArcadeTheme.muted)
                .lineSpacing(4)
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(ArcadeTheme.background)
        .alert("Rename game", isPresented: Binding(get: { renameGame != nil }, set: { if !$0 { renameGame = nil } })) {
            TextField("Game name", text: $newTitle)
            Button("Cancel", role: .cancel) { renameGame = nil }
            Button("Save") {
                if let game = renameGame { Task { await library.rename(game, to: newTitle) } }
                renameGame = nil
            }
        }
        .confirmationDialog("Remove \(deleteGame?.title ?? "game")?", isPresented: Binding(get: { deleteGame != nil }, set: { if !$0 { deleteGame = nil } }), titleVisibility: .visible) {
            Button("Remove game and saved progress", role: .destructive) {
                if let game = deleteGame { Task { await library.delete(game) } }
                deleteGame = nil
            }
        } message: { Text("The original HTML file in Files will stay where it is.") }
    }

    private func featuredGame(_ game: Game) -> some View {
        Button { Task { await library.play(game) } } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Label(game.lastPlayedAt == nil ? "UP NEXT" : "PLAY AGAIN", systemImage: "circle.fill")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.8)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 20, weight: .medium))
                }
                Spacer(minLength: 20)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(game.title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .tracking(-0.8)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Text("\(game.sizeLabel)  ·  FULL SCREEN")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(0.8)
                            .opacity(0.65)
                    }
                    Spacer(minLength: 12)
                    Image(systemName: "play.fill")
                        .font(.system(size: 19))
                        .frame(width: 52, height: 52)
                        .background(ArcadeTheme.background, in: Circle())
                        .foregroundStyle(ArcadeTheme.lime)
                }
            }
            .padding(24)
            .frame(minHeight: 228)
            .background(alignment: .topTrailing) {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 140, weight: .regular))
                    .rotationEffect(.degrees(-22))
                    .offset(x: 15, y: 6)
                    .opacity(0.08)
            }
            .foregroundStyle(ArcadeTheme.background)
            .background(ArcadeTheme.lime, in: RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .disabled(library.isBusy)
        .accessibilityLabel("Play \(game.title)")
        .accessibilityIdentifier("featuredGame")
    }

    private func gameRow(_ game: Game, index: Int) -> some View {
        Button { Task { await library.play(game) } } label: {
            HStack(spacing: 14) {
                Image(systemName: game.symbol)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(ArcadeTheme.colors[index % ArcadeTheme.colors.count])
                    .frame(width: 58, height: 58)
                    .background(ArcadeTheme.colors[index % ArcadeTheme.colors.count].opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 6) {
                    Text(game.title).font(.system(size: 16, weight: .semibold, design: .rounded)).lineLimit(2)
                    Text("HTML  ·  \(game.sizeLabel)\(game.sourceURL == nil ? "" : "  ·  Web import")")
                        .font(.system(size: 11)).foregroundStyle(ArcadeTheme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill").font(.system(size: 13)).foregroundStyle(ArcadeTheme.muted)
            }
            .padding(14)
            .background(ArcadeTheme.surface, in: RoundedRectangle(cornerRadius: 22))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(library.isBusy)
        .contextMenu {
            Button("Rename", systemImage: "pencil") { newTitle = game.title; renameGame = game }
            Button("Remove", systemImage: "trash", role: .destructive) { deleteGame = game }
        }
    }

    private var emptyLibrary: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "gamecontroller").font(.system(size: 58, weight: .light)).foregroundStyle(ArcadeTheme.lime)
            Text("Small file.\nBig adventure.")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Bring your HTML games.\nWe'll give them the whole screen.")
                .font(.subheadline).foregroundStyle(ArcadeTheme.muted).lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(28)
        .background(ArcadeTheme.surface, in: RoundedRectangle(cornerRadius: 28))
    }
}
