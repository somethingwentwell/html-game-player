import SwiftUI

struct FindView: View {
    @EnvironmentObject private var library: GameLibrary
    @StateObject private var browser = BrowserModel()
    @State private var query = ""
    @FocusState private var addressFocused: Bool
    let importFiles: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if browser.hasPage {
                webBrowser
            } else {
                discovery
            }
        }
        .background(ArcadeTheme.background)
        .onAppear {
            browser.onDownload = { file, filename, source in
                Task { await library.importDownload(file, filename: filename, sourceURL: source) }
            }
        }
    }

    private var discovery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BrandHeader()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Find your\nnext favorite.")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .tracking(-1.3)
                    Text("On your phone or out on the web.")
                        .font(.subheadline).foregroundStyle(ArcadeTheme.muted)
                }
                .padding(.top, -10)

                Button(action: importFiles) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(ArcadeTheme.lime)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 18))
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Browse device files")
                                .font(.system(size: 23, weight: .bold, design: .rounded))
                            Text("Search Files, Downloads, iCloud Drive,\nand connected storage. Select to import.")
                                .font(.system(size: 13)).lineSpacing(4)
                                .foregroundStyle(ArcadeTheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(ArcadeTheme.surface, in: RoundedRectangle(cornerRadius: 26))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(ArcadeTheme.line))
                }
                .buttonStyle(.plain)
                .disabled(library.isBusy)
                .accessibilityIdentifier("browseDeviceFiles")

                Link(destination: URL(string: "https://github.com/somethingwentwell/html-game-player#pok%C3%A9mon-html-game-list")!) {
                    HStack(spacing: 14) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 23))
                            .foregroundStyle(ArcadeTheme.lime)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Game list on GitHub")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Text("Game picks, offline notes, and a place to suggest your favorites.")
                                .font(.system(size: 12))
                                .foregroundStyle(ArcadeTheme.muted)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ArcadeTheme.muted)
                    }
                    .padding(20)
                    .background(ArcadeTheme.surface, in: RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("githubGameList")

                VStack(alignment: .leading, spacing: 16) {
                    Text("EXPLORE THE WEB")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.8).foregroundStyle(ArcadeTheme.muted)
                    searchField
                    HStack(spacing: 8) {
                        searchChip("Single-file games", query: "single file HTML games download")
                        searchChip("itch.io", query: "https://itch.io/games/html5")
                    }
                    Text("Open a game page or HTML download, then tap Import. Self-contained HTML games work best offline.")
                        .font(.system(size: 12)).lineSpacing(4)
                        .foregroundStyle(ArcadeTheme.muted)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(ArcadeTheme.muted)
            TextField("Search or paste a game link", text: $query)
                .font(.system(size: 14))
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($addressFocused)
                .onSubmit(submit)
                .accessibilityIdentifier("gameAddress")
            if !query.isEmpty {
                Button(action: submit) {
                    Image(systemName: "arrow.right.circle.fill").foregroundStyle(ArcadeTheme.lime).font(.system(size: 24))
                }
                .accessibilityLabel("Open address or search")
            }
        }
        .padding(16)
        .background(ArcadeTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ArcadeTheme.line))
    }

    private var webBrowser: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button { browser.close() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("Close browser")
                Text(browser.currentURL?.host ?? "Loading…")
                    .font(.system(size: 13, weight: .medium)).lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .onTapGesture { query = browser.currentURL?.absoluteString ?? ""; browser.close(); addressFocused = true }
                Button(action: importFiles) { Image(systemName: "folder") }
                    .disabled(library.isBusy)
                    .accessibilityLabel("Browse device files")
            }
            .font(.system(size: 18))
            .padding(18)
            if browser.isLoading { ProgressView().progressViewStyle(.linear).tint(ArcadeTheme.lime) }
            if let error = browser.errorMessage {
                VStack(spacing: 12) {
                    Text(error).font(.subheadline).multilineTextAlignment(.center)
                    Button("Try again") { browser.errorMessage = nil; browser.webView.reload() }
                }
                .padding(20)
            }
            BrowserWebView(model: browser)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 12) {
                HStack(spacing: 24) {
                    Button { browser.webView.goBack() } label: { Image(systemName: "chevron.left") }
                        .disabled(!browser.canGoBack).accessibilityLabel("Back")
                    Button { browser.webView.goForward() } label: { Image(systemName: "chevron.right") }
                        .disabled(!browser.canGoForward).accessibilityLabel("Forward")
                    Spacer()
                    Button { browser.webView.reload() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Reload page")
                }
                .padding(.horizontal, 8)
                .font(.system(size: 18))
                PrimaryButton(title: browser.isDownloading ? "Downloading…" : "Import this page", symbol: "arrow.down.to.line") {
                    if let url = browser.currentURL { Task { await library.importWebPage(url) } }
                }
                .disabled(library.isBusy || browser.isDownloading || browser.isLoading || browser.currentURL == nil)
                .accessibilityIdentifier("importWebPage")
                Text("Adds the HTML to your library. Some web games need internet.")
                    .font(.system(size: 10)).foregroundStyle(ArcadeTheme.muted)
            }
            .padding(16)
            .background(ArcadeTheme.background)
        }
    }

    private func searchChip(_ title: String, query: String) -> some View {
        Button { browser.load(query) } label: {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "arrow.up.right").font(.system(size: 9))
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(ArcadeTheme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        addressFocused = false
        browser.load(query)
    }
}
