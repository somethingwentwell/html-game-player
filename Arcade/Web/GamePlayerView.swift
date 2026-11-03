import SwiftUI
import WebKit
import SafariServices

struct GamePlayerView: UIViewControllerRepresentable {
    let game: Game
    let repository: GameRepository
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> GamePlayerController {
        GamePlayerController(game: game, repository: repository, onClose: onClose)
    }
    func updateUIViewController(_ controller: GamePlayerController, context: Context) {}
    static func dismantleUIViewController(_ controller: GamePlayerController, coordinator: ()) {
        controller.stopGame()
    }
}

final class GamePlayerController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let game: Game
    private let repository: GameRepository
    private let onClose: () -> Void
    private var webView: WKWebView!
    private let menuButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()
    private var orientation: UIInterfaceOrientationMask = .allButUpsideDown
    private var previousIdleTimer = false
    private var hasPlacedMenu = false
    private var failureView: UIStackView?
    private var hasStopped = false

    init(game: Game, repository: GameRepository, onClose: @escaping () -> Void) {
        self.game = game
        self.repository = repository
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    required init?(coder: NSCoder) { fatalError("Use init(game:repository:onClose:)") }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { orientation }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: game.id)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true

        if let source = game.sourceURL,
           let json = try? JSONSerialization.data(withJSONObject: [source.absoluteString]),
           let array = String(data: json, encoding: .utf8) {
            // Preserve relative web assets without rewriting the downloaded HTML.
            let script = """
            (() => {
              const href = \(array)[0];
              const insert = () => {
                if (!document.head) return false;
                if (!document.querySelector('base')) {
                  const base = document.createElement('base'); base.href = href;
                  document.head.prepend(base);
                }
                return true;
              };
              if (!insert()) {
                const observer = new MutationObserver(() => { if (insert()) observer.disconnect(); });
                observer.observe(document, { childList: true, subtree: true });
              }
            })();
            """
            config.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.allowsBackForwardNavigationGestures = false
        webView.isInspectable = _isDebugAssertConfiguration()
        webView.accessibilityIdentifier = "gameWebView"
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        spinner.color = UIColor(ArcadeTheme.lime)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.text = "Opening \(game.title)…"
        loadingLabel.textColor = .white
        loadingLabel.font = .systemFont(ofSize: 14)
        loadingLabel.numberOfLines = 2
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        view.addSubview(loadingLabel)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -60)
        ])

        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.image = UIImage(systemName: "ellipsis", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .bold))
        buttonConfig.baseBackgroundColor = UIColor(white: 0.10, alpha: 0.82)
        buttonConfig.baseForegroundColor = .white
        buttonConfig.cornerStyle = .capsule
        menuButton.configuration = buttonConfig
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.accessibilityLabel = "Game menu"
        menuButton.accessibilityHint = "Return to library, restart, or rotate. Drag to move."
        menuButton.accessibilityIdentifier = "gameMenu"
        menuButton.frame.size = CGSize(width: 48, height: 44)
        menuButton.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragMenu(_:))))
        view.addSubview(menuButton)
        updateMenu()
        loadGame()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        webView.setAllMediaPlaybackSuspended(false)
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = previousIdleTimer
        webView.setAllMediaPlaybackSuspended(true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hasPlacedMenu {
            menuButton.frame.origin = CGPoint(x: view.bounds.width - view.safeAreaInsets.right - 62, y: view.safeAreaInsets.top + 8)
            hasPlacedMenu = true
        }
        clampMenu()
    }

    @objc private func dragMenu(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        menuButton.center.x += translation.x
        menuButton.center.y += translation.y
        gesture.setTranslation(.zero, in: view)
        clampMenu()
    }

    private func clampMenu() {
        menuButton.center.x = max(view.safeAreaInsets.left + 30, min(view.bounds.width - view.safeAreaInsets.right - 30, menuButton.center.x))
        menuButton.center.y = max(view.safeAreaInsets.top + 30, min(view.bounds.height - view.safeAreaInsets.bottom - 30, menuButton.center.y))
    }

    private func updateMenu() {
        let rotations: [(String, UIInterfaceOrientationMask)] = [("Automatic", .allButUpsideDown), ("Portrait", .portrait), ("Landscape", .landscape)]
        let rotateMenu = UIMenu(title: "Orientation", image: UIImage(systemName: "rotate.right"), children: rotations.map { title, mask in
            UIAction(title: title, state: orientation == mask ? .on : .off) { [weak self] _ in self?.rotate(to: mask) }
        })
        menuButton.menu = UIMenu(title: game.title, children: [
            UIAction(title: "Back to Library", image: UIImage(systemName: "square.grid.2x2")) { [weak self] _ in
                self?.stopGame()
                self?.onClose()
            },
            rotateMenu,
            UIAction(title: "Restart game", image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in self?.confirmRestart() }
        ])
    }

    func stopGame() {
        guard !hasStopped, let webView else { return }
        hasStopped = true
        ArcadeAppDelegate.orientationMask = .allButUpsideDown
        view.window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.stopLoading()
        webView.setAllMediaPlaybackSuspended(true)
        // A stopped navigation does not stop an already running game loop.
        // Unload the page to release its canvas, timers, audio, and asset memory.
        webView.loadHTMLString("", baseURL: nil)
    }

    private func rotate(to mask: UIInterfaceOrientationMask) {
        orientation = mask
        ArcadeAppDelegate.orientationMask = mask
        view.window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        setNeedsUpdateOfSupportedInterfaceOrientations()
        view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { [weak self] error in
            self?.showMessage("Couldn't rotate", message: error.localizedDescription)
        }
        updateMenu()
    }

    private func confirmRestart() {
        let alert = UIAlertController(title: "Restart game?", message: "Progress since the game's last save may be lost.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Restart", style: .destructive) { [weak self] _ in self?.loadGame() })
        present(alert, animated: true)
    }

    private func loadGame() {
        failureView?.removeFromSuperview()
        failureView = nil
        spinner.startAnimating()
        loadingLabel.isHidden = false
        Task { [weak self] in
            guard let self else { return }
            let file = await repository.fileURL(for: game)
            guard FileManager.default.fileExists(atPath: file.path) else {
                showFailure(ImportError.missingGame); return
            }
            webView.loadFileURL(file, allowingReadAccessTo: file.deletingLastPathComponent())
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        spinner.stopAnimating()
        loadingLabel.isHidden = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { showFailure(error) }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { showFailure(error) }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        showFailure(NSError(domain: "HTMLArcade", code: 1, userInfo: [NSLocalizedDescriptionKey: "The game stopped responding. Tap Try again to reopen it."]))
    }

    private func showFailure(_ error: Error) {
        spinner.stopAnimating()
        loadingLabel.isHidden = true
        failureView?.removeFromSuperview()
        let label = UILabel()
        label.text = error.localizedDescription
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        let retry = UIButton(type: .system)
        retry.setTitle("Try again", for: .normal)
        retry.addAction(UIAction { [weak self] _ in self?.loadGame() }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [label, retry])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.backgroundColor = .black
        view.insertSubview(stack, belowSubview: menuButton)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -60)
        ])
        failureView = stack
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        let scheme = url.scheme?.lowercased() ?? ""
        if action.navigationType == .linkActivated, action.targetFrame?.isMainFrame != false, ["https", "http"].contains(scheme) {
            decisionHandler(.cancel)
            present(SFSafariViewController(url: url), animated: true)
        } else if ["file", "about", "data", "blob", "https", "http"].contains(scheme) {
            decisionHandler(.allow)
        } else { decisionHandler(.cancel) }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url, ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
            present(SFSafariViewController(url: url), animated: true)
        }
        return nil
    }

    private func showMessage(_ title: String, message: String) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: game.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: game.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: game.title, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in completionHandler(alert?.textFields?.first?.text) })
        present(alert, animated: true)
    }
}
